import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../.."
import "notificationLogic.js" as NotifLogic

QtObject {
    id: toastRoot

    property var _model: ListModel { id: toastModel }

    function closeToast(id) {
        for (var i = 0; i < toastModel.count; i++) {
            if (toastModel.get(i).modelData.id === id) {
                toastModel.remove(i)
                break
            }
        }
    }

    property var _window: PanelWindow {
        id: toastWindow
        screen: PanelManager.activeScreen
        anchors.top: true
        anchors.right: true
        margins.top: Tokens.spaceLg
        margins.right: Tokens.spaceLg
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        implicitWidth: 360
        implicitHeight: toastModel.count > 0 ? toastColumn.implicitHeight : 1

        Column {
            id: toastColumn
            anchors { top: parent.top; right: parent.right }
            spacing: Tokens.spaceSm
            width: 340

            Repeater {
                model: toastModel
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    required property int index

                    width: 340
                    height: content.implicitHeight + Tokens.space2xl
                    radius: Tokens.radiusLg

                    readonly property var _split: NotifLogic.splitActions(modelData.actions || [])

                    readonly property color _accent: modelData.urgency === 2
                        ? ThemeManager.active.error
                        : modelData.urgency === 0
                            ? ThemeManager.active.subtext
                            : ThemeManager.active.accent

                    readonly property color _body: ThemeManager.active.blur
                        ? modelData.urgency === 2
                            ? Qt.rgba(
                                ThemeManager.active.error.r * 0.15 + ThemeManager.active.base.r * 0.85,
                                ThemeManager.active.error.g * 0.15 + ThemeManager.active.base.g * 0.85,
                                ThemeManager.active.error.b * 0.15 + ThemeManager.active.base.b * 0.85,
                                0.30 * ThemeManager.active.opacity)
                            : Qt.rgba(ThemeManager.active.base.r,
                                      ThemeManager.active.base.g,
                                      ThemeManager.active.base.b, 0.25 * ThemeManager.active.opacity)
                        : Qt.rgba(ThemeManager.active.overlay.r,
                                  ThemeManager.active.overlay.g,
                                  ThemeManager.active.overlay.b, ThemeManager.active.opacity)

                    // Sharp gradient: accent strip on left, glass body on right
                    readonly property real _sf: 4.0 / width
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0;             color: card._accent }
                        GradientStop { position: card._sf;        color: card._accent }
                        GradientStop { position: card._sf + 0.005; color: card._body }
                        GradientStop { position: 1.0;             color: card._body }
                    }

                    border.color: ThemeManager.active.blur
                        ? Qt.rgba(1, 1, 1, 0.22)
                        : Qt.rgba(ThemeManager.active.border.r, ThemeManager.active.border.g, ThemeManager.active.border.b, 0.9)
                    border.width: 1

                    Rectangle {
                        visible: ThemeManager.active.blur
                        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
                        height: parent.height * 0.35
                        radius: parent.radius
                        z: Tokens.zOverlay
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.14) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    NotificationContent {
                        id: content
                        z: Tokens.zModal
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Tokens.spaceMd }
                        notification: modelData
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (card._split.defaultAction) card._split.defaultAction.invoke()
                            toastRoot.closeToast(modelData.id)
                        }
                    }

                    Timer {
                        interval: ConfigService.notificationTimeout || 3000
                        running: NotifLogic.shouldAutoDismiss(modelData.urgency, modelData.expireTimeout)
                        onTriggered: toastRoot.closeToast(modelData.id)
                    }
                }
            }
        }
    }

    property var _conn: Connections {
        target: NotificationService
        function onNotificationAdded(n) {
            if (!NotificationService.doNotDisturb)
                toastModel.append({ modelData: n })
        }
        function onNotificationClosed(id) {
            toastRoot.closeToast(id)
        }
    }
}
