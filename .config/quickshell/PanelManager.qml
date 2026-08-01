pragma Singleton
import QtQuick
import Quickshell

QtObject {
    id: root

    property string activePanel:  ""
    property string activeTab:    "overview"
    property var    activeScreen: null

    Component.onCompleted: _updateScreen()

    function _updateScreen() {
        var mon = HyprlandService.focusedMonitor
        for (var i = 0; i < Quickshell.screens.length; i++) {
            if (!mon || Quickshell.screens[i].name === mon.name) {
                activeScreen = Quickshell.screens[i]
                return
            }
        }
        if (Quickshell.screens.length > 0) activeScreen = Quickshell.screens[0]
    }

    property var _hyprConn: Connections {
        target: HyprlandService
        function onFocusedMonitorChanged() { root._updateScreen() }
    }

    function toggle(name) {
        activePanel = (activePanel === name) ? "" : name
    }

    function openTab(tab) {
        activeTab = tab
        activePanel = "dashboard"
    }

    // Clock/right-click-style triggers want "open to this tab, or close if
    // already open on it" — a plain toggle("dashboard") would reopen on
    // whatever tab was last active instead of the intended one.
    function toggleTab(tab) {
        if (activePanel === "dashboard" && activeTab === tab) close()
        else openTab(tab)
    }

    function close() {
        activePanel = ""
    }
}
