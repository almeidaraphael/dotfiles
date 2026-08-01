const test = require('node:test')
const assert = require('node:assert/strict')
const { parseDesktopLine, dedupeAppsByName } = require('./desktopEntries.js')

test('parses a well-formed unit-separated line', () => {
    const line = 'Visual Studio Code\x1fvscode\x1f/usr/bin/code'
    assert.deepEqual(parseDesktopLine(line), { name: 'Visual Studio Code', icon: 'vscode', exec: '/usr/bin/code' })
})

test('parses a line with an empty icon field', () => {
    const line = 'No Icon App\x1f\x1f/usr/bin/noiconapp'
    assert.deepEqual(parseDesktopLine(line), { name: 'No Icon App', icon: '', exec: '/usr/bin/noiconapp' })
})

test('dedupeAppsByName keeps the first occurrence of a name', () => {
    const entries = [
        { name: 'Foo', icon: 'local-icon', exec: '/local/foo' },
        { name: 'Foo', icon: 'system-icon', exec: '/usr/bin/foo' },
        { name: 'Bar', icon: '', exec: '/usr/bin/bar' }
    ]
    assert.deepEqual(dedupeAppsByName(entries), [
        { name: 'Foo', icon: 'local-icon', exec: '/local/foo' },
        { name: 'Bar', icon: '', exec: '/usr/bin/bar' }
    ])
})

test('dedupeAppsByName drops entries with an empty name', () => {
    assert.deepEqual(dedupeAppsByName([{ name: '', icon: '', exec: '/bin/x' }]), [])
})
