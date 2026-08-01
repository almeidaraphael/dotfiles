import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import Qt.labs.platform as Labs
import "../../.."
import "../../shared"

    // ================= Power tab ============================================
    // Session/power actions, extracted out of the System tab — Reboot/
    // Shutdown were the shell's only destructive action, worth a tab of
    // their own rather than living inside a read-only system-info/health
    // surface (see SessionActionCell above, shared with this tab).
Item {
        id: pwrRoot

        implicitHeight: sessionGrid.implicitHeight + Tokens.spaceXl * 2

        readonly property var sessionActions: [
            { label: "Lock",     icon: "󰍁", cmd: "loginctl lock-session", danger: false },
            { label: "Logout",   icon: "󰗼", cmd: "hyprctl dispatch 'hl.dsp.exit()'", danger: false },
            { label: "Reboot",   icon: "󰜉", cmd: "reboot",                danger: true  },
            { label: "Shutdown", icon: "󰐥", cmd: "shutdown now",         danger: true  }
        ]
        property string _armedSessionCmd: ""
        Timer { id: armResetTimer; interval: 3000; onTriggered: pwrRoot._armedSessionCmd = "" }

        function _sessionTint(item) {
            if (!item.danger) return ThemeManager.active.text
            if (item.cmd === pwrRoot._armedSessionCmd) return ThemeManager.active.error
            return item.label === "Shutdown" ? ThemeManager.active.error : ThemeManager.active.warning
        }

        // detached: a session action must survive the shell it is about to take
        // down (logout kills Hyprland, and Quickshell with it) — see
        // ProcessRunner._detachedScript.
        function _runSession(cmd, label) {
            ProcessRunner.run(["bash", "-c", cmd], {
                appName: "Session",
                onFailureSummary: "Couldn't " + label.toLowerCase(),
                detached: true
            })
        }

        // Reversible actions fire immediately; destructive ones arm on the
        // first click/Enter (label flips to "Confirm?", tint escalates to
        // error) and only run once the same tile is activated again within
        // armResetTimer's window — a stray Enter or misclick can no longer
        // reboot or kill the session outright.
        function _activateSession(item) {
            if (!item.danger) {
                pwrRoot._runSession(item.cmd, item.label)
                PanelManager.close()
                return
            }
            if (pwrRoot._armedSessionCmd === item.cmd) {
                armResetTimer.stop()
                pwrRoot._armedSessionCmd = ""
                pwrRoot._runSession(item.cmd, item.label)
                PanelManager.close()
            } else {
                pwrRoot._armedSessionCmd = item.cmd
                armResetTimer.restart()
            }
        }

        // 2x2 grid — reversible pair (Lock/Logout) on top, destructive pair
        // (Reboot/Shutdown) below, split by ONE horizontal divider. That
        // split is the only real category boundary here; a matching
        // vertical divider between Lock|Logout or Reboot|Shutdown would cut
        // between two tiles of the *same* severity for no reason — a cross
        // for symmetry's own sake, not structure. See PowerTabBody's
        // critique discussion: functional dividers only, not decorative
        // ones (matches SystemTabBody's own no-decoration convention).
        ColumnLayout {
            id: sessionGrid
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Tokens.spaceXl }
            spacing: Tokens.spaceLg

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Tokens.space2xl
                Repeater {
                    model: pwrRoot.sessionActions.slice(0, 2)
                    delegate: SessionActionCell { host: pwrRoot }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                Layout.leftMargin: Tokens.spaceLg
                Layout.rightMargin: Tokens.spaceLg
                color: ThemeManager.active.border
                opacity: 0.4
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Tokens.space2xl
                Repeater {
                    model: pwrRoot.sessionActions.slice(2, 4)
                    delegate: SessionActionCell { host: pwrRoot }
                }
            }
        }

    component SessionActionCell: Item {
        id: cell
        required property var modelData
        // Named "host", not "sysRoot" — a required property that shares
        // its name with the outer id it's bound to (`SessionActionCell {
        // sysRoot: sysRoot }`) resolves the RHS against the new object's
        // own (still-unset) property first, not the outer scope, and
        // silently binds to itself, staying undefined.
        required property var host

        // Fixed square footprint, not content-sized — PowerTabBody's 2x2
        // grid wants 4 uniform tiles regardless of label length ("Confirm?"
        // vs "Lock"), and a bigger fixed hit-box is the actual "make it
        // bigger" lever: the type scale tops out at text4xl (24px), so
        // growing the glyph alone hits a ceiling fast. Growing the tile is
        // where the size read as bigger and cool actually comes from.
        width: 96
        height: 96

        readonly property bool armed: cell.host._armedSessionCmd === cell.modelData.cmd

        // Rest / hover / pressed / armed — matches GlassButton's state
        // contract instead of sitting inert until clicked. Armed gets its
        // own (bigger) scale bump, not just a color change — this is the
        // shell's only destructive action, and armed is the one moment
        // worth a size call instead of flat emphasis on all 4 tiles alike.
        transformOrigin: Item.Center
        scale: cellMouse.pressed ? 0.98 : (cell.armed ? 1.08 : 1)
        Behavior on scale {
            enabled: !ConfigService.reduceMotion
            NumberAnimation { duration: Tokens.durationFast; easing.type: Tokens.easeOut }
        }

        // Hover tint — same treatment as GlassButton's inactive-hover
        // state, so this reads as clickable before the click like every
        // other icon control in the shell.
        Rectangle {
            anchors.fill: parent
            radius: Tokens.radiusMd
            color: Qt.rgba(1, 1, 1, 0.10)
            opacity: cellMouse.containsMouse ? 1 : 0
            Behavior on opacity { enabled: !ConfigService.reduceMotion; NumberAnimation { duration: Tokens.durationFast } }
        }

        ColumnLayout {
            id: cellCol
            anchors.centerIn: parent
            spacing: Tokens.spaceSm
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: cell.modelData.icon
                font.family: ThemeManager.active.fontMono
                font.bold: true
                font.pixelSize: Tokens.text4xl
                color: cell.host._sessionTint(cell.modelData)
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: cell.armed ? "Confirm?" : cell.modelData.label
                font.family: ThemeManager.active.fontUi
                font.bold: cell.armed
                font.pixelSize: Tokens.textSm
                font.capitalization: Font.AllUppercase
                color: cell.host._sessionTint(cell.modelData)
            }
        }

        // Focus ring — this row replaces a panel that had full keyboard
        // nav (Return/Space per tile); kept here since it's still the
        // only destructive action in the shell.
        Rectangle {
            anchors.fill: parent
            radius: Tokens.radiusMd
            color: "transparent"
            border.width: cell.activeFocus ? 1 : 0
            border.color: ThemeManager.active.accent
        }

        activeFocusOnTab: true
        Keys.onReturnPressed: cell.host._activateSession(cell.modelData)
        Keys.onSpacePressed:  cell.host._activateSession(cell.modelData)

        MouseArea {
            id: cellMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cell.host._activateSession(cell.modelData)
        }
    }


    }
