import QtQuick
import "../.."
import "../shared"

GlassButton {
    id: root

    property string stream: "output" // "output" | "input"
    readonly property bool isOutput: stream === "output"

    readonly property real volume: isOutput ? AudioService.outputVolume : AudioService.inputVolume
    readonly property bool muted:  isOutput ? AudioService.outputMuted  : AudioService.inputMuted

    width: 28
    height: 28
    frameRadius: Tokens.radiusMd
    hovered: mouseArea.containsMouse

    Text {
        anchors.centerIn: parent
        font.family: ThemeManager.active.fontMono
        font.pixelSize: Tokens.textLg
        color: root.muted ? ThemeManager.active.error : ThemeManager.active.subtext
        text: {
            if (root.isOutput) {
                if (root.muted) return "󰝟"
                return root.volume > 0.6 ? "󰕾" : root.volume > 0.2 ? "󰖀" : "󰕿"
            }
            return root.muted ? "󰍭" : "󰍬"
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) PanelManager.toggleTab("settings")
            else AudioService.toggleMute(root.stream)
        }
        onWheel: function(wheel) {
            AudioService.adjustVolume(root.stream, wheel.angleDelta.y > 0 ? 0.05 : -0.05)
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: ThemeManager.active.highlight
    }

    activeFocusOnTab: true
    Keys.onReturnPressed: AudioService.toggleMute(root.stream)
    Keys.onSpacePressed:  AudioService.toggleMute(root.stream)
    Keys.onUpPressed:     AudioService.adjustVolume(root.stream, 0.05)
    Keys.onDownPressed:   AudioService.adjustVolume(root.stream, -0.05)
}
