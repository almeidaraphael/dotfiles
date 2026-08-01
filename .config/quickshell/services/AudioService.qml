pragma Singleton
import QtQuick
import Quickshell.Io
import ".."

// Single source of truth for output/input volume+mute so every monitor's
// topbar VolumeControl shows the same state instead of each keeping its own
// local copy (which is what silently desynced multi-monitor setups before).
QtObject {
    id: root

    property real outputVolume: 0.5
    property bool outputMuted:  false
    property real inputVolume:  0.5
    property bool inputMuted:   false

    property var _outputLines: []
    property var _inputLines:  []

    function _applyLines(lines, isOutput) {
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            var sep = line.indexOf(":")
            if (sep < 0) continue
            var key = line.slice(0, sep)
            var val = line.slice(sep + 1)
            if (key === "VOL") {
                var vol = parseInt(val) / 100
                if (isOutput) root.outputVolume = vol
                else          root.inputVolume  = vol
            } else if (key === "MUTE") {
                var muted = val.indexOf("yes") !== -1
                if (isOutput) root.outputMuted = muted
                else          root.inputMuted  = muted
            }
        }
    }

    property var _outputReader: Process {
        stdout: SplitParser {
            onRead: function(d) { if (d) root._outputLines.push(d) }
        }
        onExited: {
            root._applyLines(root._outputLines, true)
            root._outputLines = []
        }
    }

    property var _inputReader: Process {
        stdout: SplitParser {
            onRead: function(d) { if (d) root._inputLines.push(d) }
        }
        onExited: {
            root._applyLines(root._inputLines, false)
            root._inputLines = []
        }
    }

    function refresh(target) {
        var isOutput = target === "output"
        var reader   = isOutput ? root._outputReader : root._inputReader
        // pactl's magic device names differ from wpctl's (@DEFAULT_SINK@ vs @DEFAULT_AUDIO_SINK@) —
        // this shells out to pactl, _run()'s wpctl calls below use the wpctl form.
        var dev      = isOutput ? "@DEFAULT_SINK@"   : "@DEFAULT_SOURCE@"
        var getVol   = isOutput ? "get-sink-volume"  : "get-source-volume"
        var getMute  = isOutput ? "get-sink-mute"    : "get-source-mute"
        if (isOutput) root._outputLines = []
        else          root._inputLines  = []
        reader.command = ["bash", "-c",
            "echo VOL:$(pactl " + getVol + " " + dev + " | grep -oP '[0-9]+(?=%)' | head -1);" +
            "echo MUTE:$(pactl " + getMute + " " + dev + ")"]
        reader.running = true
    }

    function _run(cmd, onFailureSummary) {
        ProcessRunner.run(cmd, { appName: "Audio", onFailureSummary: onFailureSummary })
    }

    function toggleMute(target) {
        var isOutput = target === "output"
        var dev = isOutput ? "@DEFAULT_AUDIO_SINK@" : "@DEFAULT_AUDIO_SOURCE@"
        root._run(["wpctl", "set-mute", dev, "toggle"], "Couldn't toggle mute")
        if (isOutput) root.outputMuted = !root.outputMuted
        else          root.inputMuted  = !root.inputMuted
        OsdService.show(isOutput ? "volume-mute" : "mic-mute")
    }

    function adjustVolume(target, delta) {
        var isOutput = target === "output"
        var dev  = isOutput ? "@DEFAULT_AUDIO_SINK@" : "@DEFAULT_AUDIO_SOURCE@"
        var cur  = isOutput ? root.outputVolume : root.inputVolume
        var next = Math.max(0, Math.min(1, cur + delta))
        root._run(["wpctl", "set-volume", dev, Math.round(next * 100) + "%"], "Couldn't change volume")
        if (isOutput) root.outputVolume = next
        else          root.inputVolume  = next
        var dir = delta > 0 ? "up" : "down"
        OsdService.show(isOutput ? "volume-" + dir : "mic-volume-" + dir)
    }

    Component.onCompleted: {
        refresh("output")
        refresh("input")
    }
}
