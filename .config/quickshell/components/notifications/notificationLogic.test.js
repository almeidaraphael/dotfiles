const test = require('node:test')
const assert = require('node:assert/strict')
const { iconSource, splitActions, shouldAutoDismiss, actionDisplay, resolveAppIcon, resolveNotificationIcon, extractBodyImage, resolveNotificationBanner } = require('./notificationLogic.js')

test('iconSource returns empty string for empty or missing icon', () => {
    assert.equal(iconSource("", (n) => "should-not-be-called"), "")
    assert.equal(iconSource(undefined, (n) => "should-not-be-called"), "")
})

test('iconSource treats absolute paths as direct sources', () => {
    assert.equal(iconSource("/usr/share/icons/foo.png", (n) => "wrong"), "/usr/share/icons/foo.png")
})

test('iconSource treats file:// URLs as direct sources', () => {
    assert.equal(iconSource("file:///tmp/foo.png", (n) => "wrong"), "file:///tmp/foo.png")
})

test('iconSource resolves theme names via the provided resolver', () => {
    assert.equal(iconSource("firefox", (name) => "resolved:" + name), "resolved:firefox")
})

test('splitActions pulls out the default action and keeps the rest as buttons', () => {
    const actions = [
        { identifier: "default", text: "Open" },
        { identifier: "reply", text: "Reply" },
        { identifier: "dismiss", text: "Dismiss" }
    ]
    const result = splitActions(actions)
    assert.equal(result.defaultAction.identifier, "default")
    assert.equal(result.buttonActions.length, 2)
    assert.deepEqual(result.buttonActions.map(a => a.identifier), ["reply", "dismiss"])
})

test('splitActions returns null defaultAction when none present', () => {
    const result = splitActions([{ identifier: "reply", text: "Reply" }])
    assert.equal(result.defaultAction, null)
    assert.equal(result.buttonActions.length, 1)
})

test('splitActions handles an empty actions list', () => {
    const result = splitActions([])
    assert.equal(result.defaultAction, null)
    assert.deepEqual(result.buttonActions, [])
})

test('shouldAutoDismiss is false for critical urgency', () => {
    assert.equal(shouldAutoDismiss(2), false)
})

test('shouldAutoDismiss is true for normal and low urgency', () => {
    assert.equal(shouldAutoDismiss(1), true)
    assert.equal(shouldAutoDismiss(0), true)
})

test('shouldAutoDismiss is false when expireTimeout is 0 (never expire), regardless of urgency', () => {
    assert.equal(shouldAutoDismiss(1, 0), false)
    assert.equal(shouldAutoDismiss(0, 0), false)
})

test('shouldAutoDismiss ignores expireTimeout of -1 (server default) and falls back to urgency', () => {
    assert.equal(shouldAutoDismiss(1, -1), true)
    assert.equal(shouldAutoDismiss(2, -1), false)
})

test('shouldAutoDismiss ignores a missing expireTimeout argument', () => {
    assert.equal(shouldAutoDismiss(1, undefined), true)
})

test('actionDisplay uses the action identifier as an icon name when hasActionIcons is true', () => {
    const result = actionDisplay({ identifier: "mail-reply", text: "Reply" }, true)
    assert.deepEqual(result, { mode: "icon", value: "mail-reply" })
})

test('actionDisplay uses the action text when hasActionIcons is false', () => {
    const result = actionDisplay({ identifier: "mail-reply", text: "Reply" }, false)
    assert.deepEqual(result, { mode: "text", value: "Reply" })
})

test('resolveAppIcon prefers desktopEntry over everything else', () => {
    const result = resolveAppIcon({
        desktopEntry: "google-chrome",
        icon: "https://push.foo/images/logo.jpg",
        appName: "Google Chrome"
    })
    assert.equal(result, "google-chrome")
})

test('resolveAppIcon resolves desktopEntry through the real .desktop entry when its icon differs from its id (e.g. "code" -> "vscode")', () => {
    const result = resolveAppIcon(
        { desktopEntry: "code", icon: "", appName: "Visual Studio Code" },
        (id) => id === "code" ? { id: "code", icon: "vscode" } : null
    )
    assert.equal(result, "vscode")
})

test('resolveAppIcon falls back to the raw desktopEntry id when no .desktop entry matches it', () => {
    const result = resolveAppIcon(
        { desktopEntry: "some-unknown-app", icon: "", appName: "Some App" },
        () => null
    )
    assert.equal(result, "some-unknown-app")
})

test('resolveAppIcon falls back to a local icon (theme name or path) when there is no desktopEntry', () => {
    assert.equal(resolveAppIcon({ desktopEntry: "", icon: "firefox", appName: "Firefox" }), "firefox")
    assert.equal(resolveAppIcon({ desktopEntry: "", icon: "/usr/share/icons/foo.png", appName: "Foo" }), "/usr/share/icons/foo.png")
})

test('resolveAppIcon rejects a remote URL icon and falls back to appName', () => {
    const result = resolveAppIcon({
        desktopEntry: "",
        icon: "https://push.foo/images/logo.jpg",
        appName: "Google Chrome"
    })
    assert.equal(result, "Google Chrome")
})

test('resolveAppIcon returns empty string when nothing usable is available', () => {
    assert.equal(resolveAppIcon({ desktopEntry: "", icon: "", appName: "" }), "")
    assert.equal(resolveAppIcon({}), "")
})

test('resolveNotificationIcon prefers the notification image when it resolved from an image-path hint (Chrome-style favicon, image://icon/... url)', () => {
    const result = resolveNotificationIcon({
        desktopEntry: "google-chrome",
        icon: "google-chrome",
        image: "image://icon//tmp/scoped_dir/icon.png",
        appName: "Google Chrome"
    }, (name) => "should-not-be-called:" + name)
    assert.equal(result, "image://icon//tmp/scoped_dir/icon.png")
})

test('resolveNotificationIcon ignores a raw-pixmap image (Firefox-style, image://qsimage/... url, no separate icon) and falls back to the generic app icon', () => {
    const result = resolveNotificationIcon({
        desktopEntry: "firefox",
        icon: "",
        image: "image://qsimage/1/1",
        appName: "Firefox"
    }, (name) => "resolved:" + name)
    assert.equal(result, "resolved:firefox")
})

test('resolveNotificationIcon falls back to resolveAppIcon+iconSource when there is no notification image', () => {
    const result = resolveNotificationIcon({
        desktopEntry: "google-chrome",
        icon: "google-chrome",
        image: "",
        appName: "Google Chrome"
    }, (name) => "resolved:" + name)
    assert.equal(result, "resolved:google-chrome")
})

test('resolveNotificationIcon falls back to a heuristic appName match when the direct icon does not resolve in the theme', () => {
    const result = resolveNotificationIcon(
        { desktopEntry: "", icon: "some-nonexistent-icon-name", image: "", appName: "Visual Studio Code" },
        (name) => name === "vscode" ? "resolved:vscode" : "",
        () => null,
        (appName) => appName === "Visual Studio Code" ? { id: "code", icon: "vscode" } : null
    )
    assert.equal(result, "resolved:vscode")
})

test('resolveNotificationIcon returns empty string when neither direct resolution nor the appName heuristic finds anything', () => {
    const result = resolveNotificationIcon(
        { desktopEntry: "", icon: "some-nonexistent-icon-name", image: "", appName: "Some Unknown App" },
        () => "",
        () => null,
        () => null
    )
    assert.equal(result, "")
})

test('extractBodyImage pulls the src out of an embedded img tag and strips it from the text', () => {
    const body = '<a href="https://push.foo/">push.foo</a>\n\nTest notification body\n<img src="file:///tmp/scoped_dir/image.png" alt=""/>'
    const result = extractBodyImage(body)
    assert.equal(result.image, "file:///tmp/scoped_dir/image.png")
    assert.equal(result.text, '<a href="https://push.foo/">push.foo</a>\n\nTest notification body')
})

test('extractBodyImage returns the body unchanged when there is no img tag', () => {
    const body = "Just plain text, no markup here."
    const result = extractBodyImage(body)
    assert.equal(result.image, "")
    assert.equal(result.text, body)
})

test('extractBodyImage handles missing or empty body', () => {
    assert.deepEqual(extractBodyImage(""), { image: "", text: "" })
    assert.deepEqual(extractBodyImage(undefined), { image: "", text: "" })
})

test('resolveNotificationBanner uses the notification image when it is a raw pixmap (Firefox-style, image://qsimage/... url, no body markup)', () => {
    const result = resolveNotificationBanner({
        image: "image://qsimage/1/1",
        body: "Test notification body"
    })
    assert.equal(result, "image://qsimage/1/1")
})

test('resolveNotificationBanner falls back to the body-embedded image when the notification image is an icon-file reference (Chrome-style, image://icon/... url)', () => {
    const result = resolveNotificationBanner({
        image: "image://icon//tmp/scoped_dir/icon.png",
        body: '<a href="https://push.foo/">push.foo</a>\n\nTest notification body\n<img src="file:///tmp/scoped_dir/image.png" alt=""/>'
    })
    assert.equal(result, "file:///tmp/scoped_dir/image.png")
})

test('resolveNotificationBanner returns empty string when there is neither a raw-pixmap image nor a body-embedded image', () => {
    const result = resolveNotificationBanner({
        image: "",
        body: "Just plain text, no markup here."
    })
    assert.equal(result, "")
})
