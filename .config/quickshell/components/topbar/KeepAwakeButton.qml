import QtQuick
import "../.."
import "../shared"

GlassButton {
    id: root

    width: 28
    height: 28
    frameRadius: Tokens.radiusMd
    active: IdleInhibitService.awake
    hovered: mouseArea.containsMouse

    Text {
        anchors.centerIn: parent
        // Coffee cup, not eye — "keep awake" reads as visibility/privacy with
        // an eye glyph; the coffee-cup metaphor (macOS caffeinate) is the one
        // users already recognize for idle-inhibit.
        text: IdleInhibitService.awake ? "󰅶" : "󰛊"
        font.family: ThemeManager.active.fontMono
        font.pixelSize: Tokens.textLg
        color: IdleInhibitService.awake ? ThemeManager.active.base : ThemeManager.active.subtext
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: IdleInhibitService.toggle()
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: ThemeManager.active.highlight
    }

    activeFocusOnTab: true
    Keys.onReturnPressed: IdleInhibitService.toggle()
    Keys.onSpacePressed:  IdleInhibitService.toggle()
}
