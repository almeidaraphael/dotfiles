import QtQuick
import "../.."

Item {
    id: root

    property var now: new Date()

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    activeFocusOnTab: true
    Keys.onReturnPressed: PanelManager.toggleTab("overview")
    Keys.onSpacePressed:  PanelManager.toggleTab("overview")

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: PanelManager.toggleTab("overview")
    }

    Text {
        id: col
        anchors.centerIn: parent
        text: {
            var h = root.now.getHours()
            var m = root.now.getMinutes().toString().padStart(2, "0")
            if (ConfigService.clockFormat === "12h") {
                var ampm = h >= 12 ? "PM" : "AM"
                h = h % 12 || 12
                return h + ":" + m + " " + ampm
            }
            return h.toString().padStart(2, "0") + ":" + m
        }
        font.family: ThemeManager.active.fontMono
        font.pixelSize: Tokens.text2xl
        font.bold: true
        color: ThemeManager.active.text
    }
}
