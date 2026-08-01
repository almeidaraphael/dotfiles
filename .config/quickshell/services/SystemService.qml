pragma Singleton
import QtQuick
import Quickshell.Io
import ".."

QtObject {
    id: root

    // Polling only matters while the System tab itself is on-screen — the
    // 1.5s timer previously ran for the whole Dashboard regardless of which
    // tab was active (predated the tab split), wasting cycles on
    // Overview/Media/Theme/Settings.
    readonly property bool _visible: PanelManager.activePanel === "dashboard" &&
                                      PanelManager.activeTab === "system"

    property real   cpuPercent:  0
    property string cpuLoad:     ""
    property real   ramPercent:  0
    property string ramUsed:     ""
    property string ramTotal:    ""
    property real   gpuPercent:  0
    property string vramUsed:    ""
    property string vramTotal:   ""
    property real   netDownKbps: 0
    property real   netUpKbps:   0
    property real   diskPercent: 0
    property string diskUsed:    ""
    property string diskTotal:   ""

    property var _cpuPrev: null
    property var _netPrev: null

    property var _timer: Timer {
        interval: 1500
        running: root._visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root._poll()
    }

    function _run(cmd, cb) {
        // startDetached() is fire-and-forget and never fires `exited` — must use
        // running:true so Quickshell supervises the process and its stdout stream.
        var p = Qt.createQmlObject(
            'import Quickshell.Io; Process { stdout: StdioCollector { waitForEnd: true } }', root)
        p.command = cmd
        p.stdout.streamFinished.connect(function() {
            if (cb) cb(p.stdout.text.trim())
            p.destroy()
        })
        p.running = true
    }

    function _poll() {
        _pollCpu()
        _pollRam()
        _pollGpu()
        _pollNet()
        _pollDisk()
    }

    function _pollCpu() {
        // loadavg tacked onto the same call as /proc/stat — CPU's counterpart
        // to RAM/GPU/DISK's used/total pair, so the perf row has a second
        // value to show beside the icon instead of being the only metric
        // without one. 1m/5m only (not 15m) to match the two-number rhythm
        // the other rows already use.
        _run(["bash","-c","head -1 /proc/stat; cat /proc/loadavg"], function(out) {
            var lines = out.split("\n")
            var parts = lines[0].split(/\s+/)
            var user   = parseInt(parts[1])
            var nice   = parseInt(parts[2])
            var system = parseInt(parts[3])
            var idle   = parseInt(parts[4])
            var iowait = parseInt(parts[5])
            var total  = user + nice + system + idle + iowait +
                         parseInt(parts[6]) + parseInt(parts[7])
            if (root._cpuPrev) {
                var dTotal = total - root._cpuPrev.total
                var dIdle  = idle  - root._cpuPrev.idle
                root.cpuPercent = dTotal > 0 ? Math.round((1 - dIdle/dTotal) * 100) : 0
            }
            root._cpuPrev = { total: total, idle: idle }

            var la = lines[1] ? lines[1].split(/\s+/) : []
            if (la.length >= 2)
                root.cpuLoad = parseFloat(la[0]).toFixed(2) + "/" + parseFloat(la[1]).toFixed(2)
        })
    }

    function _pollRam() {
        _run(["bash","-c","grep -E '^(MemTotal|MemAvailable):' /proc/meminfo"], function(out) {
            var lines = out.split("\n")
            var total = 0, avail = 0
            lines.forEach(function(l) {
                var m = l.match(/(\w+):\s+(\d+)/)
                if (!m) return
                if (m[1] === "MemTotal")     total = parseInt(m[2])
                if (m[1] === "MemAvailable") avail = parseInt(m[2])
            })
            var used = total - avail
            root.ramPercent = total > 0 ? used / total : 0
            root.ramUsed  = _fmtKb(used)
            root.ramTotal = _fmtKb(total)
        })
    }

    function _pollGpu() {
        _run(["bash","-c",
            "cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1; " +
            "cat /sys/class/drm/card*/device/mem_info_vram_used 2>/dev/null | head -1; " +
            "cat /sys/class/drm/card*/device/mem_info_vram_total 2>/dev/null | head -1"],
            function(out) {
                var lines = out.split("\n")
                root.gpuPercent = parseInt(lines[0]) || 0
                root.vramUsed   = _fmtBytes(parseInt(lines[1]) || 0)
                root.vramTotal  = _fmtBytes(parseInt(lines[2]) || 0)
            })
    }

    function _pollNet() {
        _run(["bash","-c","grep -E '(eno|eth|wlan|enp|wlp)' /proc/net/dev | head -2 | awk '{print $2, $10}'"],
            function(out) {
                var lines = out.trim().split("\n")
                var rx = 0, tx = 0
                lines.forEach(function(l) {
                    var p = l.trim().split(/\s+/)
                    rx += parseInt(p[0]) || 0
                    tx += parseInt(p[1]) || 0
                })
                if (root._netPrev) {
                    root.netDownKbps = Math.max(0, (rx - root._netPrev.rx) / 1024 * (1000/1500))
                    root.netUpKbps   = Math.max(0, (tx - root._netPrev.tx) / 1024 * (1000/1500))
                }
                root._netPrev = { rx: rx, tx: tx }
            })
    }

    function _pollDisk() {
        _run(["bash","-c","df -BM / | tail -1 | awk '{print $3, $4}'"], function(out) {
            var p = out.split(/\s+/)
            var used  = parseInt(p[0])
            var avail = parseInt(p[1])
            var total = used + avail
            root.diskPercent = total > 0 ? used / total : 0
            root.diskUsed  = _fmtMb(used)
            root.diskTotal = _fmtMb(total)
        })
    }

    function _fmtKb(kb) {
        if (kb >= 1048576) return (kb/1048576).toFixed(1) + " GB"
        if (kb >= 1024)    return (kb/1024).toFixed(1)    + " MB"
        return kb + " KB"
    }
    function _fmtBytes(b) {
        if (b >= 1073741824) return (b/1073741824).toFixed(1) + " GB"
        if (b >= 1048576)    return (b/1048576).toFixed(1)    + " MB"
        return b + " B"
    }
    function _fmtMb(mb) {
        if (mb >= 1024) return (mb/1024).toFixed(1) + " GB"
        return mb + " MB"
    }
}
