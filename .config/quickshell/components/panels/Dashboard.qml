import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import Qt.labs.platform as Labs
import "../.."
import "../shared"
import "dashboard"

// Was a standalone PanelWindow with its own slide-in animation; now hosted
// as plain content inside TopBar's shared morph window (components/topbar/
// TopBar.qml) — geometry, visibility, and open/close crossfade are the
// host's job (host binds `screen` and drives `visible`/`opacity` directly).
//
// Tab bodies live in components/panels/dashboard/*.qml (one file per tab),
// imported via `import "dashboard"` below. This is Attempt 2 at splitting
// this file — Attempt 1 (components/tabs/*.qml, ~2026-07) hit a confirmed
// Quickshell 0.3.0 qmlscanner bug: cross-directory type resolution for a
// directory of multiple plain (non-singleton) component files drops a
// random subset of its types on a cold scan, when that directory is only
// reachable via a nested relative import and has no other consumer keeping
// its resolution "warm" (confirmed via repeated test restarts). This file
// was inlined back into one blob as the fix at the time.
//
// This split avoids the same failure by giving components/panels/dashboard/
// an explicit qmldir — deterministic declared resolution instead of the
// scanner's implicit (and buggy) directory-contents guess. See
// docs/superpowers/specs/2026-08-01-dashboard-split-design.md for the full
// rationale and docs/superpowers/plans/2026-08-01-dashboard-split.md for
// how the migration was verified (5x cold-reload soak test). See
// .ui-craft/spec.md for each tab's actual design rationale — none of that
// changed here, only where the code lives.
Item {
    id: root

    property var screen: null

    readonly property real screenW: root.screen ? root.screen.width  : 1920
    readonly property real screenH: root.screen ? root.screen.height : 1080

    // Fixed, screen-size-independent — was `screenW * 0.82` / `screenH * 0.85`,
    // which made the panel balloon to ~70% of screen area (2099x1224 on a
    // 2560x1440 display) and grow further on bigger monitors. A glance panel's
    // content (calendar grid, settings rows, metric bars) doesn't need more
    // room on a bigger screen — every reference this shell cites (Caelestia,
    // DankMaterialShell, macOS/Windows utility panels) uses a fixed width.
    // 680 is the smallest width that keeps Settings' rail+icon+label+
    // description+control row from crowding the GlassComboBox (tightest
    // per-tab constraint measured across all 5 tabs) — stays fixed across
    // tabs so switching tabs never reflows horizontally.
    implicitWidth: 680

    // Height is dynamic per active tab (host TopBar.qml already animates
    // width/height smoothly on a local Rectangle, not the real Wayland
    // surface, so per-tab resizing is cheap — see TopBar.qml's `shape`).
    // All 5 tabs report their true content height so the panel hugs each
    // tab's actual content instead of padding out to match the densest one.
    readonly property real chromeHeight: Tokens.spaceXl * 2 + tabRow.implicitHeight + Tokens.spaceMd * 2 + chromeDivider.height
    // Unreachable fallback now that all 5 tabNames are handled explicitly
    // below — kept as a defensive default rather than deleted outright.
    readonly property real denseTabHeight: 547
    readonly property real currentTabBodyHeight: {
        if (PanelManager.activeTab === "overview") return overviewBody.implicitHeight
        if (PanelManager.activeTab === "media") return mediaBody.implicitHeight
        if (PanelManager.activeTab === "theme") return themeBody.implicitHeight
        if (PanelManager.activeTab === "system") return systemBody.implicitHeight
        if (PanelManager.activeTab === "power") return powerBody.implicitHeight
        // Settings reports its own implicit height (rail's natural height vs
        // the active category's content, whichever is taller) instead of
        // sharing a fixed dense canvas — its categories range from 1 row
        // (Display) to 2 rows (Audio/Weather/General), so a shared fixed
        // height either cramped the tall ones or left a dead void under the
        // short ones.
        if (PanelManager.activeTab === "settings") return settingsBody.implicitHeight
        return denseTabHeight
    }
    // Deliberately instant, no local Behavior — this feeds dashboardContent.
    // implicitHeight in TopBar.qml, which is `shape`'s own Behavior's
    // *target*. A Behavior here would mean shape's Behavior retargets every
    // frame of ITS OWN animation (chained Behaviors fighting: QML retriggers
    // a Behavior's transition on every change to its bound value, so a
    // target that's itself easing never lets the outer animation finish
    // cleanly — it perpetually chases a receding value instead of running
    // one 320ms curve). shape's Behavior (TopBar.qml) is the single animator
    // for this height; this stays a plain instant value.
    implicitHeight: chromeHeight + currentTabBodyHeight

    // This Item's ACTUAL rendered height — deliberately a SEPARATE property
    // from implicitHeight above, not chained to it. shape (TopBar.qml)
    // reads implicitHeight (instant) as its Behavior's target; this instead
    // watches that same instant value with its OWN independent Behavior.
    // Two independent Behaviors sourced from the same step-function value,
    // with matching duration/easing, trace mathematically identical curves
    // (same start, same target, same timing — there's nothing for them to
    // diverge on), so shape.height(t) and this.height(t) stay equal at every
    // instant during a tab switch. That's what makes anchors.centerIn safe
    // in TopBar.qml: (shape.height(t) - dashboardContent.height(t)) / 2 is
    // always 0, so content never re-centers mid-transition. During an
    // open/close (activeTab unchanged), implicitHeight never changes, so
    // this Behavior never fires and the original center-reveal is untouched.
    property real renderedHeight: implicitHeight
    Behavior on renderedHeight {
        enabled: !ConfigService.reduceMotion
        NumberAnimation { duration: Tokens.durationSlow; easing.type: Tokens.easeInOut }
    }
    height: renderedHeight

    readonly property var tabNames: ["overview", "media", "theme", "system", "power", "settings"]
    readonly property var tabLabels: { "overview": "Overview", "media": "Media", "theme": "Theme", "system": "System", "power": "Power", "settings": "Settings" }
    // Settings reuses its own "General" category glyph (see SettingsTabBody
    // categories below) — same concept, same codepoint, guaranteed to render
    // since it's already proven elsewhere in this file. Power reuses
    // Shutdown's own glyph — same reasoning.
    readonly property var tabIcons: { "overview": "󰃭", "media": "󰐊", "theme": "󰸌", "system": "󰍛", "power": "󰐥", "settings": "󰒓" }

    onVisibleChanged: {
        if (visible) glassPanel.forceActiveFocus()
    }

    // -------------------------------------------------------------------

    // Was its own GlassPanel; the host (TopBar.qml) now provides the one
    // shared glass surface (border/specular) for both compact and open
    // states — a second nested GlassPanel here was double-stacking and
    // muddying the border definition.
    Item {
        id: glassPanel
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: PanelManager.close()
        Keys.onPressed: function(event) {
            var n = parseInt(event.text)
            if (n >= 1 && n <= root.tabNames.length) {
                PanelManager.activeTab = root.tabNames[n - 1]
                event.accepted = true
            }
        }

        ColumnLayout {
            anchors { fill: parent; margins: Tokens.spaceXl }
            spacing: Tokens.spaceMd

            RowLayout {
                id: tabRow
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: root.tabNames
                    delegate: Item {
                        id: tabItem
                        required property string modelData
                        required property int index

                        readonly property bool active: PanelManager.activeTab === modelData
                        readonly property bool isFirst: index === 0

                        Layout.preferredWidth: tabContent.implicitWidth + Tokens.spaceLg * 2
                        Layout.preferredHeight: 60
                        activeFocusOnTab: true

                        // Seam from the previous tab — first tab gets none, so
                        // the strip doesn't open with a stray leading hairline.
                        VDivider {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            visible: !tabItem.isFirst
                        }

                        // Flat, not rounded — a rounded hover chip inside a strip
                        // of straight hairline dividers left a notch at the top
                        // corners where the divider met the pill's curve. Square
                        // hover matches the strip's own geometry instead of
                        // fighting it.
                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: tabItem.isFirst ? 0 : 1
                            radius: 0
                            color: Qt.rgba(1, 1, 1, (tabMouse.containsMouse && !tabItem.active) ? 0.08 : 0)
                            Behavior on color { enabled: !ConfigService.reduceMotion; ColorAnimation { duration: Tokens.durationFast } }
                        }

                        // Anchored to top with a fixed margin (not centered) so
                        // there's guaranteed clearance to the active-tab underline
                        // below — centering let the label's baseline sit almost
                        // flush against the accent line.
                        ColumnLayout {
                            id: tabContent
                            anchors { top: parent.top; topMargin: Tokens.spaceSm; horizontalCenter: parent.horizontalCenter }
                            spacing: Tokens.spaceXs

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.tabIcons[tabItem.modelData]
                                font.family: ThemeManager.active.fontMono
                                font.pixelSize: Tokens.text2xl
                                color: tabItem.active ? ThemeManager.active.accent : ThemeManager.active.subtext
                                Behavior on color { enabled: !ConfigService.reduceMotion; ColorAnimation { duration: Tokens.durationFast } }
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.tabLabels[tabItem.modelData]
                                font.family: ThemeManager.active.fontUi
                                font.pixelSize: Tokens.textSm
                                color: tabItem.active ? ThemeManager.active.text : ThemeManager.active.subtext
                                Behavior on color { enabled: !ConfigService.reduceMotion; ColorAnimation { duration: Tokens.durationFast } }
                            }
                        }

                        // Single accent placement for the whole strip — see
                        // VDivider comment above for why the seams stay neutral.
                        // Inset from both edges so it reads as its own mark,
                        // not a bar that runs edge-to-edge into the dividers.
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: Tokens.spaceSm; rightMargin: Tokens.spaceSm }
                            height: 2
                            radius: 1
                            color: ThemeManager.active.accent
                            visible: tabItem.active
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PanelManager.activeTab = tabItem.modelData
                        }
                        Keys.onReturnPressed: PanelManager.activeTab = tabItem.modelData
                        Keys.onSpacePressed:  PanelManager.activeTab = tabItem.modelData
                    }
                }

                VDivider {}

                Item { Layout.fillWidth: true }

                // Flat icon button, not a GlassButton pill — the round glass
                // chip read as a leftover heavy element once the tabs went
                // flat/minimal. Same hover language as the tabs (square,
                // 8% white), just its own hit target. AlignVCenter matters
                // here: the tab strip grew taller (54px) than this button's
                // fixed size, so without it this sat pinned to the row's top
                // instead of centered against the tabs.
                Item {
                    id: closeBtn
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    Layout.alignment: Qt.AlignVCenter
                    activeFocusOnTab: true

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(1, 1, 1, (closeMouse.containsMouse || closeBtn.activeFocus) ? 0.08 : 0)
                        Behavior on color { enabled: !ConfigService.reduceMotion; ColorAnimation { duration: Tokens.durationFast } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "󰅖"
                        font.family: ThemeManager.active.fontMono
                        font.pixelSize: Tokens.textMd
                        color: ThemeManager.active.text
                    }
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PanelManager.close()
                    }
                    Keys.onReturnPressed: PanelManager.close()
                    Keys.onSpacePressed:  PanelManager.close()
                }
            }

            Divider { id: chromeDivider }

            Item {
                id: tabStack
                Layout.fillWidth: true
                // Not fillHeight — its own independent Behavior watching the
                // same instant root.currentTabBodyHeight that root.
                // renderedHeight watches (see that property's comment).
                // Since chromeHeight (tabRow + divider, above this in the
                // ColumnLayout) is constant, root.renderedHeight(t) always
                // equals chromeHeight + this.Layout.preferredHeight(t)
                // exactly — the ColumnLayout's available space and this
                // item's reported preferred size never disagree mid-
                // transition. NOT bound to root.renderedHeight directly —
                // that would chain this Behavior's target to another
                // Behavior's output (the exact bug that broke everything
                // last round); watching the same instant source independently
                // keeps both curves identical without either depending on
                // the other's live value.
                Layout.preferredHeight: root.currentTabBodyHeight
                Behavior on Layout.preferredHeight {
                    enabled: !ConfigService.reduceMotion
                    NumberAnimation { duration: Tokens.durationSlow; easing.type: Tokens.easeInOut }
                }

                // Was a StackLayout keyed on currentIndex — that (a) sizes
                // every child to its own cell (the animated container height),
                // so Overview/Media/Theme's fillHeight rows visibly stretched
                // out of shape on every transition frame instead of holding
                // their own true content height, and (b) swaps visibility
                // instantly with no transition, so the incoming tab popped in
                // fully-formed the moment it became current. Plain opacity-
                // crossfade children fix both: Overview/Media/Theme sit at
                // their own real implicitHeight (top-anchored, never
                // stretched by the container), and switching tabs fades the
                // old body out while the new one fades in.
                OverviewTabBody {
                    id: overviewBody
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: implicitHeight
                    opacity: PanelManager.activeTab === "overview" ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationFast } }
                }
                MediaTabBody {
                    id: mediaBody
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: implicitHeight
                    opacity: PanelManager.activeTab === "media" ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationFast } }
                }
                ThemeTabBody {
                    id: themeBody
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: implicitHeight
                    opacity: PanelManager.activeTab === "theme" ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationFast } }
                }
                SystemTabBody {
                    id: systemBody
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: implicitHeight
                    opacity: PanelManager.activeTab === "system" ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationFast } }
                }
                PowerTabBody {
                    id: powerBody
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: implicitHeight
                    opacity: PanelManager.activeTab === "power" ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationFast } }
                }
                SettingsTabBody {
                    id: settingsBody
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: implicitHeight
                    opacity: PanelManager.activeTab === "settings" ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationFast } }
                }
            }
        }
    }
}
