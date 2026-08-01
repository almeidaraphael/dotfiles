pragma Singleton
import QtQuick
import Quickshell.Io
import ".."
import "webSearchParse.js" as WebSearchParse

// SearxNG JSON API primary, DuckDuckGo HTML scrape fallback when SearxNG is
// unreachable or errors. No persistence — same session-scoped tradeoff as
// the rest of the Assistant panel's services.
QtObject {
    id: root

    property string searxUrl: ConfigService.searxUrl

    function search(query, onDone, onFail) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200) {
                root._searchDdg(query, onDone, onFail)
                return
            }
            var results = WebSearchParse.parseSearxJson(xhr.responseText)
            if (results.length === 0) {
                root._searchDdg(query, onDone, onFail)
                return
            }
            onDone(results)
        }
        xhr.open("GET", root.searxUrl + "/search?q=" + encodeURIComponent(query) + "&format=json&categories=general")
        xhr.send()
    }

    function _searchDdg(query, onDone, onFail) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200) {
                onFail("DuckDuckGo request failed (" + xhr.status + ")")
                return
            }
            var results = WebSearchParse.parseDdgHtml(xhr.responseText)
            if (results.length === 0) {
                onFail("No search results found")
                return
            }
            onDone(results)
        }
        xhr.open("GET", "https://html.duckduckgo.com/html/?q=" + encodeURIComponent(query))
        xhr.send()
    }
}
