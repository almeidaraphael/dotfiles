pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

QtObject {
    id: root

    // entries: { type: "text", text } | { type: "file", text: rawUriList } | { type: "image", path }
    property var history: []
    readonly property int _maxHistory: 50

    // Quickshell.clipboardText wraps Qt's QClipboard, which on Wayland only
    // reflects the selection while this shell holds keyboard focus (layer
    // surfaces rarely do). wl-paste --watch uses wlr-data-control to observe
    // every selection change regardless of focus, so watch it instead.
    //
    // Three watchers run in parallel, one per mime type. wl-paste invokes its
    // callback on every clipboard change regardless of the requested type —
    // if the change isn't that type, the callback gets empty stdin, which all
    // three scripts detect and skip. So exactly one watcher normally produces
    // an entry per real clipboard change, keeping history chronological
    // without the processes needing to coordinate. (A source that advertises
    // more than one of these mime types at once — some file managers pair
    // text/uri-list with a text/plain path — will still produce a duplicate
    // entry per type; not worth solving without a concrete repro.)
    property var _textWatcher: Process {
        id: textWatcher
        command: ["wl-paste", "--type", "text", "--no-newline", "--watch",
                  "sh", "-c", "printf '%s\\036' \"$(cat)\""]
        stdout: SplitParser {
            splitMarker: "\x1e"
            onRead: function(data) {
                var text = data.trim()
                if (!text) return
                root._pushEntry({ type: "text", text: text }, function(e) {
                    return e.type === "text" && e.text === text
                })
            }
        }
    }

    // File manager copies (Nautilus, Thunar, Dolphin, ...) put file:// URIs
    // on the clipboard as text/uri-list, not text/plain, so they need a
    // dedicated watcher — "text" above does not match that mime type.
    property var _fileWatcher: Process {
        id: fileWatcher
        command: ["wl-paste", "--type", "text/uri-list", "--no-newline", "--watch",
                  "sh", "-c", "printf '%s\\036' \"$(cat)\""]
        stdout: SplitParser {
            splitMarker: "\x1e"
            onRead: function(data) {
                var text = data.trim()
                if (!text) return
                root._pushEntry({ type: "file", text: text }, function(e) {
                    return e.type === "file" && e.text === text
                })
            }
        }
    }

    property var _imageWatcher: Process {
        id: imageWatcher
        command: ["wl-paste", "--type", "image/png", "--watch",
                  "sh", "-c",
                  "mkdir -p \"$HOME/.cache/quickshell/clipboard\"; " +
                  "f=\"$HOME/.cache/quickshell/clipboard/$(date +%s%N).png\"; " +
                  "cat > \"$f\"; " +
                  "[ -s \"$f\" ] && printf '%s\\036' \"$f\" || rm -f \"$f\""]
        stdout: SplitParser {
            splitMarker: "\x1e"
            onRead: function(path) {
                path = path.trim()
                if (!path) return
                root._pushEntry({ type: "image", path: path }, function(e) { return false })
            }
        }
    }

    Component.onCompleted: {
        textWatcher.running = true
        fileWatcher.running = true
        imageWatcher.running = true
    }

    // "file:///a/b.txt\r\nfile:///a/c.pdf" -> ["b.txt", "c.pdf"]
    function fileNames(rawUriList) {
        return rawUriList.split(/\r?\n/)
            .filter(function(l) { return l && l[0] !== "#" })
            .map(function(l) {
                var path = l.replace(/^file:\/\//, "")
                try { path = decodeURIComponent(path) } catch (e) {}
                var parts = path.split("/")
                return parts[parts.length - 1]
            })
    }

    function _pushEntry(entry, matchesExisting) {
        var idx = -1
        for (var i = 0; i < root.history.length; i++) {
            if (matchesExisting(root.history[i])) { idx = i; break }
        }
        if (idx !== -1) root.history.splice(idx, 1)
        root.history.unshift(entry)
        if (root.history.length > root._maxHistory) {
            var evicted = root.history.splice(root._maxHistory)
            for (var j = 0; j < evicted.length; j++) {
                if (evicted[j].type === "image") _deleteFile(evicted[j].path)
            }
        }
        root.historyChanged()
    }

    function _deleteFile(path) {
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
        p.command = ["rm", "-f", path]
        p.startDetached()
    }

    function clear() {
        for (var i = 0; i < history.length; i++) {
            if (history[i].type === "image") _deleteFile(history[i].path)
        }
        history = []
        historyChanged()
    }

    function remove(index) {
        var entry = history[index]
        if (entry && entry.type === "image") _deleteFile(entry.path)
        history.splice(index, 1)
        historyChanged()
    }

    // Always goes through the wl-copy CLI (wlr-data-control), matching what
    // the watchers above read with. wl-copy daemonizes itself to keep
    // serving the selection after this process exits, and — unlike Qt's
    // QClipboard — does not require this window to hold keyboard focus at
    // the moment of the call, so it stays correct even if focus already
    // moved on by the time this runs.
    //
    // entry.text is raw clipboard content — it can contain anything the user
    // ever copied (page text, shell snippets, etc). Never splice it into a
    // shell string (JSON.stringify escapes quotes for JS, not `$`/backticks
    // for bash — that was a command-injection hole). Feed it to wl-copy's
    // stdin directly instead; no shell involved. entry.path (image type) is
    // self-generated by _imageWatcher under ~/.cache, not attacker-facing,
    // so the bash redirect there only needs the positional-arg quoting
    // already used in WallpaperService._writeLockWallpaper.
    function copy(entry) {
        if (entry.type === "image") {
            var p = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
            p.command = ["bash", "-c", "wl-copy --type image/png < \"$1\"", "_", entry.path]
            p.startDetached()
            return
        }
        var p2 = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
        p2.command = entry.type === "file" ? ["wl-copy", "--type", "text/uri-list"] : ["wl-copy"]
        p2.stdinEnabled = true
        p2.exited.connect(function() { p2.destroy() })
        p2.running = true
        p2.write(entry.text)
        p2.stdinEnabled = false
    }
}
