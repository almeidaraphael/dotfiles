import QtQuick
import "../.."
import "../shared"

GlassButton {
    id: root

    width: 28
    height: 28
    frameRadius: Tokens.radiusMd
    active: LowResourceModeService.active
    hovered: mouseArea.containsMouse

    Text {
        anchors.centerIn: parent
        // md-expansion_card — same glyph for both states, GlassButton's
        // active-tint already conveys on/off (see KeepAwakeButton for the
        // two-glyph alternative; a GPU icon doesn't have an obvious
        // opposite-state glyph the way a coffee cup/bell does).
        text: "󰢮"
        font.family: ThemeManager.active.fontMono
        font.pixelSize: Tokens.textLg
        color: LowResourceModeService.active ? ThemeManager.active.base : ThemeManager.active.subtext
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: LowResourceModeService.toggle()
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: ThemeManager.active.highlight
    }

    activeFocusOnTab: true
    Keys.onReturnPressed: LowResourceModeService.toggle()
    Keys.onSpacePressed:  LowResourceModeService.toggle()
}
