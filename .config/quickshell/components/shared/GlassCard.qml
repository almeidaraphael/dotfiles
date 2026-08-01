import QtQuick
import "../.."

Rectangle {
    id: root

    radius: Tokens.radiusLg

    color: ThemeManager.active.blur
        ? Qt.rgba(ThemeManager.active.base.r,
                  ThemeManager.active.base.g,
                  ThemeManager.active.base.b, 0.30 * ThemeManager.active.opacity)
        : Qt.rgba(ThemeManager.active.base.r,
                  ThemeManager.active.base.g,
                  ThemeManager.active.base.b, ThemeManager.active.opacity)

    border.color: ThemeManager.active.blur
        ? Qt.rgba(1, 1, 1, 0.22)
        : Qt.rgba(ThemeManager.active.border.r,
                  ThemeManager.active.border.g,
                  ThemeManager.active.border.b, 0.9)
    border.width: 1

    Rectangle {
        visible: ThemeManager.active.blur
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.margins: 1
        height: parent.height * 0.30
        radius: parent.radius
        z: Tokens.zOverlay
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.12) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}
