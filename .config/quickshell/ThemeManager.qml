pragma Singleton
import QtQuick
import "./themes"

QtObject {
    id: root

    property var active: DraculaTheme

    Component.onCompleted: setTheme(ConfigService.activeTheme)

    onActiveChanged: _syncHyprland()

    // Hyprland 0.56's Lua config rejected `hyprctl keyword` ("can't work
    // with non-legacy parsers") — live config changes now go through
    // `hyprctl eval` calling hl.config() with a Lua table literal instead
    // of the old "category:field value" string pairs.
    function _hyprConfig(luaTable) {
        var p = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
        p.command = ["hyprctl", "eval", "hl.config(" + luaTable + ")"]
        p.startDetached()
    }

    function _rgba(c) {
        function hex2(n) { return ("00" + Math.round(n * 255).toString(16)).slice(-2) }
        return "rgba(" + hex2(c.r) + hex2(c.g) + hex2(c.b) + "ff)"
    }

    function _syncHyprland() {
        var activeBorder = '{ colors = {"' + _rgba(active.accent) + '", "' + _rgba(active.accentAlt) + '"}, angle = 45 }'
        var inactiveBorder = '"' + _rgba(active.overlay) + '"'
        _hyprConfig('{ general = { ["col.active_border"] = ' + activeBorder
            + ', ["col.inactive_border"] = ' + inactiveBorder + ' } }')
    }

    function _applyExternalThemes(name) {
        ProcessRunner.run(["/bin/sh", "-c", "exec $HOME/.local/bin/theme-apply.sh " + name], {
            appName: "Theme",
            onFailureSummary: "Couldn't switch theme"
        })
    }

    function setTheme(name) {
        switch (name) {
            case "dracula":    active = DraculaTheme;    break
            case "tokyonight": active = TokyoNightTheme; break
            case "nord":       active = NordTheme;       break
            default:           active = DraculaTheme;    break
        }
        ConfigService.activeTheme = name
        ConfigService.save()
        _applyExternalThemes(name)
    }
}
