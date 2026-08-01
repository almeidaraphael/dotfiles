pragma Singleton
import QtQuick
import Qt.labs.platform

QtObject {
    id: root

    property string activeTheme:         "dracula"
    property var    activeWallpapers:    ({})
    property var    sidebarMonitors:     []
    property string weatherLocation:     ""
    property string temperatureUnit:     "C"
    property string clockFormat:         "24h"
    property int    wallpaperInterval:   600
    property string wallpaperMode:       "random"
    property int    notificationTimeout: 3000
    property bool   reduceMotion:        false
    property string ollamaBaseUrl:         "http://127.0.0.1:11434"
    property string searxUrl:              "http://127.0.0.1:8890"
    property string embeddingModel:        "nomic-embed-text"
    property int    maxFolderAttachFiles:  40
    property string preferredModel:        ""

    // Runtime-only cache-bust counter for /etc/theme-assets/avatar.png —
    // not persisted (no load()/save() entry). Every consumer of that fixed
    // path binds its Image source to this so a fresh crop shows up
    // immediately instead of only after a Quickshell restart.
    property int avatarVersion: 0

    readonly property string configPath:   StandardPaths.writableLocation(
        StandardPaths.GenericConfigLocation) + "/quickshell/config.json"
    readonly property string homeDir:     StandardPaths.writableLocation(StandardPaths.HomeLocation)
    readonly property string picturesDir: StandardPaths.writableLocation(StandardPaths.PicturesLocation)

    Component.onCompleted: load()

    function load() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", configPath, false)
        xhr.send()
        if (xhr.status === 200 && xhr.responseText !== "") {
            var cfg = JSON.parse(xhr.responseText)
            if (cfg.activeTheme !== undefined)         activeTheme         = cfg.activeTheme
            if (cfg.activeWallpapers !== undefined)    activeWallpapers    = cfg.activeWallpapers
            if (cfg.sidebarMonitors !== undefined)     sidebarMonitors     = cfg.sidebarMonitors
            if (cfg.weatherLocation !== undefined)     weatherLocation     = cfg.weatherLocation
            if (cfg.temperatureUnit !== undefined)     temperatureUnit     = cfg.temperatureUnit
            if (cfg.clockFormat !== undefined)         clockFormat         = cfg.clockFormat
            if (cfg.wallpaperInterval !== undefined)   wallpaperInterval   = cfg.wallpaperInterval
            if (cfg.wallpaperMode !== undefined)       wallpaperMode       = cfg.wallpaperMode
            if (cfg.notificationTimeout !== undefined) notificationTimeout = cfg.notificationTimeout
            if (cfg.reduceMotion !== undefined)        reduceMotion        = cfg.reduceMotion
            if (cfg.ollamaBaseUrl !== undefined)        ollamaBaseUrl        = cfg.ollamaBaseUrl
            if (cfg.searxUrl !== undefined)             searxUrl              = cfg.searxUrl
            if (cfg.embeddingModel !== undefined)       embeddingModel        = cfg.embeddingModel
            if (cfg.maxFolderAttachFiles !== undefined) maxFolderAttachFiles  = cfg.maxFolderAttachFiles
            if (cfg.preferredModel !== undefined)       preferredModel        = cfg.preferredModel
        }
    }

    function save() {
        var cfg = {
            activeTheme:         activeTheme,
            activeWallpapers:    activeWallpapers,
            sidebarMonitors:     sidebarMonitors,
            weatherLocation:     weatherLocation,
            temperatureUnit:     temperatureUnit,
            clockFormat:         clockFormat,
            wallpaperInterval:   wallpaperInterval,
            wallpaperMode:       wallpaperMode,
            notificationTimeout: notificationTimeout,
            reduceMotion:        reduceMotion,
            ollamaBaseUrl:        ollamaBaseUrl,
            searxUrl:             searxUrl,
            embeddingModel:       embeddingModel,
            maxFolderAttachFiles: maxFolderAttachFiles,
            preferredModel:       preferredModel
        }
        var localPath = configPath.replace(/^file:\/\//, "")
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
        proc.command = ["bash", "-c", "printf '%s' \"$1\" > \"$2\"", "_",
                        JSON.stringify(cfg, null, 2), localPath]
        proc.running = true
    }
}
