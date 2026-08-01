import QtQuick
import QtQuick.Layouts
import Quickshell
import "../.."
import "../shared"
import "notificationLogic.js" as NotifLogic

ColumnLayout {
    id: root

    required property var notification
    property int iconSize: 40
    property int imageHeight: 120

    spacing: Tokens.spaceSm

    readonly property var _split: NotifLogic.splitActions(root.notification.actions || [])
    readonly property var _bodyParts: NotifLogic.extractBodyImage(root.notification.body || "")
    readonly property string _banner: NotifLogic.resolveNotificationBanner(root.notification)

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spaceMd

        Item {
            Layout.preferredWidth: root.iconSize
            Layout.preferredHeight: root.iconSize
            Layout.alignment: Qt.AlignTop
            clip: true

            Rectangle {
                anchors.fill: parent
                radius: Tokens.radiusMd
                color: ThemeManager.active.base
                visible: _iconImg.status !== Image.Ready

                Text {
                    anchors.centerIn: parent
                    text: "󰂚"
                    font.family: ThemeManager.active.fontMono
                    font.pixelSize: root.iconSize * 0.5
                    color: ThemeManager.active.accent
                }
            }

            Image {
                id: _iconImg
                anchors.fill: parent
                visible: status === Image.Ready
                source: NotifLogic.resolveNotificationIcon(root.notification,
                    function(name) { return Quickshell.hasThemeIcon(name) ? Quickshell.iconPath(name) : "" },
                    function(id) { return DesktopEntries.byId(id) },
                    function(appName) { return DesktopEntries.heuristicLookup(appName) }) || Tokens.fallbackIcon
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spaceXs

            Text {
                Layout.fillWidth: true
                text: root.notification.summary
                font.family: ThemeManager.active.fontUi
                font.pixelSize: Tokens.textMd
                font.bold: true
                color: ThemeManager.active.text
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: root._bodyParts.text
                font.family: ThemeManager.active.fontUi
                font.pixelSize: Tokens.textSm
                color: ThemeManager.active.subtext
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
                visible: text.length > 0
            }
        }
    }

    Image {
        id: _heroImg
        Layout.fillWidth: true
        Layout.preferredHeight: root.imageHeight
        visible: root._banner.length > 0 && status === Image.Ready
        source: root._banner
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        clip: true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spaceSm
        visible: root._split.buttonActions.length > 0

        Repeater {
            model: root._split.buttonActions
            delegate: GlassButton {
                id: btn
                required property var modelData

                readonly property var _display: NotifLogic.actionDisplay(
                    modelData, root.notification.hasActionIcons || false)

                Layout.preferredHeight: 26
                Layout.preferredWidth: _display.mode === "icon" ? 36 : (_label.implicitWidth + Tokens.space2xl)
                Layout.alignment: Qt.AlignVCenter

                Text {
                    id: _label
                    anchors.centerIn: parent
                    visible: btn._display.mode === "text"
                    text: btn._display.mode === "text" ? btn._display.value : ""
                    font.family: ThemeManager.active.fontUi
                    font.pixelSize: Tokens.textSm
                    color: ThemeManager.active.text
                }

                Image {
                    anchors.centerIn: parent
                    visible: btn._display.mode === "icon"
                    width: 16; height: 16
                    source: btn._display.mode === "icon"
                        ? (Quickshell.hasThemeIcon(btn._display.value) ? Quickshell.iconPath(btn._display.value) : Tokens.fallbackIcon)
                        : ""
                    fillMode: Image.PreserveAspectFit
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: btn.modelData.invoke()
                }
            }
        }
    }
}
