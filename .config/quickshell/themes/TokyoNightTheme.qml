pragma Singleton
import QtQuick

QtObject {
    readonly property string name:         "tokyonight"
    readonly property bool   isDark:       true
    readonly property bool   blur:         true
    readonly property real   opacity:      1.0
    readonly property string wallpaperDir: "tokyonight"
    readonly property string fontUi:       "Inter"
    readonly property string fontMono:     "FiraCode Nerd Font"

    readonly property color base:    "#1A1B26"
    readonly property color overlay: "#24283B"

    readonly property color text:    "#C0CAF5"
    readonly property color subtext: "#8C95C9"

    readonly property color border:     "#3B4261"
    readonly property color accent:     "#7AA2F7"
    readonly property color accentAlt:  "#BB9AF7"
    readonly property color highlight:  "#2AC3DE"

    readonly property color success: "#9ECE6A"
    readonly property color warning: "#E0AF68"
    readonly property color error:   "#F7768E"
    readonly property color info:    "#2AC3DE"

    readonly property color metricCpu:  "#7AA2F7"
    readonly property color metricRam:  "#BB9AF7"
    readonly property color metricGpu:  "#F7768E"
    readonly property color metricNet:  "#9ECE6A"
    readonly property color metricDisk: "#E0AF68"

}
