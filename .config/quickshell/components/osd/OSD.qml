import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../.."
import "../shared"

PanelWindow {
    id: root

    visible: OsdService.visible
    screen: PanelManager.activeScreen

    anchors {
        bottom: true
    }

    margins.bottom: Tokens.space4xl
    implicitWidth: 260
    implicitHeight: 56
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    GlassPanel {
        anchors.fill: parent
        opacity: OsdService.visible ? 1.0 : 0.0
        Behavior on opacity { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationNormal } }

        RowLayout {
            z: Tokens.zModal
            anchors { fill: parent; margins: Tokens.spaceLg }
            spacing: Tokens.spaceMd

            Text {
                text: OsdService.icon
                font.family: ThemeManager.active.fontMono
                font.pixelSize: Tokens.text4xl
                color: OsdService.muted ? ThemeManager.active.error : ThemeManager.active.accent
            }

            Rectangle {
                Layout.fillWidth: true
                height: 6
                radius: 3
                color: ThemeManager.active.overlay

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: OsdService.muted
                           ? ThemeManager.active.error
                           : ThemeManager.active.accent
                    transform: Scale {
                        origin.x: 0
                        xScale: OsdService.value
                        Behavior on xScale { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationInstant } }
                    }
                }
            }
        }
    }
}
