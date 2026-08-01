import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../.."
import "../shared"

// First standalone panel anchored right instead of top (see
// .ui-craft/spec.md → Surface: Notification Center). Full-height right
// rail, not a compact top-anchored popup like the panels it replaces.
PanelWindow {
    id: root

    screen: PanelManager.activeScreen
    focusable: true
    anchors { top: true; bottom: true; right: true }
    margins.top: Tokens.spaceLg
    margins.bottom: Tokens.spaceLg
    implicitWidth: 380
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    property bool shouldBeActive: PanelManager.activePanel === "notificationCenter"
    property real offsetScale: shouldBeActive ? 0 : 1
    visible: shouldBeActive || offsetScale < 0.99

    margins.right: Tokens.spaceLg - (root.implicitWidth + Tokens.spaceLg) * root.offsetScale

    Behavior on offsetScale {
        enabled: !ConfigService.reduceMotion
        NumberAnimation { duration: Tokens.durationNormal; easing.type: Tokens.easeOut }
    }

    onVisibleChanged: {
        if (visible) {
            list.forceActiveFocus()
            NotificationService.markAllSeen()
        }
    }

    GlassPanel {
        anchors.fill: parent
        opacity: 1 - root.offsetScale
        focus: true
        Keys.onEscapePressed: PanelManager.close()

        ColumnLayout {
            anchors { fill: parent; margins: Tokens.spaceLg }
            spacing: Tokens.spaceSm

            PanelHeader {
                title: "Notifications"
                onCloseRequested: PanelManager.close()
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spaceSm

                DndButton {}

                Text {
                    visible: NotificationService.doNotDisturb
                    text: "DND active — muted"
                    font.family: ThemeManager.active.fontUi
                    font.pixelSize: Tokens.textXs
                    color: ThemeManager.active.subtext
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: ThemeManager.active.border; opacity: 0.4 }

            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: NotificationService.notifications.length === 0
                text: "No notifications"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: ThemeManager.active.fontUi
                font.pixelSize: Tokens.textMd
                color: ThemeManager.active.subtext
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: NotificationService.notifications.length > 0
                clip: true
                spacing: Tokens.spaceSm
                model: NotificationService.notifications
                focus: true

                delegate: GlassCard {
                    id: item
                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    height: content.implicitHeight + Tokens.space2xl

                    // Unread accent dot, not a colored border (anti-slop:
                    // thick colored left/top borders on cards are a named
                    // violation) — fades once the panel marks it seen.
                    Rectangle {
                        visible: !item.modelData.seen
                        width: 8; height: 8; radius: 4
                        anchors { left: parent.left; top: parent.top; margins: Tokens.spaceSm }
                        color: ThemeManager.active.accent
                        Behavior on opacity { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationFast } }
                    }

                    NotificationContent {
                        id: content
                        anchors { left: parent.left; right: dismissBtn.left; top: parent.top; margins: Tokens.spaceMd }
                        notification: item.modelData
                    }

                    Text {
                        anchors { right: parent.right; top: parent.top; margins: Tokens.spaceSm }
                        text: _relTime(item.modelData.timestamp)
                        font.family: ThemeManager.active.fontMono
                        font.pixelSize: Tokens.textXs
                        color: ThemeManager.active.subtext
                    }

                    Text {
                        id: dismissBtn
                        anchors { right: parent.right; bottom: parent.bottom; margins: Tokens.spaceSm }
                        text: "×"
                        font.pixelSize: Tokens.textLg
                        color: ThemeManager.active.subtext
                        MouseArea {
                            anchors.margins: -8
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotificationService.dismiss(item.modelData.id)
                        }
                    }
                }
            }

            GlassButton {
                Layout.fillWidth: true
                height: 32
                visible: NotificationService.notifications.length > 0
                activeFocusOnTab: true
                Text { anchors.centerIn: parent; text: "Clear all"; font.family: ThemeManager.active.fontUi; font.pixelSize: Tokens.textSm; color: ThemeManager.active.text }
                MouseArea { anchors.fill: parent; onClicked: NotificationService.dismissAll() }
                Keys.onReturnPressed: NotificationService.dismissAll()
                Keys.onSpacePressed:  NotificationService.dismissAll()
            }
        }
    }

    function _relTime(ts) {
        var secs = Math.max(0, (Date.now() - ts.getTime()) / 1000)
        if (secs < 60) return "now"
        if (secs < 3600) return Math.floor(secs / 60) + "m ago"
        if (secs < 86400) return Math.floor(secs / 3600) + "h ago"
        return Math.floor(secs / 86400) + "d ago"
    }
}
