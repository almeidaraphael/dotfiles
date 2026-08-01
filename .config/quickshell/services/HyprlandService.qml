pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

QtObject {
    id: root

    property var workspaces:         Hyprland.workspaces
    property var focusedWorkspace:   Hyprland.focusedWorkspace
    property var focusedMonitor:     Hyprland.focusedMonitor
    property var clientsByWorkspace: ({})
    // Static workspace->monitor bindings from hyprland.conf (`workspace = N,
    // monitor:X` rules) — id string -> monitor name. Unlike Hyprland.workspaces
    // (which only contains workspaces that currently exist/have been visited),
    // this lets the bar show a monitor's assigned-but-empty workspaces too.
    property var workspaceBindings: ({})

    property var _clientsProc: Process {
        id: clientsProc
        command: ["hyprctl", "clients", "-j"]
        property string _buf: ""

        stdout: SplitParser {
            onRead: data => clientsProc._buf += data + "\n"
        }

        onExited: {
            try {
                var data = JSON.parse(clientsProc._buf)
                var byWs = {}
                for (var i = 0; i < data.length; i++) {
                    var c = data[i]
                    var wsId = c.workspace.id
                    if (!byWs[wsId]) byWs[wsId] = []
                    byWs[wsId].push(c["class"])
                }
                root.clientsByWorkspace = byWs
            } catch(e) {
                console.log("HyprlandService clients parse error:", e)
            }
            clientsProc._buf = ""
        }
    }

    property var _rulesProc: Process {
        id: rulesProc
        command: ["hyprctl", "workspacerules", "-j"]
        property string _buf: ""

        stdout: SplitParser {
            onRead: data => rulesProc._buf += data + "\n"
        }

        onExited: {
            try {
                var data = JSON.parse(rulesProc._buf)
                var bindings = {}
                for (var i = 0; i < data.length; i++) {
                    var r = data[i]
                    if (r.monitor && /^\d+$/.test(r.workspaceString))
                        bindings[r.workspaceString] = r.monitor
                }
                root.workspaceBindings = bindings
            } catch(e) {
                console.log("HyprlandService workspacerules parse error:", e)
            }
            rulesProc._buf = ""
        }
    }

    property var _pollTimer: Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root._clientsProc.running)
                root._clientsProc.running = true
        }
    }

    // Fetched once — workspace rules only change on a hyprland.conf reload,
    // not worth polling on the same 1500ms cadence as live client state.
    Component.onCompleted: _rulesProc.running = true

    function dispatch(cmd) {
        Hyprland.dispatch(cmd)
    }

    // Hyprland 0.56 replaced the plain-string dispatch protocol with a
    // Lua-eval one (`hl.dsp.*` calls) — Hyprland.dispatch() from
    // Quickshell.Hyprland still sends the old string form, which 0.56
    // silently rejects. Shell out to hyprctl directly with the new syntax
    // until Quickshell's Hyprland module catches up.
    property var _dispatchProc: Process {}

    function switchWorkspace(id) {
        _dispatchProc.command = ["hyprctl", "dispatch", "hl.dsp.focus({workspace = " + id + "})"]
        _dispatchProc.running = true
    }
}
