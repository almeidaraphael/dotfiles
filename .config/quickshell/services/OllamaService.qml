pragma Singleton
import QtQuick
import Quickshell.Io
import Qt.labs.platform
import ".."
import "ollamaLogic.js" as OllamaLogic

// Local LLM + per-conversation RAG. Talks to Ollama's HTTP API directly
// (localhost:11434). Conversations (messages + attachment raw text) persist
// to disk across shell restarts; embeddings are derived data, not persisted
// — attachments are re-chunked and re-embedded against Ollama on load.
QtObject {
    id: root

    property string baseUrl: ConfigService.ollamaBaseUrl
    readonly property string historyPath: StandardPaths.writableLocation(
        StandardPaths.GenericConfigLocation) + "/quickshell/assistant-history.json"

    property bool   connected:    false
    property string activeModel:  ""
    property var    availableModels: []
    property string lastError:   ""

    property var conversations: []
    property string activeConversationId: ""

    // Live text of the in-flight assistant reply. Kept flat (not inside
    // `conversations`) so each streamed token only touches this one string
    // property instead of cloning the whole conversation tree — reassigning
    // `conversations` on every token forces ListView to fully reset (plain
    // JS array models aren't diffed), which reads as every message bubble
    // flickering, not just the streaming one. Committed into the real
    // message object once, when the stream finishes.
    property string streamingText: ""

    property string streamingThinking: ""
    property bool streamingThinkClosed: false
    property int streamingThinkSeconds: 0
    property var _modelCapabilities: ({})
    property bool _nativeThinking: false
    property string _rawContent: ""
    property real _thinkStartTime: 0
    // Fallback-path only: reasoning already closed out in a prior tool-call
    // round, carried forward so it isn't lost when _rawContent resets at the
    // next round boundary (see _continueAfterTool).
    property string _thinkingCommitted: ""
    readonly property real  ragScoreThreshold: 0.3
    readonly property int   chunkSize:         2000
    readonly property int   chunkOverlap:      200
    readonly property int   ragTopK:           3
    readonly property int   toolRoundBudget:   3
    readonly property int   summarizeThreshold: 30
    readonly property int   keepRecentCount:    12
    property var _summaryCache: ({})   // { [convId]: { upToLen: N, text: "..." } }

    property var _streamXhr: null

    property var _statusTimer: Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshStatus()
    }

    Component.onCompleted: root.load()

    function load() {
        var localPath = root.historyPath.replace(/^file:\/\//, "")
        var proc = Qt.createQmlObject(
            'import Quickshell.Io; Process { stdout: StdioCollector { waitForEnd: true } }', root)
        proc.command = ["cat", localPath]
        proc.stdout.streamFinished.connect(function() {
            var responseText = proc.stdout.text
            proc.destroy()
            if (responseText === "") return
            var data
            try {
                data = JSON.parse(responseText)
            } catch (e) { return }

            var convs = (data.conversations || []).map(function(c) {
                return {
                    id: c.id,
                    title: c.title,
                    updatedAt: new Date(c.updatedAt),
                    messages: (c.messages || []).map(function(m) {
                        return { role: m.role, text: m.text, citations: m.citations || [], error: m.error || "",
                                 streaming: false, toolCalling: false, toolQuery: "" }
                    }),
                    attachments: (c.attachments || []).map(function(a) {
                        return { id: a.id, name: a.name, status: a.rawText ? "embedding" : "failed", chunks: [], rawText: a.rawText || "" }
                    })
                }
            })
            root.conversations = convs

            // Re-embed after conversations are in place — _embedAttachment
            // mutates via _updateConv, which needs to find the conv/attachment
            // already present in root.conversations.
            convs.forEach(function(conv) {
                conv.attachments.forEach(function(a) {
                    if (a.rawText) root._embedAttachment(conv.id, a.id, a.rawText)
                })
            })
        })
        proc.running = true
    }

    // Debounced: _updateConv calls save() on every single mutation, and
    // folder-attach fires ~3 mutations per file back-to-back (add attachment →
    // set rawText → set status). Each write is a detached truncate-then-write
    // shell process, so N overlapping writes to the same path can interleave
    // and leave invalid JSON on disk — which load() then silently treats as
    // "no history", losing every conversation. Coalescing into one write per
    // quiet period removes the race entirely.
    function save() {
        root._saveDebounce.restart()
    }

    property var _saveDebounce: Timer {
        interval: 500
        repeat: false
        onTriggered: root._writeHistory()
    }

    function _writeHistory() {
        var data = {
            conversations: root.conversations.map(function(c) {
                return {
                    id: c.id,
                    title: c.title,
                    updatedAt: c.updatedAt,
                    messages: c.messages.map(function(m) {
                        var out = { role: m.role, text: m.text }
                        if (m.citations && m.citations.length > 0) out.citations = m.citations
                        if (m.error) out.error = m.error
                        return out
                    }),
                    attachments: (c.attachments || []).map(function(a) {
                        return { id: a.id, name: a.name, rawText: a.rawText || "" }
                    })
                }
            })
        }
        var localPath = root.historyPath.replace(/^file:\/\//, "")
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
        proc.command = ["bash", "-c", "printf '%s' \"$1\" > \"$2\"", "_",
                        JSON.stringify(data, null, 2), localPath]
        // Same one-shot cleanup contract the zenity/find pickers use — without
        // it every write leaks a Process object for the shell's lifetime.
        proc.exited.connect(function() { proc.destroy() })
        proc.running = true
    }

    function clearHistory() {
        root.conversations = []
        root.activeConversationId = ""
        root.save()
    }

    function refreshStatus() {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200) {
                root.connected = false
                root.lastError = "Ollama not reachable at " + root.baseUrl
                return
            }
            try {
                var data = JSON.parse(xhr.responseText)
                var capMap = {}
                ;(data.models || []).forEach(function(m) { capMap[m.name] = m.capabilities || [] })
                root._modelCapabilities = capMap
                // Embedding-only models (e.g. nomic-embed-text, used exclusively
                // for RAG via root.embeddingModel) can't serve /api/chat at all —
                // excluding them here keeps them out of both the picker and
                // activeModel auto-selection, not just off the visible list.
                var models = (data.models || [])
                    .filter(function(m) { return (m.capabilities || []).indexOf("completion") !== -1 })
                    .map(function(m) { return m.name })
                root.availableModels = models
                if (models.length === 0) {
                    root.connected = false
                    root.lastError = "No models pulled — run `ollama pull <model>`"
                    return
                }
                if (models.indexOf(root.activeModel) === -1) {
                    root.activeModel = models.indexOf(ConfigService.preferredModel) !== -1
                        ? ConfigService.preferredModel : models[0]
                }
                root.connected = true
                root.lastError = ""
            } catch (e) {
                root.connected = false
                root.lastError = "Bad response from Ollama"
            }
        }
        xhr.open("GET", root.baseUrl + "/api/tags")
        xhr.send()
    }

    function _findConv(id) {
        for (var i = 0; i < root.conversations.length; i++)
            if (root.conversations[i].id === id) return root.conversations[i]
        return null
    }

    readonly property bool canSwitchModel: {
        var conv = root._findConv(root.activeConversationId)
        return !conv || conv.messages.length === 0
    }

    function setActiveModel(name) {
        if (!root.canSwitchModel) return
        if (root.availableModels.indexOf(name) === -1) return
        root.activeModel = name
        ConfigService.preferredModel = name
        ConfigService.save()
    }

    // Clone-and-replace so `var` list/object mutations trigger QML bindings
    // (same pattern NotificationService uses for markAllSeen) — plain
    // in-place mutation of nested objects doesn't emit conversationsChanged.
    function _updateConv(id, mutator) {
        var list = root.conversations.slice()
        for (var i = 0; i < list.length; i++) {
            if (list[i].id !== id) continue
            var conv = Object.assign({}, list[i])
            mutator(conv)
            list[i] = conv
            root.conversations = list
            root.save()
            return
        }
    }

    function newConversation() {
        var conv = {
            id: "c" + Date.now(),
            title: "New conversation",
            messages: [],
            attachments: [],
            updatedAt: new Date()
        }
        root.conversations = [conv].concat(root.conversations)
        root.activeConversationId = conv.id
        root.save()
        return conv.id
    }

    function deleteConversation(id) {
        root.conversations = root.conversations.filter(function(c) { return c.id !== id })
        if (root.activeConversationId === id) root.activeConversationId = ""
        root.save()
    }

    // --- Attachments / RAG -------------------------------------------------

    // Chat models (activeModel) generally can't serve /api/embeddings on
    // this Ollama version — embedding requires a dedicated embedding-model
    // architecture (nomic-embed-text, mxbai-embed-large, etc), not a
    // capability of arbitrary chat models. RAG chunk/query embedding always
    // uses this fixed model, independent of whatever chat model is active.
    property string embeddingModel: ConfigService.embeddingModel

    function _embed(text, onDone, onFail) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200) { onFail(); return }
            try {
                var data = JSON.parse(xhr.responseText)
                onDone(data.embedding || [])
            } catch (e) { onFail() }
        }
        xhr.open("POST", root.baseUrl + "/api/embeddings")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(JSON.stringify({ model: root.embeddingModel, prompt: text }))
    }

    function attachFile(convId) {
        var picker = Qt.createQmlObject(
            'import Quickshell.Io; Process { stdout: StdioCollector { waitForEnd: true } }', root)
        picker.command = ["zenity", "--file-selection", "--multiple",
            "--title=Attach file(s) to conversation",
            "--file-filter=Text/code/markdown | *.txt *.md *.markdown *.py *.js *.ts *.qml *.json *.yaml *.yml *.toml *.sh *.rs *.go *.c *.cpp *.h"]
        picker.stdout.streamFinished.connect(function() {
            var raw = picker.stdout.text.trim()
            picker.destroy()
            if (raw.length === 0) return
            raw.split("|").forEach(function(path) {
                if (path.length > 0) root._readAndEmbed(convId, path)
            })
        })
        picker.running = true
    }

    property int maxFolderAttachFiles: ConfigService.maxFolderAttachFiles

    function attachFolder(convId) {
        var picker = Qt.createQmlObject(
            'import Quickshell.Io; Process { stdout: StdioCollector { waitForEnd: true } }', root)
        picker.command = ["zenity", "--file-selection", "--directory",
            "--title=Attach folder to conversation"]
        picker.stdout.streamFinished.connect(function() {
            var dir = picker.stdout.text.trim()
            picker.destroy()
            if (dir.length > 0) root._walkFolder(convId, dir)
        })
        picker.running = true
    }

    function _walkFolder(convId, dir) {
        var finder = Qt.createQmlObject(
            'import Quickshell.Io; Process { stdout: StdioCollector { waitForEnd: true } }', root)
        finder.command = ["find", dir, "-type", "f",
            "(",
            "-name", "*.txt", "-o", "-name", "*.md", "-o", "-name", "*.markdown",
            "-o", "-name", "*.py", "-o", "-name", "*.js", "-o", "-name", "*.ts",
            "-o", "-name", "*.qml", "-o", "-name", "*.json", "-o", "-name", "*.yaml",
            "-o", "-name", "*.yml", "-o", "-name", "*.toml", "-o", "-name", "*.sh",
            "-o", "-name", "*.rs", "-o", "-name", "*.go", "-o", "-name", "*.c",
            "-o", "-name", "*.cpp", "-o", "-name", "*.h",
            ")"]
        finder.stdout.streamFinished.connect(function() {
            var out = finder.stdout.text
            finder.destroy()
            var lines = out.split("\n").filter(function(l) { return l.trim().length > 0 })
            var dirPrefix = dir.replace(/\/$/, "") + "/"
            var excludeNames = ["node_modules", "target", "build", "dist"]
            var matches = lines.filter(function(fullPath) {
                var rel = fullPath.indexOf(dirPrefix) === 0 ? fullPath.slice(dirPrefix.length) : fullPath
                var parts = rel.split("/")
                return !parts.some(function(part) {
                    return part.charAt(0) === "." || excludeNames.indexOf(part) !== -1
                })
            })
            if (matches.length === 0) {
                NotificationService.notifyTransient({ appName: "Assistant",
                    summary: "No matching files",
                    body: "That folder had no files matching the supported extensions." })
                return
            }
            var truncated = matches.length > root.maxFolderAttachFiles
            var picked = matches.slice(0, root.maxFolderAttachFiles)
            picked.forEach(function(fullPath) {
                var relName = fullPath.indexOf(dirPrefix) === 0
                    ? fullPath.slice(dirPrefix.length) : fullPath.split("/").pop()
                root._readAndEmbed(convId, fullPath, relName)
            })
            if (truncated) {
                NotificationService.notifyTransient({ appName: "Assistant",
                    summary: "Folder attach truncated",
                    body: "Attached the first " + root.maxFolderAttachFiles + " of " + matches.length + " files." })
            }
        })
        finder.running = true
    }

    function _readAndEmbed(convId, path, displayName) {
        var name = displayName || path.split("/").pop()
        var attachment = { id: "a" + Date.now() + "_" + Math.random().toString(36).slice(2, 8),
                            name: name, status: "embedding", chunks: [], rawText: "" }

        root._updateConv(convId, function(conv) {
            conv.attachments = conv.attachments.concat([attachment])
        })

        var proc = Qt.createQmlObject(
            'import Quickshell.Io; Process { stdout: StdioCollector { waitForEnd: true } }', root)
        proc.command = ["cat", path]
        proc.exited.connect(function(exitCode) {
            if (exitCode !== 0) {
                proc.destroy()
                root._setAttachmentStatus(convId, attachment.id, "failed")
                return
            }
            var text = proc.stdout.text
            proc.destroy()
            root._embedAttachment(convId, attachment.id, text)
        })
        proc.running = true
    }

    // Shared by fresh attach (_readAndEmbed) and history reload (load()) —
    // embeddings aren't persisted, so reload re-derives them from the saved
    // rawText the same way a new attachment would.
    function _embedAttachment(convId, attachmentId, rawText) {
        root._updateConv(convId, function(conv) {
            conv.attachments = conv.attachments.map(function(a) {
                return a.id === attachmentId ? Object.assign({}, a, { rawText: rawText }) : a
            })
        })

        var chunks = OllamaLogic.chunkText(rawText, root.chunkSize, root.chunkOverlap)
        var pending = chunks.length
        if (pending === 0) { root._setAttachmentStatus(convId, attachmentId, "failed"); return }

        var embedded = []
        var failed = false
        chunks.forEach(function(chunkText) {
            root._embed(chunkText,
                function(vector) {
                    embedded.push({ text: chunkText, embedding: vector })
                    pending--
                    if (pending === 0) {
                        root._updateConv(convId, function(conv) {
                            conv.attachments = conv.attachments.map(function(a) {
                                if (a.id !== attachmentId) return a
                                return Object.assign({}, a, { status: failed ? "failed" : "ready", chunks: embedded })
                            })
                        })
                    }
                },
                function() {
                    failed = true
                    pending--
                    if (pending === 0) root._setAttachmentStatus(convId, attachmentId, "failed")
                })
        })
    }

    function _setAttachmentStatus(convId, attachmentId, status) {
        root._updateConv(convId, function(conv) {
            conv.attachments = conv.attachments.map(function(a) {
                return a.id === attachmentId ? Object.assign({}, a, { status: status }) : a
            })
        })
    }

    function removeAttachment(convId, attachmentId) {
        root._updateConv(convId, function(conv) {
            conv.attachments = conv.attachments.filter(function(a) { return a.id !== attachmentId })
        })
    }

    // --- Chat ---------------------------------------------------------------

    function sendMessage(convId, text) {
        var conv = root._findConv(convId)
        if (!conv || !text.trim()) return

        root._updateConv(convId, function(c) {
            c.messages = c.messages.concat([{ role: "user", text: text }])
            if (c.title === "New conversation") c.title = text.replace(/\s+/g, " ").trim().slice(0, 40)
            c.updatedAt = new Date()
        })

        root._summarizeIfNeeded(convId, function() {
            var hasRag = conv.attachments.some(function(a) { return a.status === "ready" })
            if (hasRag) {
                root._embed(text, function(queryVec) {
                    var top = OllamaLogic.topChunks(conv, queryVec, root.ragTopK, root.ragScoreThreshold)
                    root._runChat(convId, text, top)
                }, function() {
                    root._runChat(convId, text, [])
                })
            } else {
                root._runChat(convId, text, [])
            }
        })
    }

    // Rolling fold-point summarization: the cache always covers "everything
    // up to message index upToLen", and _runChat always sends everything
    // after that index verbatim — so there's never a gap where messages are
    // neither summarized nor sent. Re-summarization only fires once the
    // unsummarized tail grows past summarizeThreshold, folding the oldest
    // excess back down to keepRecentCount, rather than on every single turn.
    function _summarizeIfNeeded(convId, onReady) {
        var conv = root._findConv(convId)
        if (!conv) { onReady(); return }

        var cache = root._summaryCache[convId]
        var foldedUpTo = cache ? cache.upToLen : 0
        var recentWindowLen = conv.messages.length - foldedUpTo

        if (recentWindowLen <= root.summarizeThreshold) { onReady(); return }

        var newCutIndex = conv.messages.length - root.keepRecentCount
        var toFold = conv.messages.slice(foldedUpTo, newCutIndex)
        if (toFold.length === 0) { onReady(); return }

        var priorSummary = cache ? cache.text : ""
        var prompt = (priorSummary
            ? "Previous summary of earlier conversation:\n" + priorSummary + "\n\n"
            : "") +
            "Summarize the following additional conversation turns concisely, " +
            "folding them into the previous summary if one is present. Preserve " +
            "any facts, decisions, or context needed to continue the conversation " +
            "naturally:\n\n" +
            toFold.map(function(m) { return m.role + ": " + m.text }).join("\n")

        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200) { onReady(); return }
            try {
                var data = JSON.parse(xhr.responseText)
                var summaryText = (data.message && data.message.content) || ""
                if (summaryText) {
                    var cache2 = Object.assign({}, root._summaryCache)
                    cache2[convId] = { upToLen: newCutIndex, text: summaryText }
                    root._summaryCache = cache2
                }
            } catch (e) { /* fall through — this turn sends full recent-window history, uncompressed */ }
            onReady()
        }
        xhr.open("POST", root.baseUrl + "/api/chat")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(JSON.stringify({
            model: root.activeModel,
            messages: [{ role: "user", content: prompt }],
            stream: false
        }))
    }

    readonly property var _webSearchTool: ({
        type: "function",
        function: {
            name: "web_search",
            description: "Search the web for current information not in your training data.",
            parameters: {
                type: "object",
                properties: { query: { type: "string", description: "The search query" } },
                required: ["query"]
            }
        }
    })

    readonly property var _readFileTool: ({
        type: "function",
        function: {
            name: "read_file",
            description: "Read a specific chunk of a file already attached to this conversation. Use when the automatically-provided context doesn't contain what you need.",
            parameters: {
                type: "object",
                properties: {
                    name: { type: "string", description: "The attachment's file name (as shown in its chip), e.g. \"src/foo.py\"" },
                    chunk_index: { type: "integer", description: "0-based chunk index. Omit or use 0 for the first chunk; the response reports how many chunks exist." }
                },
                required: ["name"]
            }
        }
    })

    function _runChat(convId, userText, citations) {
        var conv = root._findConv(convId)
        if (!conv) return

        var assistantMsg = { role: "assistant", text: "", streaming: true, citations: citations, toolCalling: false, toolQuery: "" }
        root.streamingText = ""
        root.streamingThinking = ""
        root.streamingThinkClosed = false
        root.streamingThinkSeconds = 0
        root._rawContent = ""
        root._thinkStartTime = 0
        root._thinkingCommitted = ""
        root._updateConv(convId, function(c) {
            c.messages = c.messages.concat([assistantMsg])
        })

        var summaryCache = root._summaryCache[convId]
        var sourceMessages = summaryCache ? conv.messages.slice(summaryCache.upToLen) : conv.messages
        var apiMessages = sourceMessages.map(function(m) {
            return { role: m.role, content: m.text }
        })
        if (citations.length > 0) {
            var context = citations.map(function(c) { return "[" + c.file + "]\n" + c.text }).join("\n\n")
            apiMessages.unshift({ role: "system", content: "Answer using this context when relevant, and only cite files actually used:\n\n" + context })
        }
        if (summaryCache) {
            apiMessages.unshift({ role: "system", content: "Earlier conversation summary: " + summaryCache.text })
        }

        // 3 rounds, not 1: read_file's own description invites paging
        // ("the response reports how many chunks exist"), so a single round
        // makes its advertised behaviour unreachable. 3 covers
        // read_file → read_file → answer and web_search → read_file → answer
        // while still bounding the loop.
        root._postChat(convId, apiMessages, root.toolRoundBudget)
    }

    function _postChat(convId, apiMessages, roundsLeft) {
        var xhr = new XMLHttpRequest()
        root._streamXhr = xhr
        var lastLen = 0
        var toolCalls = null
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.LOADING || xhr.readyState === XMLHttpRequest.DONE) {
                var chunk = xhr.responseText.slice(lastLen)
                lastLen = xhr.responseText.length
                chunk.split("\n").forEach(function(line) {
                    line = line.trim()
                    if (!line) return
                    try {
                        var data = JSON.parse(line)
                        if (data.message && data.message.thinking) {
                            if (root._thinkStartTime === 0) root._thinkStartTime = Date.now()
                            root.streamingThinking += data.message.thinking
                        }
                        if (data.message && data.message.content) {
                            if (root._nativeThinking) {
                                if (!root.streamingThinkClosed && root.streamingThinking.length > 0 && root._thinkStartTime !== 0) {
                                    root.streamingThinkClosed = true
                                    root.streamingThinkSeconds = Math.max(1, Math.round((Date.now() - root._thinkStartTime) / 1000))
                                }
                                root.streamingText += data.message.content
                            } else {
                                root._rawContent += data.message.content
                                var split = OllamaLogic.splitThinking(root._rawContent)
                                if (split.thinking.length > 0 && root._thinkStartTime === 0) root._thinkStartTime = Date.now()
                                root.streamingThinking = root._thinkingCommitted + split.thinking
                                root.streamingText = split.text
                                // Guarded on _thinkStartTime !== 0 so a reply with no
                                // <think> tag at all (split.closed is trivially true
                                // for plain text) doesn't latch streamingThinkClosed
                                // with a garbage Date.now()-0 "seconds" value.
                                if (split.closed && !root.streamingThinkClosed && root._thinkStartTime !== 0) {
                                    root.streamingThinkClosed = true
                                    root.streamingThinkSeconds = Math.max(1, Math.round((Date.now() - root._thinkStartTime) / 1000))
                                }
                            }
                        }
                        if (data.message && data.message.tool_calls && data.message.tool_calls.length > 0) {
                            toolCalls = data.message.tool_calls
                        }
                    } catch (e) { /* partial line, wait for more */ }
                })
            }
            if (xhr.readyState === XMLHttpRequest.DONE) {
                root._streamXhr = null
                if (toolCalls && toolCalls.length > 0 && roundsLeft > 0) {
                    root._runToolCall(convId, apiMessages, toolCalls[0], roundsLeft)
                    return
                }
                // Model still wanted a tool but the round budget is spent —
                // it never produced a final answer, so whatever we commit
                // below must not be a silently blank bubble.
                var toolBudgetExhausted = !!(toolCalls && toolCalls.length > 0)
                var finalText = root.streamingText
                var finalThinking = root.streamingThinking
                var finalThinkSeconds = root.streamingThinkSeconds
                root.streamingText = ""
                root.streamingThinking = ""
                root.streamingThinkClosed = false
                root.streamingThinkSeconds = 0
                root._rawContent = ""
                root._thinkStartTime = 0
                root._thinkingCommitted = ""
                root._updateConv(convId, function(c) {
                    var msgs = c.messages.slice()
                    var last = msgs[msgs.length - 1]
                    if (xhr.status !== 200 && finalText === "") {
                        msgs[msgs.length - 1] = Object.assign({}, last, { streaming: false, toolCalling: false, error: "Ollama request failed (" + xhr.status + ")" })
                    } else {
                        var extra = finalThinking.length > 0
                            ? { thinking: finalThinking, thinkingSeconds: finalThinkSeconds }
                            : {}
                        var commitText = finalText
                        if (commitText === "" && toolBudgetExhausted)
                            commitText = "(reached the tool-call limit for this turn without a final answer)"
                        msgs[msgs.length - 1] = Object.assign({}, last, { text: commitText, streaming: false, toolCalling: false }, extra)
                    }
                    c.messages = msgs
                })
            }
        }
        xhr.open("POST", root.baseUrl + "/api/chat")
        xhr.setRequestHeader("Content-Type", "application/json")
        var supportsThinking = (root._modelCapabilities[root.activeModel] || []).indexOf("thinking") !== -1
        root._nativeThinking = supportsThinking
        var body = { model: root.activeModel, messages: apiMessages, tools: [root._webSearchTool, root._readFileTool], stream: true }
        if (supportsThinking) body.think = true
        xhr.send(JSON.stringify(body))
    }

    function _runToolCall(convId, apiMessages, toolCall, roundsLeft) {
        var name = toolCall.function && toolCall.function.name
        if (name === "web_search") {
            root._runWebSearchTool(convId, apiMessages, toolCall, roundsLeft)
        } else if (name === "read_file") {
            root._runReadFileTool(convId, apiMessages, toolCall, roundsLeft)
        } else {
            root._continueAfterTool(convId, apiMessages, toolCall, "Unknown tool: " + name, [], roundsLeft)
        }
    }

    function _runWebSearchTool(convId, apiMessages, toolCall, roundsLeft) {
        var query = (toolCall.function && toolCall.function.arguments && toolCall.function.arguments.query) || ""
        root.streamingText = ""
        root._updateConv(convId, function(c) {
            var msgs = c.messages.slice()
            var last = msgs[msgs.length - 1]
            msgs[msgs.length - 1] = Object.assign({}, last, { toolCalling: true, toolQuery: query })
            c.messages = msgs
        })

        WebSearchService.search(query,
            function(results) {
                var webCitations = results.map(function(r) { return { kind: "web", title: r.title, url: r.url } })
                root._continueAfterTool(convId, apiMessages, toolCall, JSON.stringify(results), webCitations, roundsLeft)
            },
            function(errorText) {
                var toolContent = "Search unavailable: " + errorText + ". Answer from your own knowledge and note you couldn't verify with a live search."
                root._continueAfterTool(convId, apiMessages, toolCall, toolContent, [], roundsLeft)
            })
    }

    function _runReadFileTool(convId, apiMessages, toolCall, roundsLeft) {
        var args = (toolCall.function && toolCall.function.arguments) || {}
        var name = args.name || ""
        var conv = root._findConv(convId)
        var attachment = conv ? conv.attachments.find(function(a) { return a.name === name }) : null

        if (!attachment) {
            root._continueAfterTool(convId, apiMessages, toolCall, "No attachment named \"" + name + "\".", [], roundsLeft)
            return
        }
        if (attachment.status !== "ready") {
            root._continueAfterTool(convId, apiMessages, toolCall, "Attachment \"" + name + "\" is not ready (status: " + attachment.status + ").", [], roundsLeft)
            return
        }
        if (!attachment.chunks || attachment.chunks.length === 0) {
            root._continueAfterTool(convId, apiMessages, toolCall, "Attachment \"" + name + "\" has no readable content.", [], roundsLeft)
            return
        }

        var requestedIndex = typeof args.chunk_index === "number" ? Math.floor(args.chunk_index) : 0
        var index = Math.max(0, Math.min(requestedIndex, attachment.chunks.length - 1))
        var chunkText = attachment.chunks[index].text

        var toolContent = JSON.stringify({ text: chunkText, chunk_index: index, total_chunks: attachment.chunks.length })
        var citations = [{ kind: "file", file: name, text: chunkText }]
        root._continueAfterTool(convId, apiMessages, toolCall, toolContent, citations, roundsLeft)
    }

    function _continueAfterTool(convId, apiMessages, toolCall, toolContent, citations, roundsLeft) {
        var nextMessages = apiMessages.concat([
            { role: "assistant", content: "", tool_calls: [toolCall] },
            { role: "tool", content: toolContent }
        ])

        // Round boundary for the fallback (<think>-tag) path: carry forward
        // whatever reasoning has accumulated so far (streamingThinking already
        // includes _thinkingCommitted from any earlier round) so it survives
        // the _rawContent reset below, instead of the next round's fresh
        // <think> block re-splitting against a stale buffer that still holds
        // this round's already-closed tag pair (which leaked literal
        // "<think>"/"</think>" text and stuck reasoning at round 1's content).
        // Native-thinking models don't touch _rawContent/_thinkingCommitted at
        // all (their streamingThinking is already append-only), so this is a
        // no-op for them.
        root._thinkingCommitted = root.streamingThinking
        root._rawContent = ""
        root.streamingText = ""

        root._updateConv(convId, function(c) {
            var msgs = c.messages.slice()
            var last = msgs[msgs.length - 1]
            msgs[msgs.length - 1] = Object.assign({}, last, {
                toolCalling: false,
                citations: (last.citations || []).concat(citations)
            })
            c.messages = msgs
        })

        root._postChat(convId, nextMessages, roundsLeft - 1)
    }

    function stopStreaming() {
        if (root._streamXhr) root._streamXhr.abort()
    }
}
