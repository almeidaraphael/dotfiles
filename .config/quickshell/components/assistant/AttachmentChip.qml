import QtQuick
import QtQuick.Layouts
import "../.."
import "../shared"

// Composer chip — queued/embedding/ready/failed. Failed is a per-chip
// partial state, not a panel-level error (spec: Assistant Panel, State lattice).
RowLayout {
    id: root

    required property var modelData
    signal removeRequested()

    // Folder attach names chips with a path relative to the picked folder, so
    // `label.implicitWidth` (always the full un-elided text width, regardless
    // of elide/maximumWidth) can far exceed what's actually rendered. The chip
    // must size to the capped width, not the un-elided one, or a deep path
    // produces a chip wider than the whole 420px panel.
    readonly property int labelMaxWidth: 140

    // root is placed inside a Flow (AssistantPanel.qml), a Positioner that
    // sizes children from actual width/height — not a Layout, so Layout.*
    // attached properties on root itself are no-ops here (they only apply
    // to root's own children, e.g. chipRect below). Without this, root's
    // width/height silently stay 0 and the chip never appears, though its
    // data is entirely correct.
    //
    // height is a literal (not chipRect.height) because chipRect uses
    // Layout.fillHeight — binding root's height from chipRect while
    // chipRect's height derives from root would be circular.
    height: 24
    width: chipRect.width
    spacing: Tokens.spaceXs

    Rectangle {
        id: chipRect
        Layout.fillHeight: true
        Layout.preferredWidth: icon.implicitWidth + Math.min(label.implicitWidth, root.labelMaxWidth) + statusLabel.implicitWidth + removeBtn.width + Tokens.spaceMd * 2 + Tokens.spaceXs * 3
        radius: Tokens.radiusSm
        color: ThemeManager.active.blur
            ? Qt.rgba(1, 1, 1, 0.08)
            : ThemeManager.active.overlay
        border.color: root.modelData.status === "failed"
            ? Qt.rgba(ThemeManager.active.error.r, ThemeManager.active.error.g, ThemeManager.active.error.b, 0.6)
            : Qt.rgba(1, 1, 1, 0.14)
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.spaceSm
            anchors.rightMargin: Tokens.spaceXs
            spacing: Tokens.spaceXs

            Text {
                id: icon
                text: ""
                font.family: ThemeManager.active.fontMono
                font.pixelSize: Tokens.textXs
                color: ThemeManager.active.text
            }

            Text {
                id: label
                text: root.modelData.name
                font.family: ThemeManager.active.fontUi
                font.pixelSize: Tokens.textXs
                color: ThemeManager.active.text
                elide: Text.ElideMiddle
                Layout.maximumWidth: root.labelMaxWidth
            }

            Text {
                id: statusLabel
                text: root.modelData.status === "ready"     ? "✓"
                    : root.modelData.status === "failed"     ? "✕"
                    : root.modelData.status === "embedding"  ? "⋯"
                    : "…"
                font.family: ThemeManager.active.fontMono
                font.pixelSize: Tokens.textXs
                color: root.modelData.status === "ready"  ? ThemeManager.active.success
                     : root.modelData.status === "failed" ? ThemeManager.active.error
                     : ThemeManager.active.subtext
            }

            Text {
                id: removeBtn
                text: "×"
                font.pixelSize: Tokens.textSm
                color: ThemeManager.active.subtext
                MouseArea {
                    anchors.margins: -6
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.removeRequested()
                }
            }
        }
    }
}
