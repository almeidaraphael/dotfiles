const test = require('node:test')
const assert = require('node:assert/strict')
const { parseSearxJson, parseDdgHtml } = require('./webSearchParse.js')

test('parseSearxJson extracts title/url/snippet from SearxNG JSON response', () => {
    const raw = JSON.stringify({
        results: [
            { title: 'Result One', url: 'https://example.com/one', content: 'First snippet' },
            { title: 'Result Two', url: 'https://example.com/two', content: 'Second snippet' }
        ]
    })
    const results = parseSearxJson(raw)
    assert.equal(results.length, 2)
    assert.deepEqual(results[0], { title: 'Result One', url: 'https://example.com/one', snippet: 'First snippet' })
})

test('parseSearxJson caps results at 5', () => {
    const raw = JSON.stringify({
        results: Array.from({ length: 10 }, (_, i) => ({
            title: 'Result ' + i, url: 'https://example.com/' + i, content: 'Snippet ' + i
        }))
    })
    assert.equal(parseSearxJson(raw).length, 5)
})

test('parseSearxJson returns empty array for malformed JSON', () => {
    assert.deepEqual(parseSearxJson('not json'), [])
})

test('parseSearxJson returns empty array when results field is missing', () => {
    assert.deepEqual(parseSearxJson(JSON.stringify({})), [])
})

test('parseDdgHtml extracts title/url/snippet from DuckDuckGo HTML results page', () => {
    const html = `
        <div class="result">
            <a class="result__a" href="https://example.com/foo">Foo Title</a>
            <a class="result__snippet">Foo snippet text</a>
        </div>
        <div class="result">
            <a class="result__a" href="https://example.com/bar">Bar Title</a>
            <a class="result__snippet">Bar snippet text</a>
        </div>
    `
    const results = parseDdgHtml(html)
    assert.equal(results.length, 2)
    assert.deepEqual(results[0], { title: 'Foo Title', url: 'https://example.com/foo', snippet: 'Foo snippet text' })
    assert.deepEqual(results[1], { title: 'Bar Title', url: 'https://example.com/bar', snippet: 'Bar snippet text' })
})

test('parseDdgHtml caps results at 5', () => {
    const html = Array.from({ length: 10 }, (_, i) => `
        <div class="result">
            <a class="result__a" href="https://example.com/${i}">Title ${i}</a>
            <a class="result__snippet">Snippet ${i}</a>
        </div>
    `).join('\n')
    assert.equal(parseDdgHtml(html).length, 5)
})

test('parseDdgHtml returns empty array when there are no results', () => {
    assert.deepEqual(parseDdgHtml('<html><body>no results here</body></html>'), [])
})
