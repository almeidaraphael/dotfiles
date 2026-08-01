import QtQuick
import "../.."
import "../shared"

GlassButton {
    id: root

    width: 28
    height: 28
    frameRadius: Tokens.radiusMd
    active: NotificationService.doNotDisturb
    hovered: mouseArea.containsMouse

    Text {
        anchors.centerIn: parent
        text: NotificationService.doNotDisturb ? "󰂛" : "󰂚"
        font.family: ThemeManager.active.fontMono
        font.pixelSize: Tokens.textLg
        color: NotificationService.doNotDisturb ? ThemeManager.active.base : ThemeManager.active.subtext
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: ThemeManager.active.highlight
    }

    activeFocusOnTab: true
    Keys.onReturnPressed: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
    Keys.onSpacePressed:  NotificationService.doNotDisturb = !NotificationService.doNotDisturb
}
