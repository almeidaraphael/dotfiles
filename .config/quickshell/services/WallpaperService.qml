pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

QtObject {
    id: root

    property var current: ConfigService.activeWallpapers || ({})
    property var wallpapers: []

    function currentFor(monitor) { return root.current[monitor] || "" }

    property var _themeConn: Connections {
        target: ThemeManager
        function onActiveChanged() { root.rescan() }
    }

    property var _cycleTimer: Timer {
        interval: (ConfigService.wallpaperInterval || 600) * 1000
        running: ConfigService.wallpaperMode === "random"
        repeat: true
        onTriggered: {
            for (var i = 0; i < Quickshell.screens.length; i++)
                root.setRandom(Quickshell.screens[i].name)
        }
    }

    property var _scanLines: []

    property var _scanner: Process {
        id: scanner
        stdout: SplitParser {
            onRead: function(d) { if (d) root._scanLines.push(d) }
        }
        onExited: {
            root.wallpapers = root._scanLines.filter(Boolean)
            root._scanLines = []
        }
    }

    // Opt-in: rescan is async, so callers that need a wallpaper assigned
    // right after a theme switch (rather than just refreshing the picker
    // list) call this instead of rescan() directly. Guarded by a flag so
    // plain rescan() callers (startup, filmstrip browsing) don't have
    // wallpapers reassigned out from under them.
    property bool _pendingAutoAssign: false

    function autoAssignAfterRescan() {
        root._pendingAutoAssign = true
        root.rescan()
    }

    onWallpapersChanged: {
        if (!root._pendingAutoAssign) return
        root._pendingAutoAssign = false
        if (root.wallpapers.length === 0) return
        var screens = Quickshell.screens
        for (var i = 0; i < screens.length; i++)
            root.set(root.wallpapers[i % root.wallpapers.length], screens[i].name)
    }

    Component.onCompleted: {
        rescan()
        for (var i = 0; i < Quickshell.screens.length; i++) {
            var name = Quickshell.screens[i].name
            if (root.current[name]) _apply(root.current[name], name)
        }
        _writeLockWallpaper()
    }

    // hyprlock.conf has no live IPC, so the lock screen's wallpaper is kept
    // in sync via this generated var file (same pattern as active-theme.conf)
    // rather than hyprlock's own reload_cmd, which has known crash reports
    // (hyprwm/hyprlock#733) on the background widget.
    function _writeLockWallpaper() {
        var screens = Quickshell.screens
        var primary = screens.length > 0 ? screens[0].name : ""
        var path = root.current[primary]
        if (!path) {
            var vals = Object.values(root.current)
            path = vals.length > 0 ? vals[0] : ""
        }
        if (!path) return
        var home = ConfigService.homeDir.replace(/^file:\/\//, "")
        var target = home + "/.config/hypr/active-wallpaper.conf"
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
        proc.command = ["bash", "-c", "printf '$lockWallpaper = %s\\n' \"$1\" > \"$2\"", "_", path, target]
        proc.running = true
    }

    function rescan() {
        if (!ThemeManager || !ThemeManager.active) return
        var wallDir = ThemeManager.active.wallpaperDir
        var home = ConfigService.homeDir.replace(/^file:\/\//, "")
        var dir = wallDir.startsWith("/") ? wallDir
                : wallDir.startsWith("~") ? wallDir.replace("~", home)
                : (home + "/Pictures/wallpapers/" + wallDir)
        root._scanLines = []
        scanner.command = ["bash", "-c",
            "find -L " + JSON.stringify(dir) +
            " -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png'" +
            " -o -iname '*.webp' -o -iname '*.gif' \\) 2>/dev/null | sort"]
        scanner.running = true
    }

    function set(path, monitor) {
        var next = {}
        for (var key in current) next[key] = current[key]
        next[monitor] = path
        current = next
        ConfigService.activeWallpapers = next
        ConfigService.save()
        _apply(path, monitor)
        _writeLockWallpaper()
    }

    function setRandom(monitor) {
        if (wallpapers.length === 0) return
        var idx = Math.floor(Math.random() * wallpapers.length)
        set(wallpapers[idx], monitor)
    }

    function _apply(path, monitor) {
        var cmd = ["awww", "img", path, "--transition-type", "wipe",
                   "--transition-duration", "1"]
        if (monitor) cmd.push("-o", monitor)
        ProcessRunner.run(cmd, { appName: "Wallpaper", onFailureSummary: "Couldn't set wallpaper" })
    }
}
