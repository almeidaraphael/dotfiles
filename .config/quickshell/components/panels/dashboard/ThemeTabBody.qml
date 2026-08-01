import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import Qt.labs.platform as Labs
import "../../.."
import "../../shared"

    // ================= Theme tab ============================================
    // See .ui-craft/spec.md -> Surface: Theme.
Item {
        id: thRoot

        // Drives Dashboard's per-tab panel height (root.currentTabBodyHeight)
        // — same approach as Overview/Media: the tab hugs its actual content
        // instead of sitting in the shared 547px dense-tab height, which
        // padded this tab out with dead whitespace.
        implicitHeight: themeColumn.implicitHeight + Tokens.spaceXl * 2

        readonly property var themeList: [
            { name: "dracula",    label: "Dracula",     base: "#282A36", accent: "#BD93F9", accentAlt: "#FF79C6", highlight: "#8BE9FD", text: "#F8F8F2", border: "#6272A4", blur: true,  wallpaperDir: "dracula"     },
            { name: "tokyonight", label: "Tokyo Night",  base: "#1A1B26", accent: "#7AA2F7", accentAlt: "#BB9AF7", highlight: "#2AC3DE", text: "#C0CAF5", border: "#3B4261", blur: true,  wallpaperDir: "tokyonight" },
            { name: "nord",       label: "Nord",         base: "#2E3440", accent: "#88C0D0", accentAlt: "#81A1C1", highlight: "#5E81AC", text: "#ECEFF4", border: "#4C566A", blur: true,  wallpaperDir: "nord"       }
        ]

        readonly property int themePad: Math.min(2, thRoot.themeList.length)
        // Clone-padded render list — puts the tail's last `themePad` themes
        // before index 0 and the head's first `themePad` themes after the
        // last real index, so the carousel never shows blank space at either
        // end (last theme visibly peeks left of the first, and vice versa).
        // `themeFocusIndex` stays a real 0..len-1 index everywhere else
        // (isApplied, keyboard wrap, dots) — only the Row's rendering and
        // x offset account for the padding.
        readonly property var paddedThemeList: {
            var list = thRoot.themeList
            var n = list.length
            var pad = thRoot.themePad
            var out = []
            for (var i = 0; i < pad; i++) out.push(list[(n - pad + i) % n])
            for (var i = 0; i < n; i++) out.push(list[i])
            for (var i = 0; i < pad; i++) out.push(list[i % n])
            return out
        }

        function _indexOfTheme(name) {
            for (var i = 0; i < thRoot.themeList.length; i++)
                if (thRoot.themeList[i].name === name) return i
            return 0
        }

        function _hexToRgba(hex, alpha) {
            var h = hex.replace("#", "")
            var r = parseInt(h.substring(0, 2), 16) / 255
            var g = parseInt(h.substring(2, 4), 16) / 255
            var b = parseInt(h.substring(4, 6), 16) / 255
            return Qt.rgba(r, g, b, alpha)
        }

        // Per-theme wallpaper thumbnails for the theme cards — replaces the
        // old synthetic hex-gradient art region with a real, theme-scoped
        // image (matches spec.md's original "card demonstrates the outfit"
        // intent, which the gradient never actually delivered).
        property var themeThumbs: ({})

        function _resolveWallDir(dirName) {
            var home = ConfigService.homeDir.toString().replace(/^file:\/\//, "")
            return dirName.startsWith("/") ? dirName
                 : dirName.startsWith("~") ? dirName.replace("~", home)
                 : (home + "/Pictures/wallpapers/" + dirName)
        }

        function _scanThemeThumbs() {
            for (var i = 0; i < thRoot.themeList.length; i++)
                thRoot._scanOneThumb(thRoot.themeList[i])
        }

        function _scanOneThumb(entry) {
            var dir = thRoot._resolveWallDir(entry.wallpaperDir)
            var proc = Qt.createQmlObject(
                'import Quickshell.Io; Process { stdout: StdioCollector { waitForEnd: true } }', thRoot)
            proc.command = ["bash", "-c",
                "find -L " + JSON.stringify(dir) +
                " -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png'" +
                " -o -iname '*.webp' -o -iname '*.gif' \\) 2>/dev/null | sort | head -1"]
            proc.stdout.streamFinished.connect(function() {
                var path = proc.stdout.text.trim()
                if (path) {
                    var next = Object.assign({}, thRoot.themeThumbs)
                    next[entry.name] = path
                    thRoot.themeThumbs = next
                }
                proc.destroy()
            })
            proc.running = true
        }

        Component.onCompleted: thRoot._scanThemeThumbs()

        property int themeFocusIndex: thRoot._indexOfTheme(ThemeManager.active.name)
        Connections {
            target: ThemeManager
            function onActiveChanged() { thRoot.themeFocusIndex = thRoot._indexOfTheme(ThemeManager.active.name) }
        }

        property string targetMonitor: Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""

        function _safeMonitor() {
            var screens = Quickshell.screens
            for (var i = 0; i < screens.length; i++)
                if (screens[i].name === thRoot.targetMonitor) return thRoot.targetMonitor
            return screens.length > 0 ? screens[0].name : ""
        }

        property int filmstripFocusIndex: 0

        // No padding for a single wallpaper — cloning it next to itself
        // wouldn't remove blank space, just make one photo look like three.
        readonly property int filmstripPad: WallpaperService.wallpapers.length > 1
            ? Math.min(2, WallpaperService.wallpapers.length) : 0
        // Same clone-padding trick as the theme carousel, applied to the
        // wallpaper filmstrip. Each entry carries its real index since
        // wallpaper paths aren't unique identifiers the way theme names are.
        readonly property var paddedWallpapers: {
            var list = WallpaperService.wallpapers
            var n = list.length
            if (n === 0) return []
            var pad = thRoot.filmstripPad
            var out = []
            for (var i = 0; i < pad; i++) { var k = (n - pad + i) % n; out.push({ realIndex: k, path: list[k] }) }
            for (var i = 0; i < n; i++) out.push({ realIndex: i, path: list[i] })
            for (var i = 0; i < pad; i++) { var k2 = i % n; out.push({ realIndex: k2, path: list[k2] }) }
            return out
        }

        function _applyFilmstripFocus() {
            var list = WallpaperService.wallpapers
            if (list.length === 0) return
            var idx = Math.min(thRoot.filmstripFocusIndex, list.length - 1)
            WallpaperService.set(list[idx], thRoot._safeMonitor())
        }

        function _monitorsFor(path) {
            var out = []
            var screens = Quickshell.screens
            for (var i = 0; i < screens.length; i++)
                if (WallpaperService.currentFor(screens[i].name) === path) out.push(screens[i].name)
            return out
        }

        function selectTheme(index) {
            var t = thRoot.themeList[index]
            thRoot.themeFocusIndex = index
            if (t.name === ThemeManager.active.name) return
            ThemeManager.setTheme(t.name)
            WallpaperService.autoAssignAfterRescan()
        }

        Connections {
            target: WallpaperService
            function onWallpapersChanged() {
                if (thRoot.filmstripFocusIndex >= WallpaperService.wallpapers.length)
                    thRoot.filmstripFocusIndex = 0
            }
        }

        ColumnLayout {
            id: themeColumn
            anchors { fill: parent; margins: Tokens.spaceXl }
            spacing: Tokens.spaceLg

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spaceSm

                Item {
                    id: themeCarousel
                    Layout.fillWidth: true
                    Layout.preferredHeight: 118

                    Item {
                        id: themeViewport
                        anchors.fill: parent
                        clip: true
                        focus: true
                        activeFocusOnTab: true
                        Keys.onLeftPressed:   thRoot.themeFocusIndex = (thRoot.themeFocusIndex - 1 + thRoot.themeList.length) % thRoot.themeList.length
                        Keys.onRightPressed:  thRoot.themeFocusIndex = (thRoot.themeFocusIndex + 1) % thRoot.themeList.length
                        Keys.onReturnPressed: thRoot.selectTheme(thRoot.themeFocusIndex)
                        Keys.onSpacePressed:  thRoot.selectTheme(thRoot.themeFocusIndex)

                        // 190, not the panel-width-derived max — sized so 3 full
                        // cards always fit the fixed 680px panel's 640px content
                        // width (3*190 + 2*spaceMd = 594) with real margin (not a
                        // knife's-edge fit) left over as a genuine peek of the
                        // 4th/5th card at each edge, independent of monitor/
                        // resolution since the panel width never changes.
                        readonly property int  cardWidth:   190
                        readonly property int  cardSpacing: Tokens.spaceMd
                        readonly property real step:        cardWidth + cardSpacing

                        Row {
                            id: themeRow
                            spacing: themeViewport.cardSpacing
                            anchors.verticalCenter: parent.verticalCenter
                            x: themeViewport.width / 2 - themeViewport.cardWidth / 2 - (thRoot.themeFocusIndex + thRoot.themePad) * themeViewport.step
                            Behavior on x { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationFast; easing.type: Tokens.easeOut } }

                            Repeater {
                                model: thRoot.paddedThemeList
                                delegate: Item {
                                    id: card
                                    required property var modelData
                                    required property int index
                                    width: themeViewport.cardWidth
                                    height: 118

                                    readonly property bool isFocused: modelData.name === thRoot.themeList[thRoot.themeFocusIndex].name
                                    readonly property bool isApplied: modelData.name === ThemeManager.active.name

                                    // Applied theme marked by a thicker accent border, matching
                                    // GlassButton's active-state convention (border width/color
                                    // bump, not a shadow) — keeps state signaling consistent
                                    // across the shell instead of stacking a colored glow on
                                    // top of the frosted corner accent below.
                                    Rectangle {
                                        id: cardBg
                                        anchors.fill: parent
                                        radius: Tokens.radiusLg
                                        clip: true
                                        color: modelData.blur ? thRoot._hexToRgba(modelData.base, 0.35) : modelData.base

                                        border.width: card.isApplied ? 2 : 1
                                        border.color: card.isFocused
                                            ? ThemeManager.active.text
                                            : card.isApplied
                                                ? modelData.accent
                                                : (modelData.blur ? Qt.rgba(1, 1, 1, 0.22) : thRoot._hexToRgba(modelData.border, 0.9))
                                        Behavior on border.color { enabled: !ConfigService.reduceMotion; ColorAnimation { duration: 150 } }
                                        Behavior on border.width { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: 150 } }

                                        // Real theme-scoped wallpaper thumbnail — replaces the
                                        // old synthetic hex gradient, which was both the "ugly
                                        // gradient" and the "smushed" complaint (same bug, two
                                        // descriptions). Falls back to the flat base swatch
                                        // while the async scan hasn't resolved yet.
                                        Image {
                                            anchors.fill: parent
                                            visible: !!thRoot.themeThumbs[modelData.name]
                                            source: thRoot.themeThumbs[modelData.name] ? "file://" + thRoot.themeThumbs[modelData.name] : ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: true
                                        }

                                        // Bottom scrim + label instead of a full solid-accent
                                        // block — painting one accent color across all 5 cards
                                        // at once blew the accent budget (Hick's Law: every
                                        // placement competes for attention).
                                        Rectangle {
                                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                            height: 36
                                            gradient: Gradient {
                                                GradientStop { position: 0.0; color: "transparent" }
                                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
                                            }
                                            Text {
                                                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: Tokens.spaceSm }
                                                text: modelData.label
                                                font.family: ThemeManager.active.fontUi
                                                font.pixelSize: Tokens.textMd
                                                font.bold: true
                                                color: "#FFFFFF"
                                            }
                                        }

                                        // Material-demonstrating corner ear — replaces the old
                                        // floating blurred circle, which only blurred its own
                                        // edges into a glowing dot and never actually showed the
                                        // theme's chrome (a badge standing in for a material,
                                        // exactly what this tab's own spec says to avoid). This is
                                        // a real diagonal chunk of the card's own surface treatment
                                        // instead: `GlassPanel`'s exact fill formula, solid for
                                        // flat themes, translucent + accent-tinted + soft-edged for
                                        // blur themes (the softness reads as frosted since the
                                        // whole panel surface already sits on real Hyprland
                                        // compositor blur — see hypr/rules.conf's `namespace =
                                        // quickshell` layerrule — this isn't faking that, it's the
                                        // same alpha math GlassPanel itself uses). Rotated square
                                        // clipped by cardBg produces the diagonal cut; parented
                                        // inside cardBg so it never bleeds onto the neighbor card.
                                        Rectangle {
                                            width: 80; height: 80
                                            rotation: 45
                                            anchors { right: parent.right; bottom: parent.bottom; rightMargin: -40; bottomMargin: -40 }
                                            color: modelData.accent
                                            opacity: modelData.blur ? 0.5 : 0.92
                                            layer.enabled: modelData.blur
                                            layer.effect: MultiEffect { blurEnabled: true; blur: 0.4; blurMax: 24 }
                                        }

                                        // Applied-theme indicator — independent of `isFocused` on
                                        // purpose. The border above already goes accent-colored on
                                        // apply, but that color gets overridden by the white
                                        // focus-border whenever the applied theme is also the
                                        // centered card (the common case right after picking one),
                                        // leaving zero visible "this is active" signal. A fixed
                                        // corner badge doesn't depend on scroll position.
                                        Rectangle {
                                            visible: card.isApplied
                                            width: 22; height: 22; radius: 11
                                            anchors { top: parent.top; right: parent.right; topMargin: Tokens.spaceSm; rightMargin: Tokens.spaceSm }
                                            color: modelData.accent
                                            border.color: Qt.rgba(1, 1, 1, 0.5)
                                            border.width: 1
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰄬"
                                                font.family: ThemeManager.active.fontMono
                                                font.pixelSize: Tokens.textSm
                                                color: ThemeManager.active.base
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { themeViewport.forceActiveFocus(); thRoot.selectTheme(thRoot._indexOfTheme(modelData.name)) }
                                    }
                                }
                            }
                        }
                    }

                }

                // Footer controls: prev/next flank the position dots instead of
                // floating over the track — arrows over wallpaper art had
                // inconsistent contrast (unreadable over bright thumbnails, fine
                // over dark ones); GlassButton's own chip background fixes that.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spaceSm

                    GlassButton {
                        width: 36; height: 36
                        activeFocusOnTab: true
                        frameRadius: Tokens.radiusMd
                        Text { anchors.centerIn: parent; text: "‹"; font.pixelSize: Tokens.textLg; color: ThemeManager.active.text }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: thRoot.themeFocusIndex = (thRoot.themeFocusIndex - 1 + thRoot.themeList.length) % thRoot.themeList.length
                        }
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        spacing: 0
                        Repeater {
                            model: thRoot.themeList.length
                            delegate: Item {
                                required property int index
                                // Fixed-width slot per dot — the active pill grows
                                // 6px -> 16px in place, so growth never eats into a
                                // neighbor's spacing and the two touch/overlap.
                                width: 20; height: 6
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: index === thRoot.themeFocusIndex ? 16 : 6
                                    height: 6
                                    radius: 3
                                    color: index === thRoot.themeFocusIndex ? ThemeManager.active.accent : ThemeManager.active.overlay
                                    Behavior on width { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationFast } }
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    GlassButton {
                        width: 36; height: 36
                        activeFocusOnTab: true
                        frameRadius: Tokens.radiusMd
                        Text { anchors.centerIn: parent; text: "›"; font.pixelSize: Tokens.textLg; color: ThemeManager.active.text }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: thRoot.themeFocusIndex = (thRoot.themeFocusIndex + 1) % thRoot.themeList.length
                        }
                    }
                }
            }

            Divider {}

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spaceSm

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spaceSm
                    visible: Quickshell.screens.length > 1

                    SectionLabel { text: "TARGET MONITOR" }

                    Repeater {
                        model: Quickshell.screens
                        delegate: Rectangle {
                            id: monPill
                            required property var modelData
                            required property int index
                            readonly property bool isActive: modelData.name === thRoot.targetMonitor
                            height: 24
                            width: monPillRow.implicitWidth + Tokens.spaceMd
                            radius: height / 2
                            color: isActive ? ThemeManager.active.accent : ThemeManager.active.overlay
                            border.width: 1
                            border.color: ThemeManager.active.blur
                                ? Qt.rgba(1, 1, 1, isActive ? 0.4 : 0.22)
                                : Qt.rgba(0, 0, 0, 0.3)
                            activeFocusOnTab: true
                            // Icon + index instead of the raw connector name (DP-1,
                            // eDP-1, HDMI-A-1...) — a monitor glyph with a plain
                            // number reads faster than parsing connector strings,
                            // and stays correct regardless of naming scheme since
                            // the number is the screen's position in Quickshell.screens,
                            // not a substring of modelData.name.
                            RowLayout {
                                id: monPillRow
                                anchors.centerIn: parent
                                spacing: 3
                                Text {
                                    text: "󰍹"
                                    font.family: ThemeManager.active.fontMono
                                    font.pixelSize: Tokens.textXs
                                    color: monPill.isActive ? ThemeManager.active.base : ThemeManager.active.text
                                }
                                Text {
                                    text: monPill.index + 1
                                    font.family: ThemeManager.active.fontMono
                                    font.pixelSize: Tokens.textXs
                                    font.bold: true
                                    color: monPill.isActive ? ThemeManager.active.base : ThemeManager.active.text
                                }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: thRoot.targetMonitor = monPill.modelData.name }
                            Keys.onReturnPressed: thRoot.targetMonitor = monPill.modelData.name
                            Keys.onSpacePressed:  thRoot.targetMonitor = monPill.modelData.name
                        }
                    }
                    Item { Layout.fillWidth: true }
                }

                Item {
                    id: filmstripCarousel
                    Layout.fillWidth: true
                    Layout.preferredHeight: 118

                    Item {
                        id: filmstripViewport
                        anchors.fill: parent
                        clip: true
                        focus: true
                        activeFocusOnTab: true
                        Keys.onLeftPressed:   if (WallpaperService.wallpapers.length > 0) thRoot.filmstripFocusIndex = (thRoot.filmstripFocusIndex - 1 + WallpaperService.wallpapers.length) % WallpaperService.wallpapers.length
                        Keys.onRightPressed:  if (WallpaperService.wallpapers.length > 0) thRoot.filmstripFocusIndex = (thRoot.filmstripFocusIndex + 1) % WallpaperService.wallpapers.length
                        Keys.onReturnPressed: thRoot._applyFilmstripFocus()
                        Keys.onSpacePressed:  thRoot._applyFilmstripFocus()

                        // Same size as the theme cards — landscape, matching the
                        // actual aspect ratio of wallpaper source images (the old
                        // 90x140 portrait card cropped a large chunk out of every
                        // wallpaper).
                        readonly property int  cardWidth:   190
                        readonly property int  cardHeight:  118
                        readonly property int  cardSpacing: Tokens.spaceSm
                        readonly property real step:        cardWidth + cardSpacing

                        ColumnLayout {
                            anchors.centerIn: parent
                            visible: WallpaperService.wallpapers.length === 0
                            spacing: Tokens.spaceXs
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: ""
                                font.family: ThemeManager.active.fontMono
                                font.pixelSize: Tokens.typeHeadline
                                color: ThemeManager.active.subtext
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "No wallpapers in this set"
                                font.family: ThemeManager.active.fontUi
                                font.pixelSize: Tokens.textSm
                                color: ThemeManager.active.subtext
                            }
                        }

                        Row {
                            id: filmRow
                            visible: WallpaperService.wallpapers.length > 0
                            spacing: filmstripViewport.cardSpacing
                            anchors.verticalCenter: parent.verticalCenter
                            x: filmstripViewport.width / 2 - filmstripViewport.cardWidth / 2 - (thRoot.filmstripFocusIndex + thRoot.filmstripPad) * filmstripViewport.step
                            Behavior on x { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationFast; easing.type: Tokens.easeOut } }

                            Repeater {
                                model: thRoot.paddedWallpapers
                                delegate: Rectangle {
                                    id: thumb
                                    required property var modelData
                                    required property int index
                                    width: filmstripViewport.cardWidth
                                    height: filmstripViewport.cardHeight
                                    radius: Tokens.radiusMd
                                    color: ThemeManager.active.overlay
                                    clip: true

                                    readonly property var  assignedMonitors: thRoot._monitorsFor(modelData.path)
                                    readonly property bool isApplied: assignedMonitors.length > 0
                                    readonly property bool isFocused: modelData.realIndex === thRoot.filmstripFocusIndex

                                    // Applied wallpaper marked by a thicker accent border,
                                    // matching the theme cards' active-state convention.
                                    border.width: isApplied ? 2 : 1
                                    border.color: isFocused
                                        ? ThemeManager.active.text
                                        : isApplied
                                            ? ThemeManager.active.accent
                                            : (ThemeManager.active.blur ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(0, 0, 0, 0.3))
                                    Behavior on border.color { enabled: !ConfigService.reduceMotion; ColorAnimation { duration: 150 } }
                                    Behavior on border.width { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: 150 } }

                                    scale: 1.0
                                    onIsAppliedChanged: if (isApplied && !ConfigService.reduceMotion) _pulse.start()
                                    SequentialAnimation {
                                        id: _pulse
                                        NumberAnimation { target: thumb; property: "scale"; to: 1.06; duration: 90 }
                                        NumberAnimation { target: thumb; property: "scale"; to: 1.0;  duration: 90 }
                                    }

                                    Image {
                                        anchors.fill: parent
                                        source: "file://" + thumb.modelData.path
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                    }

                                    // Scrim behind the monitor-assignment badges — without it
                                    // the 8px label text sits directly on unpredictable photo
                                    // content and can be unreadable.
                                    Rectangle {
                                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                                        height: 22
                                        visible: Quickshell.screens.length > 1 && thumb.isApplied
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: "transparent" }
                                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
                                        }
                                    }

                                    Row {
                                        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: Tokens.spaceXs }
                                        spacing: 2
                                        visible: Quickshell.screens.length > 1 && thumb.isApplied
                                        Repeater {
                                            model: thumb.assignedMonitors
                                            delegate: Rectangle {
                                                required property string modelData
                                                height: 16
                                                width: monLbl.implicitWidth + 6
                                                radius: 8
                                                color: Qt.rgba(0, 0, 0, 0.55)
                                                Text {
                                                    id: monLbl
                                                    anchors.centerIn: parent
                                                    text: parent.modelData
                                                    font.pixelSize: 8
                                                    font.family: ThemeManager.active.fontMono
                                                    color: ThemeManager.active.accent
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            filmstripViewport.forceActiveFocus()
                                            thRoot.filmstripFocusIndex = thumb.modelData.realIndex
                                            WallpaperService.set(thumb.modelData.path, thRoot._safeMonitor())
                                        }
                                    }
                                }
                            }
                        }
                    }

                }

                // Footer controls: arrows flank a dot row, same skeleton as the
                // theme carousel above — always rendered (buttons dim/disable
                // instead of vanishing) so this row structurally reads as a
                // carousel even with 0-1 wallpapers, instead of disappearing
                // and leaving a single framed photo with no carousel affordance.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spaceSm

                    GlassButton {
                        width: 36; height: 36
                        activeFocusOnTab: WallpaperService.wallpapers.length > 1
                        opacity: WallpaperService.wallpapers.length > 1 ? 1 : 0.35
                        frameRadius: Tokens.radiusMd
                        Text { anchors.centerIn: parent; text: "‹"; font.pixelSize: Tokens.textLg; color: ThemeManager.active.text }
                        MouseArea {
                            anchors.fill: parent
                            enabled: WallpaperService.wallpapers.length > 1
                            cursorShape: Qt.PointingHandCursor
                            onClicked: thRoot.filmstripFocusIndex = (thRoot.filmstripFocusIndex - 1 + WallpaperService.wallpapers.length) % WallpaperService.wallpapers.length
                        }
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        spacing: 0
                        Repeater {
                            model: WallpaperService.wallpapers.length
                            delegate: Item {
                                required property int index
                                // Fixed-width slot per dot, same growth trick as
                                // the theme carousel's dots.
                                width: 20; height: 6
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: index === thRoot.filmstripFocusIndex ? 16 : 6
                                    height: 6
                                    radius: 3
                                    color: index === thRoot.filmstripFocusIndex ? ThemeManager.active.accent : ThemeManager.active.overlay
                                    Behavior on width { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationFast } }
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    GlassButton {
                        width: 36; height: 36
                        activeFocusOnTab: WallpaperService.wallpapers.length > 1
                        opacity: WallpaperService.wallpapers.length > 1 ? 1 : 0.35
                        frameRadius: Tokens.radiusMd
                        Text { anchors.centerIn: parent; text: "›"; font.pixelSize: Tokens.textLg; color: ThemeManager.active.text }
                        MouseArea {
                            anchors.fill: parent
                            enabled: WallpaperService.wallpapers.length > 1
                            cursorShape: Qt.PointingHandCursor
                            onClicked: thRoot.filmstripFocusIndex = (thRoot.filmstripFocusIndex + 1) % WallpaperService.wallpapers.length
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spaceMd

                    // Icon-only — the old text pills ("Random" / "manual" /
                    // "random") used the word "random" twice for two
                    // different actions (shuffle once vs. an ongoing
                    // auto-rotate mode) and read as three near-identical
                    // pills. Distinct glyphs (shuffle / lock / repeat) make
                    // the two concepts visually distinct instead of leaning
                    // on overlapping labels. Not the shared SegCtrl component
                    // here — its other uses (Temperature Unit, Clock Format)
                    // are short, clear text and don't need this treatment.
                    GlassButton {
                        width: 36; height: 36
                        activeFocusOnTab: true
                        frameRadius: Tokens.radiusMd
                        Text { anchors.centerIn: parent; text: "󰒝"; font.family: ThemeManager.active.fontMono; font.pixelSize: Tokens.textLg; color: ThemeManager.active.text }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: WallpaperService.setRandom(thRoot._safeMonitor()) }
                        Keys.onReturnPressed: WallpaperService.setRandom(thRoot._safeMonitor())
                        Keys.onSpacePressed:  WallpaperService.setRandom(thRoot._safeMonitor())
                    }

                    RowLayout {
                        spacing: Tokens.spaceXs

                        GlassButton {
                            width: 36; height: 36
                            active: (ConfigService.wallpaperMode || "random") === "manual"
                            activeFocusOnTab: true
                            frameRadius: Tokens.radiusMd
                            Text { anchors.centerIn: parent; text: "󰍁"; font.family: ThemeManager.active.fontMono; font.pixelSize: Tokens.textLg; color: ThemeManager.active.text }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ConfigService.wallpaperMode = "manual"; ConfigService.save() } }
                            Keys.onReturnPressed: { ConfigService.wallpaperMode = "manual"; ConfigService.save() }
                            Keys.onSpacePressed:  { ConfigService.wallpaperMode = "manual"; ConfigService.save() }
                        }

                        GlassButton {
                            width: 36; height: 36
                            active: (ConfigService.wallpaperMode || "random") === "random"
                            activeFocusOnTab: true
                            frameRadius: Tokens.radiusMd
                            Text { anchors.centerIn: parent; text: "󰑖"; font.family: ThemeManager.active.fontMono; font.pixelSize: Tokens.textLg; color: ThemeManager.active.text }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ConfigService.wallpaperMode = "random"; ConfigService.save() } }
                            Keys.onReturnPressed: { ConfigService.wallpaperMode = "random"; ConfigService.save() }
                            Keys.onSpacePressed:  { ConfigService.wallpaperMode = "random"; ConfigService.save() }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }
    }

    // Session action cell — shared by PowerTabBody's two Repeaters split
    // either side of a real divider element, instead of faking the gap with
    // a Layout.leftMargin on one cell. `host` is passed in explicitly since a
    // top-level `component` has no implicit access to PowerTabBody's ids.
