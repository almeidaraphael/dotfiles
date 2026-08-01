function parseDesktopLine(line) {
    var parts = line.split("\x1f")
    return { name: parts[0] || "", icon: parts[1] || "", exec: parts[2] || "" }
}

function dedupeAppsByName(entries) {
    var seen = {}
    var result = []
    for (var i = 0; i < entries.length; i++) {
        var e = entries[i]
        if (!e.name || seen[e.name]) continue
        seen[e.name] = true
        result.push(e)
    }
    return result
}

if (typeof module !== "undefined") module.exports = { parseDesktopLine: parseDesktopLine, dedupeAppsByName: dedupeAppsByName }
