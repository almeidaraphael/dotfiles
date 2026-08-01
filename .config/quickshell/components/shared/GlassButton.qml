import QtQuick
import "../.."

Rectangle {
    id: root

    property bool active: false
    property bool hovered: false
    property real frameRadius: Tokens.radiusMd

    radius: frameRadius

    // Gradient handles specular highlight AND base fill — clips to pill natively.
    // Child Rectangle speculars would overflow the pill corners (effective radius < parent radius).
    gradient: ThemeManager.active.blur ? _grad : null

    // Non-blur state stays fully solid, unscaled by opacity — interactive controls
    // keep full-opacity brand colors regardless of theme translucency.
    color: ThemeManager.active.blur
        ? "transparent"
        : (active ? ThemeManager.active.accent : ThemeManager.active.overlay)

    border.color: active
        ? Qt.rgba(ThemeManager.active.accent.r, ThemeManager.active.accent.g, ThemeManager.active.accent.b, 0.85)
        : (ThemeManager.active.blur
            ? Qt.rgba(1, 1, 1, 0.28)
            : Qt.rgba(ThemeManager.active.border.r,
                      ThemeManager.active.border.g,
                      ThemeManager.active.border.b, 0.9))
    border.width: active ? 1.5 : 1

    Gradient {
        id: _grad
        GradientStop {
            position: 0.0
            color: Qt.rgba(1, 1, 1, (root.active ? 0.20 : 0.13) * ThemeManager.active.opacity)
        }
        GradientStop {
            position: 0.32
            color: Qt.rgba(ThemeManager.active.base.r,
                           ThemeManager.active.base.g,
                           ThemeManager.active.base.b,
                           (root.active ? 0.32 : 0.18) * ThemeManager.active.opacity)
        }
        GradientStop {
            position: 1.0
            color: Qt.rgba(ThemeManager.active.base.r,
                           ThemeManager.active.base.g,
                           ThemeManager.active.base.b,
                           (root.active ? 0.22 : 0.12) * ThemeManager.active.opacity)
        }
    }

    // Accent tint — same dimensions as parent so effective radius matches exactly.
    Rectangle {
        visible: ThemeManager.active.blur && root.active
        anchors.fill: parent
        radius: parent.radius
        color: Qt.rgba(ThemeManager.active.accent.r,
                       ThemeManager.active.accent.g,
                       ThemeManager.active.accent.b, 0.38)
    }

    // Hover feedback — only for the inactive state; `active` already reads
    // as "on" via the accent tint above, so stacking hover on top of that
    // would just be noise. This is what gives icon-only buttons an affordance
    // before the click, instead of looking inert until pressed.
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Qt.rgba(1, 1, 1, 0.10)
        opacity: (root.hovered && !root.active) ? 1 : 0
        Behavior on opacity { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationFast } }
    }
}
