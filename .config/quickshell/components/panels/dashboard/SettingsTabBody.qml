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

    // ================= Settings tab =========================================
    // See .ui-craft/spec.md -> Surface: Settings.
Item {
        id: setRoot

        readonly property var categories: [
            { name: "Audio",   icon: "󰕾" },
            { name: "Display", icon: "󰍹" },
            { name: "Weather", icon: "󰖐" },
            { name: "General", icon: "󰒓" },
            { name: "Profile", icon: "󰀄" }
        ]
        property int currentIndex: 0

        // Rail sizes to its widest label instead of a guessed fixed width,
        // so the content column (device dropdowns, inputs) gets whatever
        // room the rail doesn't need. 72 is a floor so the selected pill
        // never looks cramped even if categories shrink to very short words.
        property real railMaxWidth: 72

        property string profileState: "idle"
        property url    pickedFile: ""
        property real   srcW: 0
        property real   srcH: 0
        property real   cropScale: 1
        property real   cropOffsetX: 0
        property real   cropOffsetY: 0
        property string cropError: ""
        readonly property int  cropViewport: 280
        readonly property real cropMinScale: (srcW > 0 && srcH > 0) ? cropViewport / Math.min(srcW, srcH) : 1
        readonly property real cropMaxScale: cropMinScale * 4

        function clampCropOffsets() {
            var w = srcW * cropScale, h = srcH * cropScale
            cropOffsetX = Math.min(0, Math.max(cropViewport - w, cropOffsetX))
            cropOffsetY = Math.min(0, Math.max(cropViewport - h, cropOffsetY))
        }
        function resetCrop() {
            cropScale = cropMinScale
            cropOffsetX = (cropViewport - srcW * cropScale) / 2
            cropOffsetY = (cropViewport - srcH * cropScale) / 2
        }
        function setCropScale(newScale) {
            cropScale = Math.min(cropMaxScale, Math.max(cropMinScale, newScale))
            clampCropOffsets()
        }
        function cancelCrop() {
            profileState = "idle"
            pickedFile = ""
            cropError = ""
        }
        function performCrop() {
            var w = Math.round(cropViewport / cropScale)
            var h = w
            var x = Math.round(-cropOffsetX / cropScale)
            var y = Math.round(-cropOffsetY / cropScale)
            x = Math.max(0, Math.min(x, srcW - w))
            y = Math.max(0, Math.min(y, srcH - h))
            var srcPath = pickedFile.toString().replace(/^file:\/\//, "")
            cropError = ""
            var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', setRoot)
            // Leading +repage discards any page/canvas metadata a source PNG
            // may carry (e.g. a caNv chunk) — without it, -crop's geometry
            // is interpreted against that embedded canvas instead of the
            // actual raster, silently producing a wrong crop region.
            proc.command = ["magick", srcPath, "+repage", "-crop", w + "x" + h + "+" + x + "+" + y,
                             "+repage", "-resize", "512x512", "/etc/theme-assets/avatar.png"]
            proc.exited.connect(function(exitCode) {
                if (exitCode === 0) {
                    ConfigService.avatarVersion = Date.now()
                    setRoot.profileState = "idle"
                    setRoot.pickedFile = ""
                } else {
                    setRoot.cropError = "Couldn't process that image"
                }
                proc.destroy()
            })
            proc.running = true
        }

        Labs.FileDialog {
            id: avatarFileDialog
            nameFilters: ["Images (*.png *.jpg *.jpeg *.webp)"]
            onAccepted: {
                setRoot.srcW = 0
                setRoot.srcH = 0
                setRoot.pickedFile = file
                setRoot.cropError = ""
                setRoot.profileState = "cropping"
            }
        }

        property var sinks: []
        property var sources: []
        property string defaultSink: ""
        property string defaultSource: ""
        property var _lines: []
        property var _reader: Process {
            id: reader
            stdout: SplitParser { onRead: function(d) { if (d) _lines.push(d) } }
            onExited: {
                var newSinks = [], newSources = []
                for (var i = 0; i < _lines.length; i++) {
                    var line = _lines[i]
                    var sep = line.indexOf(":")
                    if (sep < 0) continue
                    var key = line.slice(0, sep), val = line.slice(sep + 1)
                    if      (key === "SINK")     newSinks.push(val)
                    else if (key === "SRC")      newSources.push(val)
                    else if (key === "DEF_SINK") defaultSink   = val
                    else if (key === "DEF_SRC")  defaultSource = val
                }
                sinks = newSinks; sources = newSources; _lines = []
                setRoot._syncCombos()
            }
        }
        function refreshAudio() {
            _lines = []
            reader.command = ["bash", "-c",
                "pactl list short sinks | awk '{print \"SINK:\"$2}';" +
                "pactl list short sources | grep -v monitor | awk '{print \"SRC:\"$2}';" +
                "echo DEF_SINK:$(pactl get-default-sink);" +
                "echo DEF_SRC:$(pactl get-default-source)"]
            reader.running = true
        }
        function friendlyDeviceName(raw) {
            if (!raw) return raw
            var s = raw.replace(/^(alsa_output|alsa_input|bluez_output|bluez_input)\./, "")
            s = s.split(".")[0]
            s = s.replace(/^usb-/, "").replace(/-[0-9]+$/, "")
            s = s.replace(/[_-]+/g, " ").trim()
            return s.length ? s : raw
        }
        function _runAudioCmd(cmd, callback) {
            var p = Qt.createQmlObject('import Quickshell.Io; Process {}', setRoot)
            p.command = cmd
            p.exited.connect(function() { if (callback) callback(); p.destroy() })
            p.running = true
        }
        function _syncCombos() {
            if (sinkCombo) {
                var si = sinks.indexOf(defaultSink)
                sinkCombo.currentIndex = si >= 0 ? si : 0
            }
            if (sourceCombo) {
                var ci = sources.indexOf(defaultSource)
                sourceCombo.currentIndex = ci >= 0 ? ci : 0
            }
        }

        function _adjustTimeout(delta) {
            ConfigService.notificationTimeout = Math.max(500, Math.min(30000, ConfigService.notificationTimeout + delta))
            ConfigService.save()
        }

        Component.onCompleted: refreshAudio()
        onCurrentIndexChanged: if (currentIndex === 0) refreshAudio()

        // Top-anchored, no fixed canvas — reports its own natural height
        // (rail's 4-item minimum vs the active category's real content,
        // whichever is taller) so the panel hugs actual content instead of
        // padding out to a shared dense height (see root.currentTabBodyHeight).
        implicitHeight: mainRow.implicitHeight

        RowLayout {
            id: mainRow
            anchors { left: parent.left; right: parent.right; top: parent.top }
            spacing: Tokens.spaceLg

            ColumnLayout {
                // Was a hardcoded 140 — with 4 short labels ("Display",
                // "Weather", ...) the rail never needed that much room, and
                // it starved the content column of the width its rows
                // (icon + title/subtitle + control) actually need. Now
                // derived from the widest label's real measured width (see
                // setRoot.railMaxWidth) instead of a guess.
                // Nested Layout items (this is a ColumnLayout, not a plain
                // Item) default Layout.fillWidth to true in Qt Quick Layouts
                // — without explicitly disabling it, the preferredWidth
                // below was only a hint and the rail still stretched to
                // share leftover row space with the content column.
                Layout.fillWidth: false
                Layout.preferredWidth: setRoot.railMaxWidth
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignTop
                spacing: Tokens.spaceXs

                Repeater {
                    model: setRoot.categories

                    delegate: Rectangle {
                        id: railItem
                        required property var modelData
                        required property int index
                        readonly property bool selected: setRoot.currentIndex === index

                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        radius: Tokens.radiusMd
                        activeFocusOnTab: true

                        color: Qt.rgba(ThemeManager.active.accent.r, ThemeManager.active.accent.g,
                                       ThemeManager.active.accent.b, selected ? 0.22 : 0)
                        Behavior on color {
                            enabled: !ConfigService.reduceMotion
                            ColorAnimation { duration: Tokens.durationFast }
                        }

                        // Feeds setRoot.railMaxWidth from this item's natural
                        // (unconstrained) content width — iconText/labelText
                        // implicitWidth stays the full natural size regardless
                        // of the label's own Layout.fillWidth/elide below.
                        Component.onCompleted: {
                            // +2 covers subpixel implicitWidth rounding (e.g.
                            // "Weather" measured a hair short of its own
                            // elide threshold without it).
                            var natural = iconText.implicitWidth + railRow.spacing + labelText.implicitWidth + Tokens.spaceSm * 2 + 2
                            setRoot.railMaxWidth = Math.max(setRoot.railMaxWidth, natural)
                        }

                        RowLayout {
                            id: railRow
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.spaceSm
                            anchors.rightMargin: Tokens.spaceSm
                            spacing: Tokens.spaceSm

                            Text {
                                id: iconText
                                text: railItem.modelData.icon
                                font.family: ThemeManager.active.fontMono
                                font.pixelSize: Tokens.textMd
                                color: railItem.selected ? ThemeManager.active.accent : ThemeManager.active.subtext
                                Behavior on color {
                                    enabled: !ConfigService.reduceMotion
                                    ColorAnimation { duration: Tokens.durationFast }
                                }
                            }
                            Text {
                                id: labelText
                                Layout.fillWidth: true
                                text: railItem.modelData.name
                                font.family: ThemeManager.active.fontUi
                                font.pixelSize: Tokens.textSm
                                elide: Text.ElideRight
                                color: railItem.selected ? ThemeManager.active.text : ThemeManager.active.subtext
                                Behavior on color {
                                    enabled: !ConfigService.reduceMotion
                                    ColorAnimation { duration: Tokens.durationFast }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: setRoot.currentIndex = railItem.index
                        }
                        Keys.onReturnPressed: setRoot.currentIndex = railItem.index
                        Keys.onSpacePressed:  setRoot.currentIndex = railItem.index
                    }
                }

                Item { Layout.fillHeight: true }
            }

            ColumnLayout {
                // Same nested-Layout default as the rail (see its
                // Layout.fillWidth comment) — RowLayout vertically centers
                // Layout children unless told otherwise, so a short category
                // (Display, 1 row) sank toward the middle of the row's
                // height whenever the rail was the taller sibling.
                Layout.alignment: Qt.AlignTop
                Layout.fillWidth: true
                spacing: Tokens.spaceMd

                Text {
                    text: setRoot.categories[setRoot.currentIndex].name
                    font.family: ThemeManager.active.fontUi
                    font.pixelSize: Tokens.typeHeadline
                    font.bold: true
                    color: ThemeManager.active.text
                }

                Divider {}

                Item {
                    Layout.fillWidth: true
                    // Sized to the active category's own content instead of
                    // stretching to fill — top-anchored, no leftover void
                    // under short categories (Display) or centering hacks.
                    implicitHeight: {
                        if (setRoot.currentIndex === 0) return audioCol.implicitHeight
                        if (setRoot.currentIndex === 1) return displayCol.implicitHeight
                        if (setRoot.currentIndex === 2) return weatherCol.implicitHeight
                        if (setRoot.currentIndex === 3) return generalCol.implicitHeight
                        return profileCol.implicitHeight
                    }
                    height: implicitHeight
                    Behavior on height {
                        enabled: !ConfigService.reduceMotion
                        NumberAnimation { duration: Tokens.durationNormal }
                    }

                    // Audio
                    ColumnLayout {
                        id: audioCol
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        spacing: Tokens.spaceLg
                        visible: opacity > 0
                        enabled: setRoot.currentIndex === 0
                        opacity: setRoot.currentIndex === 0 ? 1 : 0
                        Behavior on opacity {
                            enabled: !ConfigService.reduceMotion
                            NumberAnimation { duration: Tokens.durationNormal }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spaceMd

                            Text {
                                text: "󰕾"
                                font.family: ThemeManager.active.fontMono
                                font.pixelSize: Tokens.textLg
                                color: ThemeManager.active.subtext
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: "Output Device"; font.family: ThemeManager.active.fontUi; font.pixelSize: Tokens.textMd; font.bold: true; color: ThemeManager.active.text }
                                Text { text: "Used for playback"; font.family: ThemeManager.active.fontUi; font.pixelSize: Tokens.textSm; color: ThemeManager.active.subtext }
                            }
                            // Signature detail: a live connection dot rather than
                            // silently falling back to "No devices found" inside
                            // the combo — functional color only (success/error),
                            // matches the one-accent budget.
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                Layout.alignment: Qt.AlignVCenter
                                color: setRoot.sinks.length > 0 ? ThemeManager.active.success : ThemeManager.active.subtext
                            }
                            GlassComboBox {
                                id: sinkCombo
                                Layout.preferredWidth: 160
                                model: setRoot.sinks.length > 0 ? setRoot.sinks : ["No devices found"]
                                enabled: setRoot.sinks.length > 0
                                formatText: setRoot.friendlyDeviceName
                                onActivated: function(index) {
                                    if (setRoot.sinks.length === 0) return
                                    var chosen = setRoot.sinks[index]
                                    setRoot._runAudioCmd(["pactl", "set-default-sink", chosen], function() {
                                        setRoot.defaultSink = chosen
                                    })
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spaceMd

                            Text {
                                text: "󰍬"
                                font.family: ThemeManager.active.fontMono
                                font.pixelSize: Tokens.textLg
                                color: ThemeManager.active.subtext
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: "Input Device"; font.family: ThemeManager.active.fontUi; font.pixelSize: Tokens.textMd; font.bold: true; color: ThemeManager.active.text }
                                Text { text: "Used for recording"; font.family: ThemeManager.active.fontUi; font.pixelSize: Tokens.textSm; color: ThemeManager.active.subtext }
                            }
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                Layout.alignment: Qt.AlignVCenter
                                color: setRoot.sources.length > 0 ? ThemeManager.active.success : ThemeManager.active.subtext
                            }
                            GlassComboBox {
                                id: sourceCombo
                                Layout.preferredWidth: 160
                                model: setRoot.sources.length > 0 ? setRoot.sources : ["No devices found"]
                                enabled: setRoot.sources.length > 0
                                formatText: setRoot.friendlyDeviceName
                                onActivated: function(index) {
                                    if (setRoot.sources.length === 0) return
                                    var chosen = setRoot.sources[index]
                                    setRoot._runAudioCmd(["pactl", "set-default-source", chosen], function() {
                                        setRoot.defaultSource = chosen
                                    })
                                }
                            }
                        }
                    }

                    // Display
                    ColumnLayout {
                        id: displayCol
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        spacing: Tokens.spaceLg
                        visible: opacity > 0
                        enabled: setRoot.currentIndex === 1
                        opacity: setRoot.currentIndex === 1 ? 1 : 0
                        Behavior on opacity {
                            enabled: !ConfigService.reduceMotion
                            NumberAnimation { duration: Tokens.durationNormal }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spaceMd

                            Text {
                                text: "󰍹"
                                font.family: ThemeManager.active.fontMono
                                font.pixelSize: Tokens.textLg
                                color: ThemeManager.active.subtext
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: "Topbar Monitors"; font.family: ThemeManager.active.fontUi; font.pixelSize: Tokens.textMd; font.bold: true; color: ThemeManager.active.text }
                                Text { text: "Empty = all monitors"; font.family: ThemeManager.active.fontUi; font.pixelSize: Tokens.textSm; color: ThemeManager.active.subtext }
                            }
                            Rectangle {
                                Layout.preferredWidth: 200
                                Layout.preferredHeight: 36
                                radius: Tokens.radiusMd
                                color: Qt.rgba(ThemeManager.active.base.r, ThemeManager.active.base.g,
                                               ThemeManager.active.base.b, 0.22 * ThemeManager.active.opacity)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.22)

                                TextInput {
                                    anchors.fill: parent
                                    anchors.margins: Tokens.spaceSm
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true
                                    text: (ConfigService.sidebarMonitors || []).join(" ")
                                    font.family: ThemeManager.active.fontUi
                                    font.pixelSize: Tokens.textSm
                                    color: ThemeManager.active.text
                                    onEditingFinished: {
                                        ConfigService.sidebarMonitors = text.trim().split(/\s+/).filter(Boolean)
                                        ConfigService.save()
                                    }
                                }
                            }
                        }
                    }

                    // Weather
                    ColumnLayout {
                        id: weatherCol
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        spacing: Tokens.spaceLg
                        visible: opacity > 0
                        enabled: setRoot.currentIndex === 2
                        opacity: setRoot.currentIndex === 2 ? 1 : 0
                        Behavior on opacity {
                            enabled: !ConfigService.reduceMotion
                            NumberAnimation { duration: Tokens.durationNormal }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spaceMd

                            Text {
                                text: "󰖐"
                                font.family: ThemeManager.active.fontMono
                                font.pixelSize: Tokens.textLg
                                color: ThemeManager.active.subtext
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: "Weather Location"; font.family: ThemeManager.active.fontUi; font.pixelSize: Tokens.textMd; font.bold: true; color: ThemeManager.active.text }
                                Text { text: "Empty = auto-detect"; font.family: ThemeManager.active.fontUi; font.pixelSize: Tokens.textSm; color: ThemeManager.active.subtext }
                            }
                            Rectangle {
                                Layout.preferredWidth: 200
                                Layout.preferredHeight: 36
                                radius: Tokens.radiusMd
                                color: Qt.rgba(ThemeManager.active.base.r, ThemeManager.active.base.g,
                                               ThemeManager.active.base.b, 0.22 * ThemeManager.active.opacity)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.22)

                                TextInput {
                                    anchors.fill: parent
                                    anchors.margins: Tokens.spaceSm
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true
                                    text: ConfigService.weatherLocation || ""
                                    font.family: ThemeManager.active.fontUi
                                    font.pixelSize: Tokens.textSm
                                    color: ThemeManager.active.text
                                    onEditingFinished: {
                                        ConfigService.weatherLocation = text
                                        ConfigService.save()
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spaceMd

                            Text {
                                text: "󰔏"
                                font.family: ThemeManager.active.fontMono
                                font.pixelSize: Tokens.textLg
                                color: ThemeManager.active.subtext
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: "Temperature Unit"; font.family: ThemeManager.active.fontUi; font.pixelSize: Tokens.textMd; font.bold: true; color: ThemeManager.active.text }
                                Text { text: "For weather readings"; font.family: ThemeManager.active.fontUi; font.pixelSize: Tokens.textSm; color: ThemeManager.active.subtext }
                            }
                            SegCtrl {
                                options: ["C", "F"]
                                current: ConfigService.temperatureUnit || "C"
                                onPick: function(v) {
                                    ConfigService.temperatureUnit = v
                                    ConfigService.save()
                                }
                            }
                        }
                    }

                    // General
                    ColumnLayout {
                        id: generalCol
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        spacing: Tokens.spaceLg
                        visible: opacity > 0
                        enabled: setRoot.currentIndex === 3
                        opacity: setRoot.currentIndex === 3 ? 1 : 0
                        Behavior on opacity {
                            enabled: !ConfigService.reduceMotion
                            NumberAnimation { duration: Tokens.durationNormal }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spaceMd

                            Text {
                                text: "󰒓"
                                font.family: ThemeManager.active.fontMono
                                font.pixelSize: Tokens.textLg
                                color: ThemeManager.active.subtext
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: "Clock Format"; font.family: ThemeManager.active.fontUi; font.pixelSize: Tokens.textMd; font.bold: true; color: ThemeManager.active.text }
                                Text { text: "12h or 24h display"; font.family: ThemeManager.active.fontUi; font.pixelSize: Tokens.textSm; color: ThemeManager.active.subtext }
                            }
                            SegCtrl {
                                options: ["24h", "12h"]
                                current: ConfigService.clockFormat || "24h"
                                onPick: function(v) {
                                    ConfigService.clockFormat = v
                                    ConfigService.save()
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spaceMd

                            Text {
                                text: "󰂚"
                                font.family: ThemeManager.active.fontMono
                                font.pixelSize: Tokens.textLg
                                color: ThemeManager.active.subtext
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: "Notification Timeout"; font.family: ThemeManager.active.fontUi; font.pixelSize: Tokens.textMd; font.bold: true; color: ThemeManager.active.text }
                                Text { text: "Auto-dismiss delay"; font.family: ThemeManager.active.fontUi; font.pixelSize: Tokens.textSm; color: ThemeManager.active.subtext }
                            }
                            RowLayout {
                                spacing: Tokens.spaceXs

                                GlassButton {
                                    width: 32; height: 30
                                    activeFocusOnTab: true
                                    Text {
                                        anchors.centerIn: parent
                                        text: "−"
                                        font.family: ThemeManager.active.fontUi
                                        font.pixelSize: Tokens.textMd
                                        color: ThemeManager.active.text
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: setRoot._adjustTimeout(-500) }
                                    Keys.onReturnPressed: setRoot._adjustTimeout(-500)
                                    Keys.onSpacePressed:  setRoot._adjustTimeout(-500)
                                }
                                Text {
                                    Layout.preferredWidth: 48
                                    horizontalAlignment: Text.AlignHCenter
                                    text: (ConfigService.notificationTimeout / 1000).toFixed(1) + "s"
                                    font.family: ThemeManager.active.fontMono
                                    font.pixelSize: Tokens.textSm
                                    color: ThemeManager.active.text
                                }
                                GlassButton {
                                    width: 32; height: 30
                                    activeFocusOnTab: true
                                    Text {
                                        anchors.centerIn: parent
                                        text: "+"
                                        font.family: ThemeManager.active.fontUi
                                        font.pixelSize: Tokens.textMd
                                        color: ThemeManager.active.text
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: setRoot._adjustTimeout(500) }
                                    Keys.onReturnPressed: setRoot._adjustTimeout(500)
                                    Keys.onSpacePressed:  setRoot._adjustTimeout(500)
                                }
                            }
                        }
                    }

                    // Profile
                    ColumnLayout {
                        id: profileCol
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        spacing: Tokens.spaceLg
                        visible: opacity > 0
                        enabled: setRoot.currentIndex === 4
                        opacity: setRoot.currentIndex === 4 ? 1 : 0
                        Behavior on opacity {
                            enabled: !ConfigService.reduceMotion
                            NumberAnimation { duration: Tokens.durationNormal }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spaceMd
                            Text {
                                text: "󰀄"
                                font.family: ThemeManager.active.fontMono
                                font.pixelSize: Tokens.textLg
                                color: ThemeManager.active.subtext
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: "Avatar"; font.family: ThemeManager.active.fontUi; font.pixelSize: Tokens.textMd; font.bold: true; color: ThemeManager.active.text }
                                Text { text: "Shown on lockscreen, login, and here"; font.family: ThemeManager.active.fontUi; font.pixelSize: Tokens.textSm; color: ThemeManager.active.subtext }
                            }
                        }

                        // Idle: current avatar preview + upload trigger
                        RowLayout {
                            id: idleView
                            visible: setRoot.profileState === "idle"
                            Layout.fillWidth: true
                            spacing: Tokens.spaceMd

                            Item {
                                width: 56; height: 56

                                Image {
                                    id: profileAvatarImg
                                    anchors.fill: parent
                                    source: "file:///etc/theme-assets/avatar.png?v=" + ConfigService.avatarVersion
                                    fillMode: Image.PreserveAspectCrop
                                    cache: false
                                    visible: false
                                    layer.enabled: true
                                }
                                Rectangle {
                                    id: profileAvatarMask
                                    anchors.fill: parent
                                    radius: width / 2
                                    visible: false
                                    layer.enabled: true
                                }
                                MultiEffect {
                                    anchors.fill: profileAvatarImg
                                    source: profileAvatarImg
                                    maskEnabled: true
                                    maskSource: profileAvatarMask
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "transparent"
                                    border.width: 2
                                    border.color: ThemeManager.active.accent
                                }
                            }

                            GlassButton {
                                width: 140; height: 36
                                activeFocusOnTab: true
                                Text {
                                    anchors.centerIn: parent
                                    text: "Change Avatar"
                                    font.family: ThemeManager.active.fontUi
                                    font.pixelSize: Tokens.textSm
                                    color: ThemeManager.active.text
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: avatarFileDialog.open()
                                }
                                Keys.onReturnPressed: avatarFileDialog.open()
                                Keys.onSpacePressed:  avatarFileDialog.open()
                            }
                        }

                        // Cropping: pan/zoom the picked image inside a circular guide
                        ColumnLayout {
                            id: cropView
                            visible: setRoot.profileState === "cropping"
                            Layout.fillWidth: true
                            spacing: Tokens.spaceMd

                            Item {
                                id: cropStage
                                Layout.alignment: Qt.AlignHCenter
                                width: setRoot.cropViewport
                                height: setRoot.cropViewport

                                Item {
                                    id: cropClip
                                    anchors.fill: parent
                                    clip: true

                                    Image {
                                        id: cropImg
                                        source: setRoot.pickedFile
                                        cache: false
                                        smooth: true
                                        x: setRoot.cropOffsetX
                                        y: setRoot.cropOffsetY
                                        width: setRoot.srcW * setRoot.cropScale
                                        height: setRoot.srcH * setRoot.cropScale
                                        onStatusChanged: if (status === Image.Ready) {
                                            setRoot.srcW = sourceSize.width
                                            setRoot.srcH = sourceSize.height
                                            setRoot.resetCrop()
                                        }
                                    }
                                }

                                MouseArea {
                                    id: cropDrag
                                    anchors.fill: parent
                                    property real lastX: 0
                                    property real lastY: 0
                                    onPressed: function(mouse) { lastX = mouse.x; lastY = mouse.y }
                                    onPositionChanged: function(mouse) {
                                        if (pressed) {
                                            setRoot.cropOffsetX += mouse.x - lastX
                                            setRoot.cropOffsetY += mouse.y - lastY
                                            setRoot.clampCropOffsets()
                                            lastX = mouse.x; lastY = mouse.y
                                        }
                                    }
                                    onWheel: function(wheel) {
                                        setRoot.setCropScale(setRoot.cropScale * (wheel.angleDelta.y > 0 ? 1.1 : 1 / 1.1))
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "transparent"
                                    border.width: 2
                                    border.color: ThemeManager.active.accent
                                }
                            }

                            Slider {
                                id: zoomSlider
                                Layout.fillWidth: true
                                from: setRoot.cropMinScale
                                to: setRoot.cropMaxScale
                                value: setRoot.cropScale
                                onMoved: setRoot.setCropScale(value)

                                background: Rectangle {
                                    x: zoomSlider.leftPadding
                                    y: zoomSlider.topPadding + zoomSlider.availableHeight / 2 - height / 2
                                    width: zoomSlider.availableWidth
                                    height: 4
                                    radius: 2
                                    color: ThemeManager.active.overlay
                                    Rectangle {
                                        width: zoomSlider.visualPosition * parent.width
                                        height: parent.height
                                        radius: parent.radius
                                        color: ThemeManager.active.accent
                                    }
                                }
                                handle: Rectangle {
                                    x: zoomSlider.leftPadding + zoomSlider.visualPosition * (zoomSlider.availableWidth - width)
                                    y: zoomSlider.topPadding + zoomSlider.availableHeight / 2 - height / 2
                                    width: 14; height: 14
                                    radius: 7
                                    color: ThemeManager.active.accent
                                }
                            }

                            Text {
                                visible: setRoot.cropError.length > 0
                                text: setRoot.cropError
                                font.family: ThemeManager.active.fontUi
                                font.pixelSize: Tokens.textSm
                                color: ThemeManager.active.error
                            }

                            RowLayout {
                                id: cropButtonRow
                                spacing: Tokens.spaceMd

                                GlassButton {
                                    width: 80; height: 36
                                    activeFocusOnTab: true
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Cancel"
                                        font.family: ThemeManager.active.fontUi
                                        font.pixelSize: Tokens.textSm
                                        color: ThemeManager.active.text
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: setRoot.cancelCrop()
                                    }
                                    Keys.onReturnPressed: setRoot.cancelCrop()
                                    Keys.onSpacePressed:  setRoot.cancelCrop()
                                }

                                GlassButton {
                                    active: true
                                    width: 80; height: 36
                                    activeFocusOnTab: true
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Save"
                                        font.family: ThemeManager.active.fontUi
                                        font.pixelSize: Tokens.textSm
                                        color: ThemeManager.active.text
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: setRoot.performCrop()
                                    }
                                    Keys.onReturnPressed: setRoot.performCrop()
                                    Keys.onSpacePressed:  setRoot.performCrop()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

