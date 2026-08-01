import QtQuick
import "../.."

Rectangle {
    id: root

    property string panelName: ""
    property string iconName:  ""

    signal clicked()

    readonly property bool isActive: panelName !== "" && PanelManager.activePanel === panelName

    width: 34
    height: 34
    radius: Tokens.radiusMd
    color: isActive ? ThemeManager.active.accent : "transparent"
    border.width: activeFocus ? 2 : (isActive ? 2 : 0)
    border.color: activeFocus ? ThemeManager.active.highlight : ThemeManager.active.accentAlt

    Behavior on color { enabled: !ConfigService.reduceMotion; ColorAnimation { duration: Tokens.durationFast } }

    Text {
        anchors.centerIn: parent
        text: root.iconName
        font.family: ThemeManager.active.fontMono
        font.pixelSize: Tokens.textLg
        color: isActive ? ThemeManager.active.base : ThemeManager.active.subtext
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (root.panelName !== "")
                PanelManager.toggle(root.panelName)
            root.clicked()
        }
        cursorShape: Qt.PointingHandCursor
    }

    Keys.onReturnPressed: {
        if (panelName !== "") PanelManager.toggle(panelName)
        clicked()
    }
    Keys.onSpacePressed: {
        if (panelName !== "") PanelManager.toggle(panelName)
        clicked()
    }
    activeFocusOnTab: true
}
