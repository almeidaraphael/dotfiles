// Fallback-path only: reasoning already closed out in a prior tool-call
// round is carried forward by the caller (see OllamaService._continueAfterTool)
// so it isn't lost when the raw-content buffer resets at the next round
// boundary.
function splitThinking(raw) {
    var openTag = "<think>", closeTag = "</think>"
    var openIdx = raw.indexOf(openTag)
    if (openIdx === -1) return { thinking: "", text: raw, closed: true }
    var afterOpen = raw.slice(openIdx + openTag.length)
    var closeIdx = afterOpen.indexOf(closeTag)
    if (closeIdx === -1) return { thinking: afterOpen, text: raw.slice(0, openIdx), closed: false }
    return {
        thinking: afterOpen.slice(0, closeIdx),
        text: raw.slice(0, openIdx) + afterOpen.slice(closeIdx + closeTag.length),
        closed: true
    }
}

function chunkText(text, size, overlap) {
    var chunks = []
    var i = 0
    while (i < text.length) {
        chunks.push(text.slice(i, i + size))
        if (i + size >= text.length) break
        i += (size - overlap)
    }
    return chunks
}

function cosine(a, b) {
    var dot = 0, na = 0, nb = 0
    for (var i = 0; i < a.length; i++) { dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i] }
    if (na === 0 || nb === 0) return 0
    return dot / (Math.sqrt(na) * Math.sqrt(nb))
}

function topChunks(conv, queryEmbedding, k, scoreThreshold) {
    var scored = []
    conv.attachments.forEach(function(att) {
        if (att.status !== "ready") return
        att.chunks.forEach(function(c) {
            scored.push({ kind: "file", file: att.name, text: c.text, score: cosine(queryEmbedding, c.embedding) })
        })
    })
    scored.sort(function(a, b) { return b.score - a.score })
    return scored.slice(0, k).filter(function(s) { return s.score > scoreThreshold })
}

if (typeof module !== "undefined") module.exports = { splitThinking: splitThinking, chunkText: chunkText, cosine: cosine, topChunks: topChunks }
