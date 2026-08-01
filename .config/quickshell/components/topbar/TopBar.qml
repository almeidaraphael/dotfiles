import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../.."
import "../shared"
import "../panels"

PanelWindow {
    id: topBar

    anchors { top: true }
    margins.top: 0
    color: "transparent"

    // Visible gap between the screen edge and the pill/panel — this is what
    // reads as "floating" rather than fused to the monitor edge. Applied to
    // `shape`'s y (not a PanelWindow margin) since the surface itself stays
    // pinned full-screen for the click-through mask trick below.
    // Hardcoded to 8, not a Tokens spacing step — matches Hyprland's
    // `gaps_out` (hypr/theme.conf) exactly, so the gap above the pill and
    // the gap below it (pill-to-tiled-window, which IS gaps_out) read as the
    // same width. Keep these two values in sync if either changes.
    readonly property real topGap: 8

    readonly property bool isActiveScreen: screen !== undefined && screen === PanelManager.activeScreen

    // Only the topbar on the currently-active monitor ever morphs open —
    // other monitors' bars stay compact, matching how Dashboard used to be
    // a single instance that repositioned itself to PanelManager.activeScreen.
    readonly property bool isOpen: isActiveScreen && PanelManager.activePanel === "dashboard"

    focusable: isOpen

    // Reserve the compact strip ALWAYS, open or not — otherwise tiled
    // windows reflow to fill the gap the instant the dashboard opens (since
    // the zone shrank to 0) and jump again on close. `Normal` + a fixed
    // number (never derived from the window's own huge pinned geometry)
    // keeps the reservation constant regardless of isOpen.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: compactHeight + topGap

    // The real Wayland surface is pinned at a fixed, generously-large size —
    // always. It never resizes. Animating a real layer-shell surface's
    // implicit size every frame forces a protocol reconfigure per frame,
    // which is what made the first version of this morph janky. Only
    // `shape`'s local x/y/width/height animate now (pure GPU compositing).
    // `mask` below keeps clicks passing through everywhere except `shape`'s
    // current bounds, so this oversized invisible surface never blocks
    // input to windows underneath it.
    implicitWidth:  screen ? screen.width  : 1920
    implicitHeight: screen ? screen.height : 1080

    mask: Region { item: shape }

    readonly property real sideColumnWidth: Math.max(leftCluster.implicitWidth, rightCluster.implicitWidth)
    // Hairline divider slots separating workspace/clock/icon clusters —
    // each cluster reads as its own module instead of one continuous row,
    // so differing content density between clusters doesn't read as lopsided.
    readonly property real dividerSlot: Tokens.spaceMd
    readonly property real compactWidth:  sideColumnWidth * 2 + centerCluster.implicitWidth + Tokens.space3xl + Tokens.spaceMd + dividerSlot * 2
    // spaceLg padding on top of the 28px buttons lands exactly at a 44px bar —
    // enough breathing room around the content now that the outer gap (8px,
    // matching Hyprland's gaps_out) is thin.
    readonly property real compactHeight: compactRow.implicitHeight + Tokens.spaceLg

    readonly property real targetWidth:  isOpen ? dashboardContent.implicitWidth  : compactWidth
    readonly property real targetHeight: isOpen ? dashboardContent.implicitHeight : compactHeight
    readonly property real targetX: (topBar.width - targetWidth) / 2
    // Same topGap whether compact or open — the dashboard morphs out of the
    // pill in place, so both states anchor to the same y or the panel would
    // jump to the screen edge the instant it opens.
    readonly property real targetY: topBar.topGap

    GlassPanel {
        id: shape
        x: topBar.targetX
        y: topBar.targetY
        width: topBar.targetWidth
        height: topBar.targetHeight
        clip: true
        // Degenerates to a full capsule at the thin compact bar height (radius
        // == height/2 well under the 28px cap); locks to a fixed squircle
        // radius once open — same shape family whether compact or morphed
        // into the dashboard.
        frameRadius: topBar.isOpen ? Tokens.radiusXl : Math.min(height / 2, 28)

        Behavior on x           { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationSlow; easing.type: Tokens.easeInOut } }
        Behavior on y           { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationSlow; easing.type: Tokens.easeInOut } }
        Behavior on width       { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationSlow; easing.type: Tokens.easeInOut } }
        Behavior on height      { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationSlow; easing.type: Tokens.easeInOut } }
        Behavior on frameRadius { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationSlow; easing.type: Tokens.easeInOut } }

        Item {
            id: compactContent
            anchors.fill: parent
            opacity: topBar.isOpen ? 0 : 1
            visible: opacity > 0.01
            Behavior on opacity { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationFast } }

            RowLayout {
                id: compactRow
                anchors { verticalCenter: parent.verticalCenter; horizontalCenter: parent.horizontalCenter }
                // Side clusters are fixed-width (sideColumnWidth), so this
                // inset is pure edge margin, not content compression — only
                // the center clock's fillWidth slack shrinks to make room.
                // spaceLg (8px/side) read as fused-to-the-border; space3xl
                // (16px/side) gives the workspace indicator and right-side
                // buttons real breathing room from the pill edge.
                width: parent.width - Tokens.space3xl
                spacing: 0

                Item {
                    Layout.preferredWidth: topBar.sideColumnWidth
                    // A plain Item's implicitHeight defaults to 0 and doesn't
                    // pick up anchored (non-Layout) children — without this,
                    // RowLayout computes the whole row's height as ~0 and the
                    // window surface clips everything to a sliver.
                    implicitHeight: leftCluster.implicitHeight
                    Layout.fillHeight: true
                    WorkspaceIndicator {
                        id: leftCluster
                        screen: topBar.screen
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    }
                }

                Item {
                    Layout.preferredWidth: topBar.dividerSlot
                    Layout.fillHeight: true
                    Rectangle {
                        anchors.centerIn: parent
                        width: 1
                        height: parent.height * 0.5
                        color: ThemeManager.active.border
                        opacity: 0.5
                    }
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: centerCluster.implicitHeight
                    Layout.fillHeight: true
                    Clock {
                        id: centerCluster
                        anchors.centerIn: parent
                    }
                }

                Item {
                    Layout.preferredWidth: topBar.dividerSlot
                    Layout.fillHeight: true
                    Rectangle {
                        anchors.centerIn: parent
                        width: 1
                        height: parent.height * 0.5
                        color: ThemeManager.active.border
                        opacity: 0.5
                    }
                }

                Item {
                    Layout.preferredWidth: topBar.sideColumnWidth
                    implicitHeight: rightCluster.implicitHeight
                    Layout.fillHeight: true
                    RowLayout {
                        id: rightCluster
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: Tokens.spaceSm

                        VolumeControl { stream: "output" }
                        VolumeControl { stream: "input" }
                        KeepAwakeButton {}
                        LowResourceModeButton {}
                    }
                }
            }
        }

        // Sized to its own natural implicitWidth/implicitHeight (NOT
        // anchors.fill to `shape`) so its bento grid always lays out at one
        // consistent size — `shape`'s clip crops it during the transition
        // instead of forcing the grid to reflow/distort at intermediate
        // animated sizes.
        Dashboard {
            id: dashboardContent
            // centerIn, not top-anchored — this is what gives the open/close
            // morph its symmetric reveal-from-center feel (content clipped
            // by shape's still-small bounds on all sides, unveiling equally
            // top and bottom as shape grows). Safe for tab-switching too:
            // dashboardContent.height is Dashboard's `renderedHeight` (see
            // that property's comment), an independent Behavior watching the
            // same instant value shape's own Behavior targets — both trace
            // identical curves, so this centerIn math never has a stale
            // operand to re-center against mid-transition.
            anchors.centerIn: parent
            screen: topBar.screen
            opacity: topBar.isOpen ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationNormal } }
        }
    }
}
