import Quickshell
import Quickshell.Io
import "./themes"
import "./services"
import "./components/topbar"
import "./components/panels"
import "./components/launcher"
import "./components/notifications"
import "./components/osd"
import "./components/assistant"

ShellRoot {
    property var frameScreens: {
        var monitors = ConfigService.sidebarMonitors
        if (!monitors || monitors.length === 0) return Quickshell.screens
        var result = []
        for (var i = 0; i < Quickshell.screens.length; i++) {
            if (monitors.indexOf(Quickshell.screens[i].name) !== -1)
                result.push(Quickshell.screens[i])
        }
        return result
    }

    Variants {
        model: frameScreens
        delegate: TopBar { required property var modelData; screen: modelData }
    }
    NotificationToast {}
    NotificationCenter {}
    AssistantPanel {}
    OSD {}

    AppLauncher { id: launcher }

    IpcHandler {
        target: "toggle"
        function handle(panel: string) {
            if (panel === "launcher") {
                if (launcher.visible) launcher.close()
                else launcher.open()
            } else {
                PanelManager.toggle(panel)
            }
        }
        // Dedicated function (not an optional 2nd param on handle()) —
        // Quickshell's IPC marshaling requires every exposed function
        // param to have a concrete type; an untyped/optional `tab` param
        // showed up as QVariant and got rejected ("cannot be used across
        // IPC"), and a typed-but-required 2nd param would break every
        // existing 1-arg `handle <panel>` call site (launcher,
        // notificationCenter, plain dashboard toggle).
        function openTab(tab: string) {
            PanelManager.openTab(tab)
        }
    }

    IpcHandler {
        target: "osd"
        function handle(type: string) {
            OsdService.show(type)
        }
    }
}
