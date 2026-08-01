function fuzzyScore(query, target) {
    if (query.length === 0) return 0

    var qi = 0
    var score = 0
    var consecutive = 0
    var firstMatch = -1
    var lastMatch = -1

    for (var ti = 0; ti < target.length && qi < query.length; ti++) {
        if (target[ti] === query[qi]) {
            if (firstMatch === -1) firstMatch = ti
            lastMatch = ti
            score += 1

            var atBoundary = ti === 0 || target[ti - 1] === " " || target[ti - 1] === "-" || target[ti - 1] === "_"
            if (atBoundary) score += 8
            if (consecutive > 0) score += 5
            consecutive += 1
            qi += 1
        } else {
            consecutive = 0
        }
    }

    if (qi < query.length) return null

    var span = lastMatch - firstMatch + 1
    return score - span * 0.1
}

if (typeof module !== "undefined") module.exports = { fuzzyScore: fuzzyScore }
