pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property bool   visible: false
    property string icon:    ""
    property string label:   ""
    property real   value:   0.0
    property bool   muted:   false

    property var _timer: Timer {
        interval: 1500
        onTriggered: root.visible = false
    }

    // "mic-*" types read @DEFAULT_SOURCE@, everything else reads @DEFAULT_SINK@ —
    // covers both the sink/source keybinds and the sidebar VolumeControl icons.
    property bool _isSource: false

    property var _volProc: Process {
        id: volProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.value = Math.min(parseInt(text.trim()) / 100, 1.0)
                root._muteProc.running = true
            }
        }
    }

    property var _muteProc: Process {
        id: muteProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.muted = text.indexOf("yes") !== -1
                if (root._isSource) {
                    root.icon  = root.muted ? "󰍭" : "󰍬"
                    root.label = "Microphone"
                } else {
                    root.icon  = root.muted ? "󰝟"
                               : root.value > 0.6 ? "󰕾"
                               : root.value > 0.2 ? "󰖀" : "󰕿"
                    root.label = "Volume"
                }
                root._present()
            }
        }
    }

    function show(type) {
        root._isSource = type.indexOf("mic") === 0
        var target  = root._isSource ? "@DEFAULT_SOURCE@" : "@DEFAULT_SINK@"
        var getVol  = root._isSource ? "get-source-volume" : "get-sink-volume"
        var getMute = root._isSource ? "get-source-mute"   : "get-sink-mute"
        volProc.command  = ["bash", "-c", "pactl " + getVol + " " + target + " | grep -oP '[0-9]+(?=%)' | head -1"]
        muteProc.command = ["pactl", getMute, target]
        volProc.running = true
    }

    function _present() {
        visible = true
        _timer.restart()
    }
}
