pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Manual GPU-load-reduction toggle for running heavy compute jobs (e.g.
// ComfyUI) on the same GPU that drives the desktop. A real amdgpu ring
// hang during a ComfyUI VAE decode crashed Hyprland once — see
// docs/superpowers/specs/2026-08-01-low-resource-mode-design.md.
QtObject {
    id: root

    property bool active: false

    function toggle() {
        root.active = !root.active
        if (root.active) root.enable()
        else root.disable()
    }

    function enable() {
        _hyprConfig('{ decoration = { blur = { enabled = false } } }')
        _hyprConfig('{ decoration = { shadow = { enabled = false } } }')
        _hyprConfig('{ animations = { enabled = false } }')
        _run(["pkill", "-x", "awww-daemon"])
    }

    function disable() {
        _hyprConfig('{ decoration = { blur = { enabled = true } } }')
        _hyprConfig('{ decoration = { shadow = { enabled = true } } }')
        _hyprConfig('{ animations = { enabled = true } }')
        _run(["awww-daemon"])
        _restoreWallpapers()
    }

    function _run(cmd) {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
        proc.command = cmd
        proc.startDetached()
    }

    function _hyprConfig(luaTable) {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
        proc.command = ["hyprctl", "eval", "hl.config(" + luaTable + ")"]
        proc.startDetached()
    }

    // awww-daemon needs a moment to come up before it can accept `awww img`
    // calls from WallpaperService.set() — matches the transition duration
    // WallpaperService._apply() already uses for its own wipe transition.
    function _restoreWallpapers() {
        _restoreTimer.start()
    }

    property var _restoreTimer: Timer {
        interval: 1000
        repeat: false
        onTriggered: {
            var current = WallpaperService.current
            for (var monitor in current) {
                if (current[monitor]) WallpaperService.set(current[monitor], monitor)
            }
        }
    }
}
