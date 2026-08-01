pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property int updates:        0
    property int orphans:        0
    property int failedServices: 0
    property int coredumps:      0

    property var _timer: Timer {
        interval: 900000 // 15 min — these checks shell out further than /proc reads, keep them rare
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root._poll()
    }

    function refresh() { root._poll() }

    function _poll() {
        // startDetached() is fire-and-forget and never fires `exited` — must use
        // running:true so Quickshell supervises the process and its stdout stream.
        var proc = Qt.createQmlObject(
            'import Quickshell.Io; Process { stdout: StdioCollector { waitForEnd: true } }', root)
        proc.command = ["bash", "-c",
            "p=$(checkupdates 2>/dev/null | wc -l); " +
            "a=$( (yay -Qu 2>/dev/null || paru -Qu 2>/dev/null) | wc -l); " +
            "echo $((p + a)); " +
            "pacman -Qtdq 2>/dev/null | wc -l; " +
            "systemctl --failed --no-legend 2>/dev/null | wc -l; " +
            // Journal entries outlive the dump file (rm'ing
            // /var/lib/systemd/coredump/* frees disk but coredumpctl still
            // lists it as "missing") — a real fix would mean vacuuming the
            // whole journal, not just crash records. Time-bounding instead
            // so old crashes age out of the count on their own.
            "coredumpctl list --no-legend --since='7 days ago' 2>/dev/null | wc -l"]
        proc.stdout.streamFinished.connect(function() {
            var lines = proc.stdout.text.trim().split("\n")
            root.updates        = parseInt(lines[0]) || 0
            root.orphans        = parseInt(lines[1]) || 0
            root.failedServices = parseInt(lines[2]) || 0
            root.coredumps      = parseInt(lines[3]) || 0
            proc.destroy()
        })
        proc.running = true
    }
}
