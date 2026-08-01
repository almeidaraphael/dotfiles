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

    // ================= System tab ===========================================
    // See .ui-craft/spec.md -> Surface: System.
Item {
        id: sysRoot

        // Reports its own content height instead of stretching to fill the
        // legacy fixed dense canvas (see root.denseTabHeight) — matches
        // Overview/Media/Theme/Settings, which all hug their real content.
        // Mattered less before, but decluttering this tab (dropping 4 of 5
        // sparklines, tightening the health grid) shrank its true content
        // height well below 547 — staying pinned to the old fixed height
        // would've just left dead space at the bottom instead of the tighter
        // panel this pass is going for.
        implicitHeight: sysRow.y + sysRow.implicitHeight + Tokens.spaceXl

        property string uptime: ""
        property string osName: ""
        property string wmName: ""
        property string sessionType: ""

        readonly property string username: ConfigService.homeDir.toString().split("/").pop()
        readonly property string avatarSource: "file:///etc/theme-assets/avatar.png?v=" + ConfigService.avatarVersion

        Timer {
            interval: 60000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: {
                var proc = Qt.createQmlObject(
                    'import Quickshell.Io; Process { stdout: StdioCollector { waitForEnd: true } }', sysRoot)
                // Compact form ("11h 50m" not "11 hours, 50 minutes") — the
                // verbose form doesn't fit its stat-cell column without
                // eliding into "11 hours, 50 …", which defeats the point of
                // showing it as a labeled stat next to WM/SESSION.
                proc.command = ["bash", "-c",
                    "uptime -p | sed -E 's/^up //; s/ days?/d/g; s/ hours?/h/g; s/ minutes?/m/g; s/, /  /g'"]
                proc.stdout.streamFinished.connect(function() { sysRoot.uptime = proc.stdout.text.trim(); proc.destroy() })
                proc.running = true
            }
        }

        Component.onCompleted: {
            var proc = Qt.createQmlObject(
                'import Quickshell.Io; Process { stdout: StdioCollector { waitForEnd: true } }', sysRoot)
            proc.command = ["bash", "-c",
                "source /etc/os-release 2>/dev/null; echo \"${PRETTY_NAME:-Unknown}\"; " +
                "if [ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ]; then echo Hyprland; else echo \"${XDG_CURRENT_DESKTOP:-Unknown}\"; fi; " +
                "echo \"${XDG_SESSION_TYPE:-unknown}\""]
            proc.stdout.streamFinished.connect(function() {
                var lines = proc.stdout.text.trim().split("\n")
                sysRoot.osName      = lines[0] || "Unknown"
                sysRoot.wmName      = lines[1] || "Unknown"
                sysRoot.sessionType = lines[2] || "unknown"
                proc.destroy()
            })
            proc.running = true
        }

        function _fmtNet(kbps) {
            if (kbps >= 1024) return (kbps / 1024).toFixed(1) + " MB/s"
            return Math.round(kbps) + " KB/s"
        }

        // Severity is per-metric, not a blanket "any nonzero value is a
        // warning" rule — UPDATES/ORPHANS are routine, expected states even
        // at nonzero counts, while FAILED/CRASHES are actual health signals.
        // Treating a backlog of 28 coredumps the same color as 2 routine
        // orphaned packages hid the metric that actually matters.
        function _healthColor(label, value) {
            if (label === "FAILED")  return value > 0 ? ThemeManager.active.error : ThemeManager.active.success
            if (label === "CRASHES") return value > 5 ? ThemeManager.active.error
                                    : value > 0 ? ThemeManager.active.warning
                                    : ThemeManager.active.subtext
            if (label === "ORPHANS") return value > 0 ? ThemeManager.active.warning : ThemeManager.active.subtext
            return ThemeManager.active.text // UPDATES — informational, never alarm-colored
        }

        // Bars used to carry this signal; once dropped, the % itself needs
        // to communicate severity instead of just being neutral text — same
        // "color instead of decoration" idea as _healthColor above. Takes a
        // plain 0-100 value (callers normalize ram/disk's 0-1 fraction first).
        function _loadColor(pct) {
            if (pct >= 90) return ThemeManager.active.error
            if (pct >= 70) return ThemeManager.active.warning
            return ThemeManager.active.text
        }

        property bool _firstSampleReceived: false
        Timer { interval: 1600; running: true; repeat: false; onTriggered: sysRoot._firstSampleReceived = true }

        // Opens a real terminal (not a hidden background Process) because
        // UPDATES/ORPHANS/CRASHES fixes need sudo — the user has to type
        // their password interactively. Stays open after the command exits
        // ("read -p") so they can see the output before it closes, and
        // re-polls SystemHealthService once they close it so the grid
        // reflects the new state without waiting for the 15min timer.
        function _runFix(item) {
            var proc = Qt.createQmlObject(
                'import Quickshell.Io; Process { stdout: StdioCollector { waitForEnd: true } }', sysRoot)
            proc.command = ["alacritty", "-e", "bash", "-c",
                item.cmd + "; echo; read -p 'done — press enter to close'"]
            proc.stdout.streamFinished.connect(function() {
                SystemHealthService.refresh()
                proc.destroy()
            })
            proc.running = true
        }

        // Same hero + companion shape as Overview (see OverviewTabBody:
        // calendar 60% / clock+weather 40%, one accent divider between) —
        // mirrored left-right per spec.md: companion (System Info, System
        // Health) sits at 40% on the left, Performance is the 60% hero on
        // the right.
        RowLayout {
            id: sysRow
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Tokens.spaceXl }
            spacing: Tokens.spaceLg

            // ---- System Info + System Health (companion column) ----------
            // Top-aligned, not stretched — this column's content (short text
            // rows + a compact grid) doesn't benefit from Overview's
            // clock/weather trick of centering into leftover space; forcing
            // it to fill left a dead gap before the divider whenever the
            // hero card was the taller side.
            ColumnLayout {
                Layout.preferredWidth: sysRow.width * 0.4
                Layout.alignment: Qt.AlignTop
                spacing: Tokens.spaceLg

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Tokens.spaceSm

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spaceMd
                        Item {
                            width: 56; height: 56

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: ThemeManager.active.overlay
                                visible: avatarImg.status !== Image.Ready
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰀄"
                                    font.family: ThemeManager.active.fontMono
                                    font.pixelSize: Tokens.text2xl
                                    color: ThemeManager.active.accent
                                }
                            }

                            // Rectangle.clip only clips to the item's bounding
                            // BOX, never to its rounded corners — a plain
                            // `radius` + `clip: true` wrapper (the old approach
                            // here) renders the photo as a hard-edged square.
                            // MultiEffect's alpha mask is the actual fix: source
                            // and mask both stay invisible, MultiEffect samples
                            // their textures directly (same module already used
                            // for blur elsewhere in this file).
                            Image {
                                id: avatarImg
                                anchors.fill: parent
                                source: sysRoot.avatarSource
                                fillMode: Image.PreserveAspectCrop
                                cache: false
                                visible: false
                                smooth: true
                                layer.enabled: true
                            }
                            Rectangle {
                                id: avatarMask
                                anchors.fill: parent
                                radius: width / 2
                                visible: false
                                layer.enabled: true
                            }
                            MultiEffect {
                                anchors.fill: avatarImg
                                source: avatarImg
                                maskEnabled: true
                                maskSource: avatarMask
                                visible: avatarImg.status === Image.Ready
                            }

                            // Accent ring — mirrors hyprlock's own avatar
                            // treatment (image { border_size = 3; border_color
                            // = $purple }) so the shell's identity moment
                            // matches the lockscreen's instead of looking like
                            // an unrelated widget.
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: "transparent"
                                border.width: 2
                                border.color: ThemeManager.active.accent
                                visible: avatarImg.status === Image.Ready
                            }
                        }
                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: sysRoot.username
                                font.family: ThemeManager.active.fontUi; font.bold: true
                                font.pixelSize: Tokens.textMd; color: ThemeManager.active.text
                            }
                            Text {
                                text: sysRoot.osName
                                font.family: ThemeManager.active.fontUi; font.pixelSize: Tokens.textSm
                                color: ThemeManager.active.subtext
                            }
                        }
                    }

                    // Was one run-on "WMName · sessiontype · uptime" string —
                    // read as an afterthought caption with no way to tell the
                    // three facts apart at a glance. Same label+value stat-cell
                    // grammar as the health row below instead, so this column
                    // reads as two named sections (facts, health) rather than
                    // an identity row with loose text trailing under it.
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Tokens.spaceXs
                        spacing: Tokens.spaceLg

                        Repeater {
                            model: [
                                { label: "WM",      value: sysRoot.wmName,      capitalize: false },
                                { label: "SESSION", value: sysRoot.sessionType, capitalize: true  },
                                { label: "UPTIME",  value: sysRoot.uptime,      capitalize: false }
                            ]
                            // No Layout.fillWidth here — forcing 3 equal thirds
                            // gave "Hyprland"/"11 hours, 50 minutes" ~75px each
                            // and elided them into "Hypri…"/"11 hours, 50 …".
                            // Natural width per cell + the trailing spacer below
                            // fills the row without starving any one value.
                            ColumnLayout {
                                required property var modelData
                                spacing: 0
                                SectionLabel { text: modelData.label }
                                Text {
                                    text: modelData.value
                                    font.family: ThemeManager.active.fontUi
                                    font.pixelSize: Tokens.textSm
                                    font.capitalization: modelData.capitalize ? Font.Capitalize : Font.MixedCase
                                    color: ThemeManager.active.text
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }

                Divider {}

                // Was a 2-column GridLayout with fixed columnSpacing — hugged
                // its own content width instead of the column's, leaving dead
                // space to the right of the panel. A fillWidth row of 4 equal
                // cells spans the full column instead (matches the
                // WM/SESSION/UPTIME row above). No heading — the Divider
                // above plus 4 caps-labeled cells already reads as its own
                // group without one.
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Tokens.spaceSm

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spaceMd

                        Repeater {
                            model: [
                                // md-update
                                { label: "UPDATES", icon: "󰚰", value: SystemHealthService.updates,
                                  cmd: "sudo pacman -Syu --noconfirm && (yay -Syu --noconfirm || paru -Syu --noconfirm)" },
                                // md-delete_variant
                                { label: "ORPHANS", icon: "󰆳", value: SystemHealthService.orphans,
                                  cmd: "sudo pacman -Rns $(pacman -Qtdq)" },
                                // md-alert_circle
                                { label: "FAILED",  icon: "󰀨", value: SystemHealthService.failedServices,
                                  cmd: "systemctl reset-failed" },
                                // Inspects rather than clears — the count is
                                // a 7-day journal window (see
                                // SystemHealthService), so there's nothing to
                                // "fix" here, just crashes worth looking at.
                                // md-skull
                                { label: "CRASHES", icon: "󰚌", value: SystemHealthService.coredumps,
                                  cmd: "coredumpctl list --since='7 days ago'" }
                            ]
                            Item {
                                id: healthCell
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: healthCellCol.implicitHeight

                                // A fixed 40px icon column (matching
                                // Performance) doesn't fit here — 4 cells
                                // share only 40% of the panel width, so each
                                // cell gets ~85-100px, and icon(40)+value+
                                // label-column overflowed that budget and
                                // spilled into the neighboring cell. Instead:
                                // small icon inline with just the value, on
                                // its own line, label kept full-width below
                                // exactly as before — only the value line
                                // grows by one glyph's width.
                                ColumnLayout {
                                    id: healthCellCol
                                    anchors { left: parent.left; right: parent.right; top: parent.top }
                                    spacing: 0
                                    RowLayout {
                                        spacing: Tokens.spaceXs
                                        Text {
                                            text: healthCell.modelData.icon
                                            font.family: ThemeManager.active.fontMono
                                            font.pixelSize: Tokens.textSm
                                            color: sysRoot._healthColor(healthCell.modelData.label, healthCell.modelData.value)
                                        }
                                        Text {
                                            text: healthCell.modelData.value
                                            font.family: ThemeManager.active.fontMono; font.bold: true
                                            font.pixelSize: Tokens.textLg
                                            color: sysRoot._healthColor(healthCell.modelData.label, healthCell.modelData.value)
                                        }
                                    }
                                    Text {
                                        text: healthCell.modelData.label
                                        font.family: ThemeManager.active.fontUi
                                        font.pixelSize: Tokens.text2xs
                                        color: ThemeManager.active.subtext
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: sysRoot._runFix(healthCell.modelData)
                                }
                            }
                        }
                    }
                }
            }

            // Accent divider — same "one visible thread" role as Overview's
            // calendar/companion divider.
            Rectangle {
                Layout.fillHeight: true
                Layout.topMargin: Tokens.spaceLg
                Layout.bottomMargin: Tokens.spaceLg
                width: 1
                color: ThemeManager.active.accent
                opacity: 0.35
            }

            // ---- Performance (hero) ---------------------------------------
            Item {
                id: perfCard
                Layout.preferredWidth: sysRow.width * 0.6
                Layout.alignment: Qt.AlignTop
                implicitHeight: perfContent.implicitHeight

                ColumnLayout {
                    id: perfContent
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    spacing: Tokens.spaceMd

                    // No bars — redundant next to an exact %, and NET (no
                    // natural 0-100% ceiling to fill against) never fit the
                    // pattern anyway. The % itself now carries severity via
                    // _loadColor instead. No peak caption — the % sits right
                    // beside the icon and the row's secondary detail (used/
                    // total, load average) is pushed to the far right by the
                    // fillWidth spacer, so every row is a single line: icon,
                    // value, detail.
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spaceSm
                        Text {
                            // md-cpu_64_bit
                            text: "󰻠"; Layout.preferredWidth: 40
                            horizontalAlignment: Text.AlignHCenter
                            font.family: ThemeManager.active.fontMono
                            font.pixelSize: Tokens.textLg; color: ThemeManager.active.text
                        }
                        Text {
                            text: sysRoot._firstSampleReceived ? Math.round(SystemService.cpuPercent) + "%" : "--"
                            font.family: ThemeManager.active.fontMono; font.bold: true; font.pixelSize: Tokens.textSm
                            color: sysRoot._firstSampleReceived ? sysRoot._loadColor(SystemService.cpuPercent) : ThemeManager.active.text
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            // Load average (1m/5m) — CPU's counterpart to
                            // RAM/GPU/DISK's used/total pair below.
                            text: sysRoot._firstSampleReceived && SystemService.cpuLoad ? "load " + SystemService.cpuLoad : ""
                            font.family: ThemeManager.active.fontMono; font.pixelSize: Tokens.textSm
                            color: ThemeManager.active.subtext
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spaceSm
                        Text {
                            // md-memory
                            text: "󰍛"; Layout.preferredWidth: 40
                            horizontalAlignment: Text.AlignHCenter
                            font.family: ThemeManager.active.fontMono
                            font.pixelSize: Tokens.textLg; color: ThemeManager.active.text
                        }
                        Text {
                            text: sysRoot._firstSampleReceived ? Math.round(SystemService.ramPercent * 100) + "%" : "--"
                            font.family: ThemeManager.active.fontMono; font.bold: true; font.pixelSize: Tokens.textSm
                            color: sysRoot._firstSampleReceived ? sysRoot._loadColor(SystemService.ramPercent * 100) : ThemeManager.active.text
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: sysRoot._firstSampleReceived ? SystemService.ramUsed + "/" + SystemService.ramTotal : ""
                            font.family: ThemeManager.active.fontMono; font.pixelSize: Tokens.textSm
                            color: ThemeManager.active.subtext
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spaceSm
                        Text {
                            // md-expansion_card
                            text: "󰢮"; Layout.preferredWidth: 40
                            horizontalAlignment: Text.AlignHCenter
                            font.family: ThemeManager.active.fontMono
                            font.pixelSize: Tokens.textLg; color: ThemeManager.active.text
                        }
                        Text {
                            text: sysRoot._firstSampleReceived ? Math.round(SystemService.gpuPercent) + "%" : "--"
                            font.family: ThemeManager.active.fontMono; font.bold: true; font.pixelSize: Tokens.textSm
                            color: sysRoot._firstSampleReceived ? sysRoot._loadColor(SystemService.gpuPercent) : ThemeManager.active.text
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: sysRoot._firstSampleReceived ? SystemService.vramUsed + "/" + SystemService.vramTotal : ""
                            font.family: ThemeManager.active.fontMono; font.pixelSize: Tokens.textSm
                            color: ThemeManager.active.subtext
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spaceSm
                        Text {
                            // md-harddisk
                            text: "󰋊"; Layout.preferredWidth: 40
                            horizontalAlignment: Text.AlignHCenter
                            font.family: ThemeManager.active.fontMono
                            font.pixelSize: Tokens.textLg; color: ThemeManager.active.text
                        }
                        Text {
                            text: sysRoot._firstSampleReceived ? Math.round(SystemService.diskPercent * 100) + "%" : "--"
                            font.family: ThemeManager.active.fontMono; font.bold: true; font.pixelSize: Tokens.textSm
                            color: sysRoot._firstSampleReceived ? sysRoot._loadColor(SystemService.diskPercent * 100) : ThemeManager.active.text
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: sysRoot._firstSampleReceived ? SystemService.diskUsed + "/" + SystemService.diskTotal : ""
                            font.family: ThemeManager.active.fontMono; font.pixelSize: Tokens.textSm
                            color: ThemeManager.active.subtext
                        }
                    }

                    // Last, not grouped with CPU/RAM/GPU/DISK — throughput
                    // isn't a load percentage (no natural ceiling, no
                    // severity color), so it sits after the four metrics
                    // that share that shape instead of breaking up the run.
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spaceSm
                        Text {
                            // md-network
                            text: "󰛳"; Layout.preferredWidth: 40
                            horizontalAlignment: Text.AlignHCenter
                            font.family: ThemeManager.active.fontMono
                            font.pixelSize: Tokens.textLg; color: ThemeManager.active.text
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: sysRoot._firstSampleReceived
                                ? "↓ " + sysRoot._fmtNet(SystemService.netDownKbps) + "  ↑ " + sysRoot._fmtNet(SystemService.netUpKbps)
                                : "--"
                            font.family: ThemeManager.active.fontMono; font.pixelSize: Tokens.textSm
                            color: ThemeManager.active.subtext
                        }
                    }
                }
            }
        }
    }

