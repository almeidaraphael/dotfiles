const test = require('node:test')
const assert = require('node:assert/strict')
const { splitThinking, chunkText, cosine, topChunks } = require('./ollamaLogic.js')

test('splitThinking: no think tag at all', () => {
    const r = splitThinking('just plain text')
    assert.deepEqual(r, { thinking: '', text: 'just plain text', closed: true })
})

test('splitThinking: open tag with no close (still streaming)', () => {
    const r = splitThinking('before<think>reasoning so far')
    assert.equal(r.thinking, 'reasoning so far')
    assert.equal(r.text, 'before')
    assert.equal(r.closed, false)
})

test('splitThinking: open and close tag present', () => {
    const r = splitThinking('before<think>reasoning</think>after')
    assert.equal(r.thinking, 'reasoning')
    assert.equal(r.text, 'beforeafter')
    assert.equal(r.closed, true)
})

test('chunkText: text shorter than chunk size is a single chunk', () => {
    const chunks = chunkText('short text', 2000, 200)
    assert.deepEqual(chunks, ['short text'])
})

test('chunkText: overlap produces expected boundaries', () => {
    const chunks = chunkText('abcdefghij', 4, 1)
    assert.deepEqual(chunks, ['abcd', 'defg', 'ghij'])
})

test('cosine: identical vectors score 1', () => {
    assert.equal(cosine([1, 0], [1, 0]), 1)
})

test('cosine: orthogonal vectors score 0', () => {
    assert.equal(cosine([1, 0], [0, 1]), 0)
})

test('cosine: zero vector returns 0, not NaN', () => {
    assert.equal(cosine([0, 0], [1, 1]), 0)
})

test('topChunks: filters below threshold and respects k', () => {
    const conv = {
        attachments: [
            { status: 'ready', name: 'a.txt', chunks: [
                { text: 'high match', embedding: [1, 0] },
                { text: 'low match', embedding: [0, 1] }
            ] },
            { status: 'embedding', name: 'b.txt', chunks: [
                { text: 'not ready yet', embedding: [1, 0] }
            ] }
        ]
    }
    const results = topChunks(conv, [1, 0], 5, 0.3)
    assert.equal(results.length, 1)
    assert.equal(results[0].text, 'high match')
})
