import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../.."

Row {
    id: root
    spacing: Tokens.spaceXs

    // Which monitor's workspaces to show — each bar only shows its own
    // monitor's workspaces, not every workspace across the whole session.
    property var screen

    // Cap on visible per-workspace app icons before collapsing into a
    // "+N" overflow chip — keeps a workspace with many windows from
    // ballooning the pill's width unboundedly.
    readonly property int maxIcons: 3

    // Icon theme lookup fails silently on unmatched wm classes, so try the
    // class name first, then the app's real desktop-entry icon before
    // giving up and letting the delegate fall back to a drawn placeholder.
    function resolveIcon(wmClass) {
        if (!wmClass)
            return ""
        if (Quickshell.hasThemeIcon(wmClass))
            return wmClass
        var entry = DesktopEntries.heuristicLookup(wmClass)
        if (entry && entry.icon && Quickshell.hasThemeIcon(entry.icon))
            return entry.icon
        return ""
    }

    Component {
        id: workspaceDelegate

        Rectangle {
            id: workspaceCard

            property int wsId: modelData.id
            property bool isSpecial: wsId < 0
            property bool focused: wsId === HyprlandService.focusedWorkspace?.id
            property var clients: HyprlandService.clientsByWorkspace[wsId] ?? []

            // Sized to its own content (was parent.width in the vertical
            // sidebar layout) — a horizontal Row can't share one fixed width
            // across items the way a fixed-width vertical Column pill could.
            // Floored to 28 (the right cluster's fixed button size) so an
            // empty/numeral-only workspace reads as a chip the same footprint
            // as a VolumeControl/KeepAwakeButton, not a thin text-hugging oval.
            implicitWidth: Math.max(cardContent.implicitWidth + Tokens.spaceMd, 28)
            implicitHeight: Math.max(cardContent.implicitHeight + Tokens.spaceSm, 28)
            // Full capsule (was flat radiusMd) — matches the pill's own
            // squircle-family shape instead of sitting square-cornered
            // inside a smooth capsule.
            radius: height / 2
            // Unfocused pills get the same chip treatment as the icon
            // buttons on the bar's other side (overlay fill + hairline
            // border) instead of bare text — matches density/texture
            // across both clusters rather than just matching width.
            color: focused ? ThemeManager.active.accent : ThemeManager.active.overlay
            border.color: focused ? "transparent" : ThemeManager.active.border
            border.width: focused ? 0 : 1

            MouseArea {
                anchors.fill: parent
                onClicked: HyprlandService.switchWorkspace(wsId)
                cursorShape: Qt.PointingHandCursor
            }

            Row {
                id: cardContent
                anchors.centerIn: parent
                spacing: Tokens.spaceXs

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: workspaceCard.isSpecial ? "" : workspaceCard.wsId
                    font.family: ThemeManager.active.fontMono
                    font.pixelSize: Tokens.textSm
                    color: workspaceCard.focused
                           ? ThemeManager.active.base
                           : ThemeManager.active.subtext
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spaceXs

                    Repeater {
                        model: workspaceCard.clients.slice(0, root.maxIcons)

                        delegate: Item {
                            width: 14
                            height: 14

                            property string resolvedIcon: root.resolveIcon(modelData)

                            Image {
                                anchors.fill: parent
                                visible: parent.resolvedIcon !== ""
                                source: parent.resolvedIcon !== "" ? Quickshell.iconPath(parent.resolvedIcon) : ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: parent.resolvedIcon === ""
                                radius: Tokens.radiusSm
                                color: ThemeManager.active.overlay
                                border.color: ThemeManager.active.border
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData ? modelData.charAt(0).toUpperCase() : "?"
                                    font.family: ThemeManager.active.fontMono
                                    font.pixelSize: Tokens.text2xs
                                    color: ThemeManager.active.subtext
                                }
                            }
                        }
                    }

                    // Overflow chip — past maxIcons, collapse the rest into
                    // a count instead of letting the pill grow unbounded.
                    Rectangle {
                        width: 14
                        height: 14
                        visible: workspaceCard.clients.length > root.maxIcons
                        radius: Tokens.radiusSm
                        color: ThemeManager.active.overlay
                        border.color: ThemeManager.active.border
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "+" + (workspaceCard.clients.length - root.maxIcons)
                            font.family: ThemeManager.active.fontMono
                            font.pixelSize: Tokens.text2xs
                            color: ThemeManager.active.subtext
                        }
                    }
                }
            }
        }
    }

    // Only this bar's own monitor's workspaces — without this filter every
    // bar renders every workspace on every monitor identically, doubling
    // (or worse) the pill's content for no reason.
    function onThisScreen(w) {
        return root.screen && w.monitor && w.monitor.name === root.screen.name
    }

    // Union of this monitor's statically-bound workspace ids (hyprland.conf
    // `workspace = N, monitor:X` rules — present even when empty/never
    // visited) and any live workspace currently on this monitor (covers
    // dynamically-created workspaces with no rule). Deduped, sorted.
    property var normalWorkspaces: {
        var name = root.screen ? root.screen.name : null
        var boundIds = []
        if (name) {
            var bindings = HyprlandService.workspaceBindings
            for (var key in bindings) {
                if (bindings[key] === name)
                    boundIds.push(parseInt(key))
            }
        }
        var liveIds = Hyprland.workspaces.values
            .filter(w => w.id >= 0 && root.onThisScreen(w))
            .map(w => w.id)
        var ids = [...new Set(boundIds.concat(liveIds))].sort((a, b) => a - b)
        return ids.map(id => ({ id: id }))
    }

    // Ordinary workspaces first, special (scratchpad, id < 0) ones after.
    Repeater {
        model: root.normalWorkspaces
        delegate: workspaceDelegate
    }

    Repeater {
        model: Hyprland.workspaces.values.filter(w => w.id < 0 && root.onThisScreen(w))
        delegate: workspaceDelegate
    }
}
