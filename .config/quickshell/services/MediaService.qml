pragma Singleton
import QtQuick
import Quickshell.Io
import ".."

QtObject {
    id: root

    property string title:        "No media"
    property string artist:       ""
    property string album:        ""
    property string artUrl:       ""
    property string status:       "Stopped"
    property real   position:     0.0
    property real   duration:     0.0
    property var    players:      []
    property string activePlayer: ""
    property var    spectrum:     []

    property var _cavaProc: Process {
        id: cavaProc
        command: ["/bin/sh", "-c", "exec cava -p \"$HOME/.config/cava/quickshell.conf\""]

        stdout: SplitParser {
            onRead: data => {
                var vals = data.split(";").filter(function(s) { return s.length > 0 })
                root.spectrum = vals.map(function(v) { return parseInt(v) || 0 })
            }
        }

        onExited: root.spectrum = []
    }

    onStatusChanged: {
        if (status === "Playing" && !_cavaProc.running) _cavaProc.running = true
        else if (status !== "Playing" && _cavaProc.running) _cavaProc.running = false
        _toastDebounce.restart()
    }
    onTitleChanged:  _toastDebounce.restart()
    onArtistChanged: _toastDebounce.restart()

    property bool   _toastInitialized: false
    property string _lastToastKey:     ""

    property var _toastDebounce: Timer {
        interval: 200
        onTriggered: root._maybeToast()
    }

    function _maybeToast() {
        var key = status + "|" + title + "|" + artist
        if (!_toastInitialized) {
            _lastToastKey = key
            _toastInitialized = true
            return
        }
        if (key === _lastToastKey) return
        _lastToastKey = key
        if (status === "Stopped") return

        NotificationService.notifyTransient({
            appName: "Media",
            summary: status === "Playing" ? title : "Paused",
            body:    status === "Playing" ? artist : title,
            icon:    artUrl,
            urgency: 1
        })
    }

    property var _pollTimer: Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root._poll()
    }

    function _run(args, cb) {
        // startDetached() is fire-and-forget and never fires `exited` — must use
        // running:true so Quickshell supervises the process and its stdout stream.
        var p = Qt.createQmlObject(
            'import Quickshell.Io; Process { stdout: StdioCollector { waitForEnd: true } }', root)
        p.command = args
        p.stdout.streamFinished.connect(function() {
            if (cb) cb(p.stdout.text.trim())
            p.destroy()
        })
        p.running = true
    }

    function _poll() {
        _run(["playerctl","--list-all"], function(out) {
            players = out.split("\n").filter(Boolean)
            if (activePlayer !== "" && players.indexOf(activePlayer) === -1) activePlayer = ""
            if (players.length > 0 && activePlayer === "") activePlayer = players[0]
            if (activePlayer === "") {
                title = "No media"; artist = ""; album = ""; artUrl = ""
                status = "Stopped"; position = 0; duration = 0
            }
        })
        if (activePlayer === "") return
        var p = activePlayer

        _run(["playerctl","-p",p,"status"],                   function(s) { status   = s || "Stopped" })
        _run(["playerctl","-p",p,"metadata","title"],          function(s) { title    = s || "No media" })
        _run(["playerctl","-p",p,"metadata","artist"],         function(s) { artist   = s })
        _run(["playerctl","-p",p,"metadata","album"],          function(s) { album    = s })
        _run(["playerctl","-p",p,"metadata","mpris:artUrl"],   function(s) { artUrl   = s })
        _run(["playerctl","-p",p,"metadata","mpris:length"],   function(s) {
            duration = s ? parseInt(s) / 1000000 : 0
        })
        _run(["playerctl","-p",p,"position"], function(s) {
            position = s ? parseFloat(s) : 0
        })
    }

    function playPause() { _run(["playerctl","-p",activePlayer,"play-pause"], null) }
    function play()      { _run(["playerctl","-p",activePlayer,"play"],       null) }
    function pause()     { _run(["playerctl","-p",activePlayer,"pause"],      null) }
    function next()      { _run(["playerctl","-p",activePlayer,"next"],       null) }
    function previous()  { _run(["playerctl","-p",activePlayer,"previous"],   null) }
    function seek(secs)  { _run(["playerctl","-p",activePlayer,"position",String(secs)], null) }

    function setPlayer(name) {
        activePlayer = name
        _poll()
    }
}
