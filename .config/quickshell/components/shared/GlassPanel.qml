import QtQuick
import "../.."

Rectangle {
    id: root

    property real frameRadius: Tokens.radiusXl

    radius: frameRadius

    color: ThemeManager.active.blur
        ? Qt.rgba(ThemeManager.active.base.r,
                 ThemeManager.active.base.g,
                 ThemeManager.active.base.b, 0.45 * ThemeManager.active.opacity)
        : Qt.rgba(ThemeManager.active.base.r,
                 ThemeManager.active.base.g,
                 ThemeManager.active.base.b, ThemeManager.active.opacity)

    // Accent tint overlay — anchors.fill + radius: parent.radius, so it's
    // exactly the same size and curve as `root` itself. Safe by construction.
    Rectangle {
        visible: ThemeManager.active.blur
        anchors.fill: parent
        radius: parent.radius
        color: Qt.rgba(ThemeManager.active.accent.r,
                       ThemeManager.active.accent.g,
                       ThemeManager.active.accent.b, 0.08)
    }

    border.color: ThemeManager.active.blur
        ? Qt.rgba(1, 1, 1, 0.22)
        : Qt.rgba(ThemeManager.active.border.r, ThemeManager.active.border.g, ThemeManager.active.border.b, 0.9)
    border.width: 1

    // Deliberately no separate specular-highlight / inner-shadow overlay
    // strips here. Those used to be inset partial rectangles (e.g. a left
    // edge strip only 4% of the width, or a top strip 32% of the height)
    // each computing their own corner radius. Any such strip's own radius is
    // necessarily smaller than root's actual corner radius, so it traces a
    // tighter curve nested inside root's true silhouette — visibly
    // diverging from it right where the strip's rounded end meets root's
    // corner (a squared nub or kink poking past the real curve). This isn't
    // fixable by clamping the strip's own radius; the mismatch is inherent
    // to any inset rectangle claiming a smaller radius than its container.
    // The border + fill above already read as "glass" without it.
}
