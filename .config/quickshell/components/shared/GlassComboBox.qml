import QtQuick
import QtQuick.Controls
import "../.."

ComboBox {
    id: root

    // Optional formatter applied to both the closed-state text and popup rows —
    // lets callers show a friendly label while `model`/`currentIndex` keep raw values.
    property var formatText: function(s) { return s }

    implicitHeight: 38
    displayText: formatText(currentText)

    delegate: ItemDelegate {
        id: del
        width: root.width
        required property var modelData
        required property int index
        highlighted: root.highlightedIndex === index

        contentItem: Text {
            text: root.formatText(del.modelData)
            font.family: ThemeManager.active.fontUi
            font.pixelSize: Tokens.textSm
            color: ThemeManager.active.text
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: Tokens.radiusMd
            color: ThemeManager.active.accent
            opacity: del.highlighted ? 0.25 : 0
        }
    }

    background: Rectangle {
        radius: Tokens.radiusMd
        color: ThemeManager.active.overlay
        opacity: ThemeManager.active.blur ? 0.55 : 1
        border.width: 1
        border.color: Qt.rgba(ThemeManager.active.border.r, ThemeManager.active.border.g,
                               ThemeManager.active.border.b, root.activeFocus ? 0.9 : 0.5)
    }

    contentItem: Text {
        leftPadding: Tokens.spaceMd
        rightPadding: 28
        text: root.displayText
        font.family: ThemeManager.active.fontUi
        font.pixelSize: Tokens.textSm
        color: ThemeManager.active.text
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }

    indicator: Text {
        x: root.width - width - Tokens.spaceMd
        y: root.topPadding + (root.availableHeight - height) / 2
        text: "󰅀"
        font.family: ThemeManager.active.fontMono
        font.pixelSize: Tokens.textSm
        color: ThemeManager.active.subtext
    }

    popup: Popup {
        y: root.height + 4
        width: root.width
        implicitHeight: Math.min(contentItem.implicitHeight, 220)
        padding: Tokens.spaceXs

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator {}
        }

        background: Rectangle {
            radius: Tokens.radiusMd
            color: ThemeManager.active.base
            border.width: 1
            border.color: Qt.rgba(ThemeManager.active.border.r, ThemeManager.active.border.g,
                                   ThemeManager.active.border.b, 0.6)
        }
    }
}
