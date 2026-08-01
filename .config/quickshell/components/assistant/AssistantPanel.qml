import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../.."
import "../shared"

// Left-anchored mirror of Notification Center (see .ui-craft/spec.md →
// Surface: Assistant Panel) — same offsetScale/margins slide pattern, axis
// and edge flipped. One panel, two internal views (list/chat) rather than
// two PanelWindows, per brief principle 4 ("less is more").
PanelWindow {
    id: root

    screen: PanelManager.activeScreen
    focusable: true
    anchors { top: true; bottom: true; left: true }
    margins.top: Tokens.spaceLg
    margins.bottom: Tokens.spaceLg
    implicitWidth: 420
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    property bool shouldBeActive: PanelManager.activePanel === "assistant"
    property real offsetScale: shouldBeActive ? 0 : 1
    visible: shouldBeActive || offsetScale < 0.99

    margins.left: Tokens.spaceLg - (root.implicitWidth + Tokens.spaceLg) * root.offsetScale

    Behavior on offsetScale {
        enabled: !ConfigService.reduceMotion
        NumberAnimation { duration: Tokens.durationNormal; easing.type: Tokens.easeOut }
    }

    property string view: "list"
    property bool clearArmed: false

    onViewChanged: root.clearArmed = false

    readonly property var currentConv: OllamaService.conversations.find(
        function(c) { return c.id === OllamaService.activeConversationId }) || null

    // Guards double-send: Enter and the composer's send button both route
    // through _send(), and a second concurrent sendMessage() while one is
    // still streaming would corrupt the "last message" the stream appends
    // to (see OllamaService._runChat — it always targets messages[len-1]).
    readonly property bool streaming: root.currentConv && root.currentConv.messages.length > 0
        && root.currentConv.messages[root.currentConv.messages.length - 1].streaming

    onVisibleChanged: {
        if (visible) {
            OllamaService.refreshStatus()
            root.view = OllamaService.activeConversationId ? "chat" : "list"
        }
    }

    function _openConversation(id) {
        OllamaService.activeConversationId = id
        root.view = "chat"
    }

    function _newConversation() {
        OllamaService.newConversation()
        root.view = "chat"
        composerInput.forceActiveFocus()
    }

    GlassPanel {
        anchors.fill: parent
        opacity: 1 - root.offsetScale
        focus: true
        Keys.onEscapePressed: {
            if (root.view === "chat") root.view = "list"
            else PanelManager.close()
        }

        ColumnLayout {
            anchors { fill: parent; margins: Tokens.spaceLg }
            spacing: Tokens.spaceSm

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spaceSm

                GlassButton {
                    visible: root.view === "chat"
                    width: 28; height: 28
                    activeFocusOnTab: true
                    Text { anchors.centerIn: parent; text: "󰁍"; font.family: ThemeManager.active.fontMono; font.pixelSize: Tokens.textMd; color: ThemeManager.active.text }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.view = "list" }
                    Keys.onReturnPressed: root.view = "list"
                }

                Text {
                    Layout.fillWidth: true
                    text: root.view === "chat" && root.currentConv ? root.currentConv.title : "Assistant"
                    font.family: ThemeManager.active.fontUi
                    font.pixelSize: Tokens.textLg
                    font.bold: true
                    color: ThemeManager.active.text
                    elide: Text.ElideRight
                }

                GlassButton {
                    visible: root.view === "list" && OllamaService.conversations.length > 0
                    width: 28; height: 28
                    activeFocusOnTab: true
                    active: root.clearArmed

                    Timer {
                        id: clearArmTimer
                        interval: 3000
                        onTriggered: root.clearArmed = false
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.clearArmed ? "!" : "󰃢"
                        font.family: root.clearArmed ? ThemeManager.active.fontUi : ThemeManager.active.fontMono
                        font.bold: root.clearArmed
                        font.pixelSize: Tokens.textMd
                        color: root.clearArmed ? ThemeManager.active.error : ThemeManager.active.text
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.clearArmed) {
                                clearArmTimer.stop()
                                root.clearArmed = false
                                OllamaService.clearHistory()
                            } else {
                                root.clearArmed = true
                                clearArmTimer.restart()
                            }
                        }
                    }
                    Keys.onReturnPressed: {
                        if (root.clearArmed) {
                            clearArmTimer.stop()
                            root.clearArmed = false
                            OllamaService.clearHistory()
                        } else {
                            root.clearArmed = true
                            clearArmTimer.restart()
                        }
                    }
                }

                GlassButton {
                    visible: root.view === "list"
                    width: 28; height: 28
                    activeFocusOnTab: true
                    Text { anchors.centerIn: parent; text: "󰐕"; font.family: ThemeManager.active.fontMono; font.pixelSize: Tokens.textLg; color: ThemeManager.active.text }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root._newConversation() }
                    Keys.onReturnPressed: root._newConversation()
                }

                GlassButton {
                    width: 28; height: 28
                    activeFocusOnTab: true
                    Text { anchors.centerIn: parent; text: "󰅖"; font.family: ThemeManager.active.fontMono; font.pixelSize: Tokens.textMd; color: ThemeManager.active.text }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: PanelManager.close() }
                    Keys.onReturnPressed: PanelManager.close()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spaceSm

                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: OllamaService.connected ? ThemeManager.active.success : ThemeManager.active.error
                }

                Text {
                    visible: !OllamaService.canSwitchModel
                    Layout.fillWidth: true
                    text: "ollama · " + (OllamaService.activeModel || "no model") + " · "
                        + (OllamaService.connected ? "connected" : "down")
                    font.family: ThemeManager.active.fontUi
                    font.pixelSize: Tokens.text2xs
                    font.letterSpacing: 0.4
                    color: ThemeManager.active.subtext
                    elide: Text.ElideRight
                }

                GlassComboBox {
                    id: modelPicker
                    visible: OllamaService.canSwitchModel
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    model: OllamaService.availableModels
                    currentIndex: OllamaService.availableModels.indexOf(OllamaService.activeModel)
                    onActivated: function(index) {
                        OllamaService.setActiveModel(OllamaService.availableModels[index])
                    }
                }

                Text {
                    visible: OllamaService.canSwitchModel
                    text: OllamaService.connected ? "connected" : "down"
                    font.family: ThemeManager.active.fontUi
                    font.pixelSize: Tokens.text2xs
                    font.letterSpacing: 0.4
                    color: ThemeManager.active.subtext
                }

                GlassButton {
                    visible: !OllamaService.connected
                    Layout.preferredWidth: 44; Layout.preferredHeight: 20
                    activeFocusOnTab: true
                    Text { anchors.centerIn: parent; text: "Retry"; font.pixelSize: Tokens.text2xs; color: ThemeManager.active.text }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: OllamaService.refreshStatus() }
                    Keys.onReturnPressed: OllamaService.refreshStatus()
                }
            }

            Text {
                visible: !OllamaService.connected && OllamaService.lastError.length > 0
                Layout.fillWidth: true
                text: OllamaService.lastError
                font.family: ThemeManager.active.fontUi
                font.pixelSize: Tokens.textXs
                color: ThemeManager.active.error
                wrapMode: Text.Wrap
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: ThemeManager.active.border; opacity: 0.4 }

            // --- List view -----------------------------------------------------
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.view === "list"

                Text {
                    anchors.centerIn: parent
                    width: parent.width * 0.8
                    visible: OllamaService.conversations.length === 0
                    text: "No conversations yet\nStart one, attach a file for grounded answers."
                    horizontalAlignment: Text.AlignHCenter
                    font.family: ThemeManager.active.fontUi
                    font.pixelSize: Tokens.textMd
                    color: ThemeManager.active.subtext
                    wrapMode: Text.Wrap
                }

                ListView {
                    id: convList
                    anchors.fill: parent
                    visible: OllamaService.conversations.length > 0
                    clip: true
                    spacing: Tokens.spaceSm
                    model: OllamaService.conversations
                    focus: root.view === "list"
                    keyNavigationEnabled: true
                    ScrollBar.vertical: ScrollBar {}

                    delegate: GlassCard {
                        id: convItem
                        required property var modelData
                        width: ListView.view.width
                        height: 88

                        readonly property string _preview: {
                            var msgs = modelData.messages
                            if (msgs.length === 0) return "No messages yet"
                            return msgs[msgs.length - 1].text.replace(/\s+/g, " ").trim().slice(0, 240)
                        }

                        ColumnLayout {
                            anchors { left: parent.left; right: deleteBtn.left; top: parent.top; bottom: parent.bottom; margins: Tokens.spaceMd }
                            spacing: 2
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spaceSm
                                Text {
                                    Layout.fillWidth: true
                                    text: convItem.modelData.title
                                    font.family: ThemeManager.active.fontUi
                                    font.pixelSize: Tokens.textMd
                                    font.bold: true
                                    color: ThemeManager.active.text
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: root._relTime(convItem.modelData.updatedAt)
                                    font.family: ThemeManager.active.fontUi
                                    font.pixelSize: Tokens.textXs
                                    color: ThemeManager.active.subtext
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: convItem._preview
                                font.family: ThemeManager.active.fontUi
                                font.pixelSize: Tokens.textXs
                                color: ThemeManager.active.subtext
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            id: deleteBtn
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter; margins: Tokens.spaceSm }
                            text: "×"
                            font.pixelSize: Tokens.textLg
                            color: ThemeManager.active.subtext
                            MouseArea {
                                anchors.margins: -8
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: OllamaService.deleteConversation(convItem.modelData.id)
                            }
                        }

                        MouseArea {
                            anchors { left: parent.left; right: deleteBtn.left; top: parent.top; bottom: parent.bottom }
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root._openConversation(convItem.modelData.id)
                        }

                        Keys.onReturnPressed: root._openConversation(convItem.modelData.id)
                    }
                }
            }

            // --- Chat view ------------------------------------------------------
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.view === "chat"
                spacing: Tokens.spaceSm

                ListView {
                    id: msgList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: Tokens.spaceMd
                    model: root.currentConv ? root.currentConv.messages : []
                    onCountChanged: Qt.callLater(function() { msgList.positionViewAtEnd() })
                    ScrollBar.vertical: ScrollBar {}

                    // Qt6 defaults ListView to reusing delegate instances across
                    // model resets. The streaming caret's looping opacity
                    // animation on a reused Text can outlive the swap to a
                    // different (non-streaming) message — a short list of chat
                    // turns doesn't need recycling's perf win, so it's simpler
                    // and safer to just always create fresh delegates.
                    reuseItems: false

                    Connections {
                        target: OllamaService
                        function onStreamingTextChanged() { Qt.callLater(function() { msgList.positionViewAtEnd() }) }
                        // Reasoning grows while streamingText is still empty, so
                        // without this the live "Thinking…" block scrolls out of
                        // view with nothing to pull the list back down.
                        function onStreamingThinkingChanged() { Qt.callLater(function() { msgList.positionViewAtEnd() }) }
                    }

                    delegate: MessageBubble {
                        width: ListView.view.width
                    }
                }

                // Folder attach can add dozens of chips at once — an unbounded
                // Flow would push the composer input off-screen. Capped at
                // ~3 rows, scrollable beyond that, same ScrollBar pattern as
                // msgList/composerFlick elsewhere in this panel.
                Flickable {
                    id: attachmentsFlick
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(attachmentsFlow.implicitHeight, 3 * (24 + Tokens.spaceXs))
                    visible: root.currentConv && root.currentConv.attachments.length > 0
                    clip: true
                    contentWidth: width
                    contentHeight: attachmentsFlow.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {}

                    Flow {
                        id: attachmentsFlow
                        width: attachmentsFlick.width
                        spacing: Tokens.spaceXs

                        Repeater {
                            model: root.currentConv ? root.currentConv.attachments : []
                            delegate: AttachmentChip {
                                onRemoveRequested: OllamaService.removeAttachment(root.currentConv.id, modelData.id)
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spaceSm

                    GlassButton {
                        width: 32; height: 32
                        activeFocusOnTab: true
                        Text { anchors.centerIn: parent; text: ""; font.family: ThemeManager.active.fontMono; font.pixelSize: Tokens.textMd; color: ThemeManager.active.text }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: OllamaService.attachFile(root.currentConv.id)
                        }
                    }

                    GlassButton {
                        width: 32; height: 32
                        activeFocusOnTab: true
                        Text { anchors.centerIn: parent; text: "󰉋"; font.family: ThemeManager.active.fontMono; font.pixelSize: Tokens.textMd; color: ThemeManager.active.text }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: OllamaService.attachFolder(root.currentConv.id)
                        }
                    }

                    GlassCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(composerInput.implicitHeight + Tokens.spaceMd * 2, 140)
                        radius: Tokens.radiusMd

                        Flickable {
                            id: composerFlick
                            anchors.fill: parent
                            anchors.margins: Tokens.spaceMd
                            contentHeight: composerInput.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            ScrollBar.vertical: ScrollBar {}

                            TextEdit {
                                id: composerInput
                                width: parent.width
                                font.family: ThemeManager.active.fontUi
                                font.pixelSize: Tokens.textSm
                                color: ThemeManager.active.text
                                opacity: root.streaming ? 0.5 : 1
                                readOnly: root.streaming
                                wrapMode: TextEdit.Wrap
                                selectByMouse: true

                                // Flickable doesn't auto-follow the cursor —
                                // without this, typing past the visible
                                // height looks like input is capped/silently
                                // dropping keystrokes even though the text
                                // is there, just scrolled out of view.
                                onCursorRectangleChanged: {
                                    var cr = cursorRectangle
                                    if (cr.y < composerFlick.contentY)
                                        composerFlick.contentY = cr.y
                                    else if (cr.y + cr.height > composerFlick.contentY + composerFlick.height)
                                        composerFlick.contentY = cr.y + cr.height - composerFlick.height
                                }

                                Text {
                                    anchors.fill: parent
                                    visible: composerInput.text.length === 0
                                    text: "Type a message… (Shift+Enter for newline)"
                                    font: composerInput.font
                                    color: ThemeManager.active.subtext
                                }

                                Keys.onPressed: function(event) {
                                    if (event.key === Qt.Key_Return && !(event.modifiers & Qt.ShiftModifier)) {
                                        event.accepted = true
                                        if (!root.streaming) root._send()
                                    }
                                }
                            }
                        }
                    }

                    GlassButton {
                        width: 32; height: 32
                        activeFocusOnTab: true
                        Text {
                            anchors.centerIn: parent
                            text: root.streaming ? "󰓛" : "󰁝"
                            font.family: ThemeManager.active.fontMono
                            font.pixelSize: Tokens.textMd
                            color: ThemeManager.active.text
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.streaming ? OllamaService.stopStreaming() : root._send()
                        }
                    }
                }
            }
        }
    }

    function _send() {
        if (!root.currentConv || root.streaming || composerInput.text.trim().length === 0) return
        OllamaService.sendMessage(root.currentConv.id, composerInput.text)
        composerInput.text = ""
        composerFlick.contentY = 0
    }

    function _relTime(ts) {
        if (!ts) return ""
        var secs = Math.max(0, (Date.now() - ts.getTime()) / 1000)
        if (secs < 60) return "now"
        if (secs < 3600) return Math.floor(secs / 60) + "m ago"
        if (secs < 86400) return Math.floor(secs / 3600) + "h ago"
        return Math.floor(secs / 86400) + "d ago"
    }
}
