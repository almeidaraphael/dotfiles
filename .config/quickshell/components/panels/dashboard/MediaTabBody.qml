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

    // ================= Media tab ============================================
    // Straight port of the old standalone MediaPanel.qml, scaled up. See
    // .ui-craft/spec.md -> Surface: Media.
Item {
        id: mdRoot

        focus: true
        Keys.onSpacePressed: MediaService.playPause()
        Keys.onLeftPressed:  MediaService.previous()
        Keys.onRightPressed: MediaService.next()

        readonly property bool isEmpty: MediaService.activePlayer === ""

        // Drives Dashboard's per-tab panel height (root.currentTabBodyHeight)
        // — same bottom-up pattern as Overview's calendarCard. mediaContent's
        // implicitHeight is computed from its children regardless of mdRoot's
        // externally-assigned actual height, so no binding loop.
        implicitHeight: Tokens.spaceXl * 2 + (mdRoot.isEmpty ? Math.max(emptyColumn.implicitHeight, 160) : mediaContent.implicitHeight)

        Image {
            id: artBg
            anchors.fill: parent
            source: MediaService.artUrl
            fillMode: Image.PreserveAspectCrop
            visible: ThemeManager.active.blur && MediaService.artUrl !== "" && !mdRoot.isEmpty
            opacity: 0.3
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64 }
        }

        Canvas {
            id: waveformBg
            // Caged to a bottom band, not full-bleed — full-height made this
            // the single loudest object in the panel despite carrying no
            // information (pure decoration). Confining it + lower opacity
            // reads as texture behind the controls instead of a competing
            // hero element.
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 160
            opacity: mdRoot.isEmpty ? 0.12 : 0.22
            Connections { target: MediaService; function onSpectrumChanged() { waveformBg.requestPaint() } }
            Connections { target: mdRoot; function onIsEmptyChanged() { waveformBg.requestPaint() } }
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                if (mdRoot.isEmpty) { _paintFlatline(ctx); return }
                var bars = MediaService.spectrum
                if (MediaService.status !== "Playing" || bars.length === 0) return
                switch (ThemeManager.active.name) {
                    case "tokyonight": _paintSmoothLine(ctx, bars); break
                    case "nord":       _paintSparseBars(ctx, bars); break
                    default:           _paintBars(ctx, bars);      break // dracula
                }
            }
            function _paintFlatline(ctx) {
                var mid = height / 2
                ctx.strokeStyle = ThemeManager.active.subtext
                ctx.lineWidth = 2
                ctx.beginPath(); ctx.moveTo(0, mid); ctx.lineTo(width, mid); ctx.stroke()
            }
            function _paintBars(ctx, bars) {
                var grad = ctx.createLinearGradient(0, 0, width, 0)
                grad.addColorStop(0,   ThemeManager.active.accent)
                grad.addColorStop(0.5, ThemeManager.active.accentAlt)
                grad.addColorStop(1,   ThemeManager.active.highlight)
                ctx.fillStyle = grad
                var gap = 3
                var barWidth = (width - gap * (bars.length - 1)) / bars.length
                var mid = height / 2
                for (var i = 0; i < bars.length; i++) {
                    var mag = Math.min(bars[i] / 100, 1.0)
                    var barHeight = Math.max(mag * mid, 2)
                    var x = i * (barWidth + gap)
                    ctx.fillRect(x, mid - barHeight, barWidth, barHeight * 2)
                }
            }
            function _paintSmoothLine(ctx, bars) {
                var mid = height / 2
                var step = width / (bars.length - 1)
                var grad = ctx.createLinearGradient(0, 0, width, 0)
                grad.addColorStop(0, ThemeManager.active.accent); grad.addColorStop(1, ThemeManager.active.accentAlt)
                ctx.strokeStyle = grad; ctx.lineWidth = 2
                ctx.beginPath(); ctx.moveTo(0, mid)
                for (var i = 0; i < bars.length - 1; i++) {
                    var mag = Math.min(bars[i] / 100, 1.0); var y = mid - mag * mid * 0.8
                    var xMid = (i + 0.5) * step
                    var nextMag = Math.min(bars[i + 1] / 100, 1.0); var nextY = mid - nextMag * mid * 0.8
                    ctx.quadraticCurveTo(i * step, y, xMid, (y + nextY) / 2)
                }
                ctx.stroke()
            }
            function _paintSparseBars(ctx, bars) {
                ctx.fillStyle = ThemeManager.active.accent
                var stride = 3, gap = 6
                var visible = Math.floor(bars.length / stride)
                var barWidth = (width - gap * (visible - 1)) / visible
                var mid = height / 2
                for (var i = 0; i < visible; i++) {
                    var mag = Math.min(bars[i * stride] / 100, 1.0)
                    var barHeight = Math.max(mag * mid * 0.6, 2)
                    var x = i * (barWidth + gap)
                    ctx.fillRect(x, mid - barHeight, barWidth, barHeight * 2)
                }
            }
        }

        ColumnLayout {
            id: emptyColumn
            anchors.centerIn: parent
            spacing: Tokens.spaceSm
            visible: mdRoot.isEmpty
            opacity: visible ? 1 : 0
            Behavior on opacity { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationNormal } }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "♪"
                font.family: ThemeManager.active.fontMono
                font.pixelSize: Tokens.typeDisplay
                color: ThemeManager.active.subtext
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Nothing playing"
                font.family: ThemeManager.active.fontUi
                font.pixelSize: Tokens.textMd
                color: ThemeManager.active.subtext
            }
        }

        ColumnLayout {
            id: mediaContent
            anchors { fill: parent; margins: Tokens.spaceXl }
            spacing: Tokens.spaceMd
            visible: !mdRoot.isEmpty
            opacity: visible ? 1 : 0
            Behavior on opacity { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationNormal } }

            RowLayout {
                id: nowPlayingRow
                Layout.fillWidth: true
                spacing: Tokens.spaceLg

                property string _lastTitle: MediaService.title
                onVisibleChanged: if (visible) _lastTitle = MediaService.title

                Connections {
                    target: MediaService
                    function onTitleChanged() {
                        if (MediaService.title === nowPlayingRow._lastTitle) return
                        nowPlayingRow._lastTitle = MediaService.title
                        nowPlayingRow.opacity = 0
                        nowPlayingRow.opacity = 1
                    }
                }

                Behavior on opacity { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationNormal } }

                Rectangle {
                    // Was 192 — outweighed the actual primary action (transport
                    // controls) and left the text column looking sparse next to it.
                    width: 144; height: 144
                    radius: Tokens.radiusMd; clip: true; color: ThemeManager.active.overlay
                    visible: MediaService.artUrl !== ""
                    Image { anchors.fill: parent; source: MediaService.artUrl; fillMode: Image.PreserveAspectCrop }
                }
                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Tokens.spaceXs
                    Text { text: MediaService.title; font.pixelSize: Tokens.typeHeadline; font.bold: true; color: ThemeManager.active.text; elide: Text.ElideRight; Layout.fillWidth: true; font.family: ThemeManager.active.fontUi }
                    Text { text: MediaService.artist; font.pixelSize: Tokens.textLg; color: ThemeManager.active.subtext; elide: Text.ElideRight; Layout.fillWidth: true; font.family: ThemeManager.active.fontUi }
                    Text { text: MediaService.album; font.pixelSize: Tokens.textMd; color: ThemeManager.active.subtext; elide: Text.ElideRight; Layout.fillWidth: true; font.family: ThemeManager.active.fontUi }
                    Row {
                        spacing: Tokens.spaceSm
                        visible: MediaService.players.length > 1
                        Repeater {
                            model: MediaService.players
                            Rectangle {
                                id: pill
                                required property var modelData
                                readonly property bool isActive: modelData === MediaService.activePlayer
                                readonly property string _app: modelData.split(".")[0]
                                height: 22; width: pillRow.implicitWidth + Tokens.spaceMd; radius: height / 2
                                color: isActive ? ThemeManager.active.accent : ThemeManager.active.overlay
                                border.color: ThemeManager.active.blur ? Qt.rgba(1,1,1, isActive?0.38:0.22) : Qt.rgba(ThemeManager.active.border.r, ThemeManager.active.border.g, ThemeManager.active.border.b, 0.9)
                                border.width: 1; activeFocusOnTab: true
                                RowLayout {
                                    id: pillRow; anchors.centerIn: parent; spacing: Tokens.spaceXs
                                    IconImage { implicitSize: 12; source: Quickshell.hasThemeIcon(pill._app) ? Quickshell.iconPath(pill._app) : Tokens.fallbackIcon }
                                    Text { text: pill._app.charAt(0).toUpperCase() + pill._app.slice(1); font.pixelSize: Tokens.textXs; color: pill.isActive ? ThemeManager.active.base : ThemeManager.active.text; font.family: ThemeManager.active.fontUi }
                                }
                                MouseArea { anchors.fill: parent; onClicked: MediaService.setPlayer(pill.modelData) }
                                Keys.onReturnPressed: MediaService.setPlayer(pill.modelData)
                                Keys.onSpacePressed:  MediaService.setPlayer(pill.modelData)
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true; height: 20
                // Extra breathing room above the mm:ss labels — they anchor to
                // this item's top edge, so the column's base spacing alone put
                // them right up against the art/text row above.
                Layout.topMargin: Tokens.spaceSm
                Rectangle {
                    id: track
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                    // Was 4px — read as an afterthought next to the 144px art
                    // and 44px transport buttons; this is the primary scrub
                    // surface and needed to carry equivalent visual weight.
                    height: 6; radius: 3; color: ThemeManager.active.overlay
                    readonly property real playFraction: MediaService.duration > 0 ? MediaService.position / MediaService.duration : 0
                    Rectangle {
                        anchors.fill: parent; radius: parent.radius; color: ThemeManager.active.accent
                        transform: Scale { origin.x: 0; xScale: track.playFraction; Behavior on xScale { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationSlower } } }
                    }
                    Rectangle {
                        width: 12; height: 12; radius: 6; anchors.verticalCenter: track.verticalCenter
                        x: track.width * track.playFraction - width / 2
                        color: ThemeManager.active.accent; border.color: ThemeManager.active.text; border.width: 1.5
                        Behavior on x { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationSlower } }
                    }
                }
                MouseArea { anchors.fill: parent; onClicked: MediaService.seek(MediaService.duration * (mouseX / width)) }
                Text {
                    anchors.left: parent.left; anchors.bottom: parent.top
                    text: mdRoot._fmt(MediaService.position); font.family: ThemeManager.active.fontMono; font.pixelSize: Tokens.textXs; color: ThemeManager.active.subtext
                }
                Text {
                    anchors.right: parent.right; anchors.bottom: parent.top
                    text: mdRoot._fmt(MediaService.duration); font.family: ThemeManager.active.fontMono; font.pixelSize: Tokens.textXs; color: ThemeManager.active.subtext
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Tokens.spaceLg
                Repeater {
                    model: [ { icon: "󰒮", action: "previous" }, { icon: MediaService.status === "Playing" ? "󰏤" : "󰐊", action: "playPause" }, { icon: "󰒭", action: "next" } ]
                    GlassButton {
                        // Play/pause (the primary action) sized up over prev/next —
                        // all three were identical 44px before, so the actual
                        // primary control didn't read as primary.
                        readonly property bool isPrimary: modelData.action === "playPause"
                        width: isPrimary ? 52 : 44; height: isPrimary ? 52 : 44
                        active: isPrimary && MediaService.status === "Playing"
                        activeFocusOnTab: true
                        required property var modelData
                        Text { anchors.centerIn: parent; text: modelData.icon; font.family: ThemeManager.active.fontMono; font.pixelSize: parent.isPrimary ? Tokens.text3xl : Tokens.text2xl; color: ThemeManager.active.text }
                        MouseArea { anchors.fill: parent; onClicked: MediaService[modelData.action]() }
                        Keys.onReturnPressed: MediaService[modelData.action]()
                        Keys.onSpacePressed:  MediaService[modelData.action]()
                    }
                }
            }
        }

        function _fmt(secs) { var m = Math.floor(secs / 60); var s = Math.floor(secs % 60).toString().padStart(2, "0"); return m + ":" + s }
    }

