import QtQuick
import QtQuick.Layouts
import "../.."

RowLayout {
    id: root

    property string title: ""
    signal closeRequested()

    Layout.fillWidth: true

    Text {
        text: root.title
        font.family: ThemeManager.active.fontUi
        font.pixelSize: Tokens.textLg
        font.bold: true
        color: ThemeManager.active.text
        Layout.fillWidth: true
    }

    GlassButton {
        id: closeBtn
        width: 28; height: 28
        activeFocusOnTab: true
        active: closeMouse.containsMouse || closeBtn.activeFocus

        Text {
            anchors.centerIn: parent
            text: "󰅖"
            font.family: ThemeManager.active.fontMono
            font.pixelSize: Tokens.textMd
            color: ThemeManager.active.text
        }

        MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeRequested()
        }

        Keys.onReturnPressed: root.closeRequested()
        Keys.onSpacePressed:  root.closeRequested()
    }
}
