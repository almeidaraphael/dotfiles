pragma Singleton
import QtQuick

// Numbers here are hand-synced with .config/hypr/theme.conf (gaps_in/gaps_out,
// border_size, rounding, animations bezier curves) — no shared runtime between
// Hyprland and Quickshell, so keep both files in mind when changing either.
QtObject {
    // Spacing — 4px base grid, arithmetic to 20 then exponential tail. Cf. hypr
    // theme.conf general{} gaps_in=5, gaps_out=10
    readonly property int spaceXs:  4
    readonly property int spaceSm:  8
    readonly property int spaceMd:  12
    readonly property int spaceLg:  16
    readonly property int spaceXl:  20
    readonly property int space2xl: 24
    readonly property int space3xl: 32
    readonly property int space4xl: 48

    // Type scale — 2px steps 8-24, collapses ad-hoc pixelSize values used
    // across components (11/13/15/9 etc. snapped to nearest step on adoption)
    readonly property int text2xs:  8
    readonly property int textXs:   10
    readonly property int textSm:   12
    readonly property int textMd:   14
    readonly property int textLg:   16
    readonly property int textXl:   18
    readonly property int text2xl:  20
    readonly property int text3xl:  22
    readonly property int text4xl:  24

    // Semantic type roles — alias raw sizes so components reference *why*
    // a size was picked, not just its magnitude. Sizing doesn't vary per
    // Theme.qml (unlike color), so roles live here, not in Theme.qml.
    readonly property int typeDisplay:  text4xl  // hero numbers: Overview's clock, large stat readouts
    readonly property int typeHeadline: text2xl  // card/section titles, panel headers
    readonly property int typeBody:     textSm   // default readable body text
    readonly property int typeLabel:    text2xs  // section labels, chip/badge text

    // Radii. Cf. hypr theme.conf decoration{} rounding=5 (window corners, diverges
    // from radiusLg on purpose — panels are a different chrome layer than windows)
    readonly property int radiusSm:   4   // chips, small badges
    readonly property int radiusMd:   8   // buttons, inputs
    readonly property int radiusLg:   12  // cards, panels (GlassCard default)
    readonly property int radiusXl:   16  // large panels, sidebar
    readonly property int radiusFull: 9999

    // Motion — duration in ms, ~1.6x geometric progression, easing as QML
    // Easing.Type enum values. Cf. hypr theme.conf animations{} — flat cubic
    // here, Hyprland uses a springy overshoot bezier ("spring":
    // 0.155,1.105,0.2,1.031) for windows/border/workspaces
    readonly property int durationInstant: 80
    readonly property int durationFast:    120
    readonly property int durationNormal:  200
    readonly property int durationSlow:    320
    readonly property int durationSlower:  500
    readonly property int easeOut:   Easing.OutCubic
    readonly property int easeIn:    Easing.InCubic
    readonly property int easeInOut: Easing.InOutCubic

    // Quickshell's icon provider never reports a load failure via Image.status
    // (always Ready, silently substitutes its own checkerboard placeholder
    // texture) — callers must pre-check Quickshell.hasThemeIcon(name) before
    // calling Quickshell.iconPath(name) and use this as the substitute instead.
    readonly property url fallbackIcon: "file:///usr/share/pixmaps/archlinux-logo.svg"

    // Z-index — cross-component stacking only (not intra-component paint order)
    readonly property int zBase:     0
    readonly property int zDropdown: 10
    readonly property int zOverlay:  20
    readonly property int zModal:    30
    readonly property int zToast:    40
}
