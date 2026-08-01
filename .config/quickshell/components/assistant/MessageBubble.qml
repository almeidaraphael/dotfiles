import QtQuick
import QtQuick.Layouts
import "../.."
import "../shared"

// Plain text blocks differentiated by alignment + a subtle bg tint on the
// assistant side only (see .ui-craft/spec.md → Surface: Assistant Panel) —
// no colored chat-bubble slop.
RowLayout {
    id: root

    required property var modelData
    readonly property bool isUser: modelData.role === "user"
    property bool _copied: false

    Layout.fillWidth: true
    spacing: 0

    function _copyText() {
        ClipboardService.copy({ type: "text",
            text: root.modelData.streaming ? OllamaService.streamingText : root.modelData.text })
        root._copied = true
        copiedResetTimer.restart()
    }

    Timer { id: copiedResetTimer; interval: 1200; onTriggered: root._copied = false }

    Item { Layout.fillWidth: root.isUser; Layout.preferredWidth: 0 }

    ColumnLayout {
        id: content
        Layout.maximumWidth: root.width * 0.78
        Layout.margins: root.isUser ? 0 : Tokens.spaceSm
        spacing: Tokens.spaceXs

        Rectangle {
            visible: !root.isUser
            anchors.fill: parent
            anchors.margins: -Tokens.spaceSm
            radius: Tokens.radiusMd
            z: -1
            color: Qt.rgba(ThemeManager.active.accent.r, ThemeManager.active.accent.g,
                            ThemeManager.active.accent.b, 0.06)
        }

        ColumnLayout {
            id: thinkingBlock
            visible: !root.isUser && ((root.modelData.streaming && OllamaService.streamingThinking.length > 0) || !!root.modelData.thinking)
            Layout.fillWidth: true
            spacing: 2

            readonly property bool liveActive: root.modelData.streaming
                && OllamaService.streamingThinking.length > 0 && !OllamaService.streamingThinkClosed
            readonly property string thinkText: root.modelData.streaming
                ? OllamaService.streamingThinking : (root.modelData.thinking || "")
            readonly property int thinkSeconds: root.modelData.streaming
                ? OllamaService.streamingThinkSeconds : (root.modelData.thinkingSeconds || 0)
            property bool expanded: false

            Text {
                id: thinkLabel
                Layout.fillWidth: true
                text: thinkingBlock.liveActive ? "Thinking…"
                    : (thinkingBlock.thinkSeconds === 0
                        ? ("Thought " + (thinkingBlock.expanded ? "▾" : "▸"))
                        : ("Thought for " + thinkingBlock.thinkSeconds + "s " + (thinkingBlock.expanded ? "▾" : "▸")))
                font.family: ThemeManager.active.fontUi
                font.pixelSize: Tokens.textXs
                font.italic: true
                color: ThemeManager.active.subtext
                opacity: thinkingBlock.liveActive ? thinkLabel._pulse : 1.0
                property real _pulse: 1.0

                SequentialAnimation on _pulse {
                    running: thinkingBlock.liveActive && !ConfigService.reduceMotion
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.4; duration: Tokens.durationSlower }
                    NumberAnimation { to: 1.0; duration: Tokens.durationSlower }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !thinkingBlock.liveActive
                    cursorShape: Qt.PointingHandCursor
                    onClicked: thinkingBlock.expanded = !thinkingBlock.expanded
                }
            }

            Text {
                visible: thinkingBlock.liveActive || thinkingBlock.expanded
                Layout.fillWidth: true
                Layout.leftMargin: Tokens.spaceMd
                text: thinkingBlock.thinkText
                font.family: ThemeManager.active.fontUi
                font.pixelSize: Tokens.textXs
                font.italic: true
                color: ThemeManager.active.subtext
                wrapMode: Text.Wrap
            }
        }

        Text {
            id: bodyText
            visible: !root.modelData.toolCalling
            Layout.fillWidth: true
            text: (root.modelData.streaming ? OllamaService.streamingText : root.modelData.text)
                  + (root.modelData.streaming ? " ▍" : "")
            font.family: ThemeManager.active.fontUi
            font.pixelSize: Tokens.textSm
            color: root.modelData.error ? ThemeManager.active.error : ThemeManager.active.text
            wrapMode: Text.Wrap
            textFormat: Text.PlainText

            // Opacity is gated by the current modelData, not by the animation
            // itself — if a recycled delegate's leftover animation instance
            // is still mid-cycle, it only drives `_pulse`, which this message
            // ignores once `streaming` is false. See msgList.reuseItems note
            // in AssistantPanel.qml for why that can otherwise happen.
            opacity: root.modelData.streaming ? bodyText._pulse : 1.0
            property real _pulse: 1.0

            SequentialAnimation on _pulse {
                running: root.modelData.streaming && !ConfigService.reduceMotion
                loops: Animation.Infinite
                NumberAnimation { to: 0.55; duration: Tokens.durationSlower }
                NumberAnimation { to: 1.0;  duration: Tokens.durationSlower }
            }
        }

        Text {
            visible: !!root.modelData.toolCalling
            Layout.fillWidth: true
            text: "🔎 searching web for “" + root.modelData.toolQuery + "”…"
            font.family: ThemeManager.active.fontUi
            font.pixelSize: Tokens.textXs
            font.italic: true
            color: ThemeManager.active.subtext
        }

        Text {
            visible: !!root.modelData.error
            Layout.fillWidth: true
            text: root.modelData.error || ""
            font.family: ThemeManager.active.fontUi
            font.pixelSize: Tokens.textXs
            color: ThemeManager.active.error
            wrapMode: Text.Wrap
        }

        Repeater {
            model: root.modelData.citations || []
            delegate: ColumnLayout {
                id: citeRow
                required property var modelData
                required property int index
                readonly property bool isWeb: citeRow.modelData.kind === "web"
                property bool expanded: false
                Layout.fillWidth: true
                spacing: 2

                // Multiple citations can point at the same file (top-k RAG
                // chunks are picked by similarity, not deduped by filename) —
                // a same-file (N/total) suffix distinguishes them instead of
                // showing "source: README.md" repeated with no explanation.
                readonly property int _dupIndex: {
                    if (citeRow.isWeb) return 0
                    var citations = root.modelData.citations || []
                    var seen = 0
                    for (var i = 0; i <= citeRow.index; i++) {
                        if (citations[i].kind !== "web" && citations[i].file === citeRow.modelData.file) seen++
                    }
                    return seen
                }
                readonly property int _dupTotal: {
                    if (citeRow.isWeb) return 0
                    var citations = root.modelData.citations || []
                    var total = 0
                    for (var i = 0; i < citations.length; i++) {
                        if (citations[i].kind !== "web" && citations[i].file === citeRow.modelData.file) total++
                    }
                    return total
                }

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: citeRow.isWeb
                        ? ("🔗 " + citeRow.modelData.title)
                        : ((citeRow.expanded ? "▾ " : "▸ ") + "source: " + citeRow.modelData.file
                           + (citeRow._dupTotal > 1 ? " (" + citeRow._dupIndex + "/" + citeRow._dupTotal + ")" : ""))
                    font.family: ThemeManager.active.fontMono
                    font.pixelSize: Tokens.textXs
                    color: ThemeManager.active.subtext
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (citeRow.isWeb) {
                                var proc = Qt.createQmlObject(
                                    'import Quickshell.Io; Process {}', citeRow)
                                proc.command = ["xdg-open", citeRow.modelData.url]
                                proc.running = true
                            } else {
                                citeRow.expanded = !citeRow.expanded
                            }
                        }
                    }
                }

                Text {
                    visible: !citeRow.isWeb && citeRow.expanded
                    Layout.fillWidth: true
                    Layout.leftMargin: Tokens.spaceMd
                    text: citeRow.modelData.text || ""
                    font.family: ThemeManager.active.fontMono
                    font.pixelSize: Tokens.textXs
                    color: ThemeManager.active.subtext
                    wrapMode: Text.Wrap
                    maximumLineCount: 6
                    elide: Text.ElideRight
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: root.isUser ? Qt.AlignRight : Qt.AlignLeft
            visible: !root.modelData.toolCalling

            Rectangle {
                width: 20; height: 20; radius: Tokens.radiusSm
                color: Qt.rgba(1, 1, 1, 0.08)

                Text {
                    anchors.centerIn: parent
                    text: root._copied ? "󰄬" : "󰆏"
                    font.family: ThemeManager.active.fontMono
                    font.pixelSize: Tokens.textXs
                    color: root._copied ? ThemeManager.active.success : ThemeManager.active.subtext
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._copyText()
                }
            }
        }
    }

    Item { Layout.fillWidth: !root.isUser; Layout.preferredWidth: 0 }
}
