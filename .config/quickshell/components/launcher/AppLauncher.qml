import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../.."
import "../shared"
import "fuzzy.js" as Fuzzy
import "desktopEntries.js" as DesktopEntries

PanelWindow {
    id: root

    focusable: true
    screen: PanelManager.activeScreen
    anchors { bottom: true }
    implicitWidth: 560
    implicitHeight: resultsVisible ? 480 : 72
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    // open: 20px above bottom; closed: (height+5)px below screen edge
    margins.bottom: Tokens.spaceXl * (1 - root.offsetScale) - (root.implicitHeight + 5) * root.offsetScale

    property bool _open: false
    property real offsetScale: _open ? 0 : 1
    visible: _open || offsetScale < 0.99

    Behavior on offsetScale {
        enabled: !ConfigService.reduceMotion
        NumberAnimation { duration: Tokens.durationNormal; easing.type: Tokens.easeOut }
    }

    Behavior on height { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationFast; easing.type: Tokens.easeOut } }

    property var  apps:           []
    property var  results:        []
    property int  selectedIndex:  0
    property bool resultsVisible: results.length > 0

    property var _appLines: []

    // Read (not just import) ClipboardService so this property binding forces
    // the singleton to instantiate at shell startup instead of on first `# `
    // search. Without this, its watchers don't start until the launcher is
    // first used in clip mode, silently dropping every copy before that.
    property var _clipboardWarmup: ClipboardService.history

    // "Clipboard" dropped — the `# ` clip-search mode above already covers
    // it, and there's no more standalone clipboard panel to toggle (moved
    // into the launcher entirely, see .ui-craft/spec.md → Surface: Panels).
    //
    // "Power Menu" dropped too — Lock/Logout/Reboot/Shutdown below cover it
    // directly, one fewer hop than opening the dashboard's power tab.
    readonly property var commandActions: [
        { label: "Notifications",     type: "panel",   panelName: "notificationCenter" },
        { label: "Media",             type: "panel",   panelName: "dashboard", tab: "media" },
        { label: "Dashboard",         type: "panel",   panelName: "dashboard" },
        { label: "Lock",              type: "session", cmd: "loginctl lock-session" },
        { label: "Logout",            type: "session", cmd: "hyprctl dispatch 'hl.dsp.exit()'" },
        { label: "Reboot",            type: "session", cmd: "reboot",       danger: true },
        { label: "Shutdown",          type: "session", cmd: "shutdown now", danger: true },
        { label: "Theme: Dracula",    type: "theme",   theme: "dracula" },
        { label: "Theme: Nord",       type: "theme",   theme: "nord" },
        { label: "Theme: Tokyo Night", type: "theme",  theme: "tokyonight" },
        { label: "Random Wallpaper",  type: "wallpaper" }
    ]

    // Mirrors Dashboard's session-action arming (Dashboard.qml sysRoot):
    // destructive commands need a second activation within the window
    // below so a stray Enter can't reboot/shutdown outright.
    property string _armedAction: ""
    Timer { id: armResetTimer; interval: 3000; onTriggered: root._armedAction = "" }

    property var _appLoader: Process {
        id: appLoader
        stdout: SplitParser {
            onRead: function(d) { if (d) root._appLines.push(d) }
        }
        onExited: {
            var entries = root._appLines.filter(Boolean).map(DesktopEntries.parseDesktopLine)
            root.apps = DesktopEntries.dedupeAppsByName(entries)
            root._appLines = []
        }
    }

    Component.onCompleted: _loadApps()

    function open() {
        searchInput.text = ""
        results = []
        selectedIndex = 0
        _armedAction = ""
        _open = true
        Qt.callLater(function() { searchInput.forceActiveFocus() })
    }

    function close() {
        _open = false
        _armedAction = ""
    }

    function _loadApps() {
        root._appLines = []
        appLoader.command = ["bash", "-c",
            "for dir in \"$HOME/.local/share/applications\" /usr/share/applications; do" +
            " find \"$dir\" -name '*.desktop' 2>/dev/null; done | while IFS= read -r f; do" +
            " name=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-);" +
            " icon=$(grep -m1 '^Icon=' \"$f\" | cut -d= -f2-);" +
            " execval=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2- | sed -E 's/%[fFuUick]//g');" +
            " nodisplay=$(grep -m1 '^NoDisplay=true' \"$f\");" +
            " [ -z \"$nodisplay\" ] && [ -n \"$execval\" ] && printf '%s\\x1f%s\\x1f%s\\n' \"$name\" \"$icon\" \"$execval\";" +
            " done"]
        appLoader.running = true
    }

    function _search(query) {
        var mode = _mode(query)
        selectedIndex = 0
        if (mode === "app" && query.length === 0) {
            results = []
            return
        }
        if (mode === "app") {
            var q = query.toLowerCase()
            var scored = []
            for (var i = 0; i < apps.length; i++) {
                var s = Fuzzy.fuzzyScore(q, apps[i].name.toLowerCase())
                if (s !== null) scored.push({ entry: apps[i], score: s })
            }
            scored.sort(function(a, b) { return b.score - a.score })
            results = scored.slice(0, 8).map(function(x) { return x.entry })
        } else if (mode === "clip") {
            var frag = query.slice(2).toLowerCase()
            var pool = frag
                ? ClipboardService.history.filter(function(c) {
                    if (c.type === "text") return c.text.toLowerCase().indexOf(frag) !== -1
                    if (c.type === "file") return ClipboardService.fileNames(c.text).join(" ").toLowerCase().indexOf(frag) !== -1
                    return false
                })
                : ClipboardService.history
            results = pool.slice(0, 12)
        } else if (mode === "action") {
            var frag = query.slice(2).toLowerCase()
            if (!frag) {
                results = root.commandActions.slice()
            } else {
                var scoredActions = []
                for (var j = 0; j < root.commandActions.length; j++) {
                    var actionScore = Fuzzy.fuzzyScore(frag, root.commandActions[j].label.toLowerCase())
                    if (actionScore !== null) scoredActions.push({ entry: root.commandActions[j], score: actionScore })
                }
                scoredActions.sort(function(a, b) { return b.score - a.score })
                results = scoredActions.map(function(x) { return x.entry })
            }
        } else {
            results = []
        }
    }

    function _mode(text) {
        if (text.startsWith("! ")) return "action"
        if (text.startsWith("# ")) return "clip"
        return "app"
    }

    // detached: a session action must survive the shell it is about to take
    // down (logout kills Hyprland, and Quickshell with it) — see
    // ProcessRunner._detachedScript.
    function _runShellCmd(cmd, label) {
        ProcessRunner.run(["bash", "-c", cmd], {
            appName: "Session",
            onFailureSummary: "Couldn't " + label.toLowerCase(),
            detached: true
        })
    }

    function _runCommandAction(item) {
        if (item.type === "panel") {
            if (item.tab) PanelManager.openTab(item.tab)
            else PanelManager.toggle(item.panelName)
            close()
            return
        }
        if (item.type === "theme") {
            ThemeManager.setTheme(item.theme)
            WallpaperService.autoAssignAfterRescan()
            close()
            return
        }
        if (item.type === "wallpaper") {
            for (var i = 0; i < Quickshell.screens.length; i++)
                WallpaperService.setRandom(Quickshell.screens[i].name)
            close()
            return
        }
        // session: reversible commands fire immediately; destructive ones
        // arm on first activation and only run if the same item fires
        // again before armResetTimer clears it.
        if (!item.danger) {
            root._runShellCmd(item.cmd, item.label)
            close()
            return
        }
        if (root._armedAction === item.cmd) {
            armResetTimer.stop()
            root._armedAction = ""
            root._runShellCmd(item.cmd, item.label)
            close()
        } else {
            root._armedAction = item.cmd
            armResetTimer.restart()
        }
    }

    function _actionLabel(item) {
        if (item.type === "session" && item.danger && root._armedAction === item.cmd)
            return "Confirm " + item.label + "?"
        return item.label
    }

    function _actionTint(item) {
        if (item.type !== "session" || !item.danger) return ThemeManager.active.text
        if (root._armedAction === item.cmd) return ThemeManager.active.error
        return item.label === "Shutdown" ? ThemeManager.active.error : ThemeManager.active.warning
    }

    function _execute() {
        // Mode must come from the untrimmed text — trimming first turns
        // "! " (prefix, empty query) into "!", which no longer matches
        // _mode()'s "! " check and silently falls through to app mode.
        var text = searchInput.text
        var mode = _mode(text)

        if (mode === "action") {
            var action = results[selectedIndex]
            if (action) root._runCommandAction(action)
            return
        }

        if (mode === "clip") {
            var item = results[selectedIndex]
            if (item) ClipboardService.copy(item)
            close()
            return
        }

        // App mode
        var entry = results[selectedIndex]
        if (entry) {
            // detached: a launched app is long-lived and must not stay a child
            // of a QML Process object — otherwise quitting it hours later
            // toasts "Couldn't launch <app>", and closing Quickshell closes it.
            ProcessRunner.run(["bash", "-c", entry.exec], {
                appName: "Launcher",
                onFailureSummary: "Couldn't launch " + entry.name,
                detached: true
            })
        }
        close()
    }

    GlassPanel {
        anchors.fill: parent
        opacity: 1 - root.offsetScale
        focus: true
        Keys.onEscapePressed: root.close()
        Keys.onReturnPressed: root._execute()
        Keys.onUpPressed:   { if (root.selectedIndex > 0) root.selectedIndex-- }
        Keys.onDownPressed: { if (root.selectedIndex < root.results.length - 1) root.selectedIndex++ }

        ColumnLayout {
            anchors { fill: parent; margins: Tokens.spaceMd }
            spacing: Tokens.spaceSm

            GlassCard {
                Layout.fillWidth: true
                height: 48
                radius: Tokens.radiusLg

                RowLayout {
                    z: Tokens.zModal
                    anchors { fill: parent; leftMargin: Tokens.spaceMd; rightMargin: Tokens.spaceMd }
                    spacing: Tokens.spaceSm

                    Text {
                        text: {
                            var m = root._mode(searchInput.text)
                            if (m === "action") return "!"
                            if (m === "clip")   return "#"
                            return "󰍉"
                        }
                        font.family: ThemeManager.active.fontMono
                        font.pixelSize: Tokens.textXl
                        color: ThemeManager.active.accent
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        font.family: ThemeManager.active.fontUi
                        font.pixelSize: Tokens.textLg
                        color: ThemeManager.active.text
                        onTextChanged: root._search(text)
                        Keys.onReturnPressed: root._execute()
                        Keys.onEscapePressed: root.close()
                        Keys.onUpPressed:   { if (root.selectedIndex > 0) root.selectedIndex-- }
                        Keys.onDownPressed: { if (root.selectedIndex < root.results.length - 1) root.selectedIndex++ }
                    }
                }
            }

            ListView {
                id: resultList
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.resultsVisible
                model: root.results
                currentIndex: root.selectedIndex
                clip: true

                delegate: Rectangle {
                    width: resultList.width
                    height: 48
                    radius: Tokens.radiusMd

                    color: index === root.selectedIndex
                        ? ThemeManager.active.blur
                            ? Qt.rgba(ThemeManager.active.accent.r,
                                      ThemeManager.active.accent.g,
                                      ThemeManager.active.accent.b, 0.28 * ThemeManager.active.opacity)
                            : ThemeManager.active.accent
                        : "transparent"

                    border.color: index === root.selectedIndex && ThemeManager.active.blur
                        ? Qt.rgba(1, 1, 1, 0.30)
                        : "transparent"
                    border.width: 1

                    required property var    modelData
                    required property int    index

                    RowLayout {
                        anchors { fill: parent; leftMargin: Tokens.spaceMd; rightMargin: Tokens.spaceMd }
                        spacing: Tokens.spaceMd

                        IconImage {
                            implicitSize: 24
                            visible: root._mode(searchInput.text) === "app"
                            source: {
                                if (!visible) return ""
                                return modelData.icon && Quickshell.hasThemeIcon(modelData.icon)
                                    ? Quickshell.iconPath(modelData.icon)
                                    : Tokens.fallbackIcon
                            }
                        }

                        Image {
                            width: 32
                            height: 32
                            visible: root._mode(searchInput.text) === "clip" && modelData.type === "image"
                            source: visible ? "file://" + modelData.path : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        Text {
                            Layout.preferredWidth: 24
                            horizontalAlignment: Text.AlignHCenter
                            visible: root._mode(searchInput.text) === "clip" && modelData.type !== "image"
                            text: modelData.type === "file" ? "󰧮" : "󰧭"
                            font.family: ThemeManager.active.fontMono
                            font.pixelSize: Tokens.textLg
                            color: ThemeManager.active.accent
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                var m = root._mode(searchInput.text)
                                if (m === "clip") {
                                    if (modelData.type === "image") return "Image"
                                    if (modelData.type === "file") {
                                        var names = ClipboardService.fileNames(modelData.text)
                                        return names.length > 1
                                            ? names[0] + "  +" + (names.length - 1) + " more"
                                            : names[0]
                                    }
                                    return modelData.text.replace(/\n/g, " ").slice(0, 60)
                                }
                                if (m === "action") return root._actionLabel(modelData)
                                if (m === "app")    return modelData.name
                                return modelData
                            }
                            font.family: root._mode(searchInput.text) === "clip" && modelData.type === "text"
                                         ? ThemeManager.active.fontMono
                                         : ThemeManager.active.fontUi
                            font.pixelSize: Tokens.textMd
                            color: root._mode(searchInput.text) === "action"
                                   ? root._actionTint(modelData)
                                   : ThemeManager.active.text
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.selectedIndex = index
                            root._execute()
                        }
                    }
                }
            }
        }
    }
}
