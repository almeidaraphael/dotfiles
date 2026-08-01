function parseSearxJson(responseText) {
    var data
    try {
        data = JSON.parse(responseText)
    } catch (e) {
        return []
    }
    var results = data && Array.isArray(data.results) ? data.results : []
    return results.slice(0, 5).map(function(r) {
        return { title: r.title || "", url: r.url || "", snippet: r.content || "" }
    })
}

function parseDdgHtml(html) {
    var results = []
    var linkRe = /<a class="result__a" href="([^"]*)"[^>]*>([\s\S]*?)<\/a>/
    var snippetRe = /<a class="result__snippet"[^>]*>([\s\S]*?)<\/a>/

    var blockMatch
    var re = /<div class="result">([\s\S]*?)(?=<div class="result">|$)/g
    while ((blockMatch = re.exec(html)) !== null && results.length < 5) {
        var block = blockMatch[1]
        var linkMatch = linkRe.exec(block)
        if (!linkMatch) continue
        var snippetMatch = snippetRe.exec(block)
        results.push({
            title: linkMatch[2].replace(/<[^>]+>/g, "").trim(),
            url: linkMatch[1],
            snippet: snippetMatch ? snippetMatch[1].replace(/<[^>]+>/g, "").trim() : ""
        })
    }
    return results
}

if (typeof module !== "undefined") module.exports = { parseSearxJson: parseSearxJson, parseDdgHtml: parseDdgHtml }
