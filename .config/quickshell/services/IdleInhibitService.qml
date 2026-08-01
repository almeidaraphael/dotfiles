pragma Singleton
import Quickshell.Io
import QtQuick

// Single source of truth for the keep-awake toggle so every monitor's
// topbar KeepAwakeButton shows the same state and only one systemd-inhibit
// lock is ever held, instead of each button keeping its own local copy.
QtObject {
    id: root

    property bool awake: false

    // startDetached() is fire-and-forget and never fires `exited` — must use running:true,
    // and here we want it to keep running for as long as `awake` stays true.
    property var _inhibit: Process {
        command: ["systemd-inhibit", "--what=idle", "--who=quickshell",
                  "--why=Keep Awake", "--mode=block", "sleep", "infinity"]
        running: root.awake
    }

    function toggle() {
        root.awake = !root.awake
    }
}
