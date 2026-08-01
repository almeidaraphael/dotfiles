pragma Singleton
import QtQuick

QtObject {
    // Surfaces
    property color base:      "#000000"
    property color overlay:   "#111111"

    // Text
    property color text:      "#ffffff"
    property color subtext:   "#AAAAAA"

    // Borders + Accents
    property color border:    "#333333"
    property color accent:    "#ffffff"
    property color accentAlt: "#cccccc"
    property color highlight: "#aaaaaa"

    // Status
    property color success:   "#00ff00"
    property color warning:   "#ffaa00"
    property color error:     "#ff0000"
    property color info:      "#00aaff"

    // Performance metrics
    property color metricCpu:  "#00aaff"
    property color metricRam:  "#00ff00"
    property color metricGpu:  "#aa00ff"
    property color metricNet:  "#ff00aa"
    property color metricDisk: "#ffaa00"

    // Fonts
    property string fontUi:   "Inter"
    property string fontMono: "FiraCode Nerd Font"

    // Metadata
    property string name:         "base"
    property string wallpaperDir: ""
    property bool isDark:         true
    property bool blur:           false
    property real opacity:        1.0
}
