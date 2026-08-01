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

RowLayout {
    id: segRoot
    required property var    options
    required property string current
    signal pick(string val)
    spacing: Tokens.spaceXs

    Repeater {
        model: segRoot.options
        GlassButton {
            required property string modelData
            width: 70; height: 28
            active: modelData === segRoot.current
            activeFocusOnTab: true

            Text {
                anchors.centerIn: parent
                text: modelData
                font.family: ThemeManager.active.fontUi
                font.pixelSize: Tokens.textSm
                color: ThemeManager.active.text
            }

            MouseArea { anchors.fill: parent; onClicked: segRoot.pick(modelData) }
            Keys.onReturnPressed: segRoot.pick(modelData)
            Keys.onSpacePressed:  segRoot.pick(modelData)
        }
    }
}
