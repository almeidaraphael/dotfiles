const test = require('node:test')
const assert = require('node:assert/strict')
const { fuzzyScore } = require('./fuzzy.js')

test('rejects when a query character is missing from the target', () => {
    assert.equal(fuzzyScore('vsc', 'gimp'), null)
})

test('matches a subsequence scattered across the target', () => {
    assert.notEqual(fuzzyScore('vsc', 'visual studio code'), null)
})

test('empty query matches everything with score 0', () => {
    assert.equal(fuzzyScore('', 'anything'), 0)
})

test('ranks word-boundary acronym matches above buried consecutive matches', () => {
    const acronymScore = fuzzyScore('vsc', 'visual studio code')
    const buriedScore = fuzzyScore('vsc', 'devscripts')
    assert.ok(acronymScore > buriedScore, `expected ${acronymScore} > ${buriedScore}`)
})

test('rejects out-of-order characters', () => {
    assert.equal(fuzzyScore('csv', 'visual studio code'), null)
})
