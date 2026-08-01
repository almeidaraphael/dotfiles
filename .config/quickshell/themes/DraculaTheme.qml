pragma Singleton
import QtQuick

QtObject {
    // draculatheme.com/spec — canonical values
    readonly property color base:      "#282A36"  // Background
    readonly property color overlay:   "#44475A"  // Current Line

    readonly property color text:      "#F8F8F2"  // Foreground
    readonly property color subtext:   "#9AA5CE"  // Comment (brightened for readability)

    readonly property color border:    "#6272A4"  // Comment
    readonly property color accent:    "#BD93F9"  // Purple
    readonly property color accentAlt: "#FF79C6"  // Pink
    readonly property color highlight: "#8BE9FD"  // Cyan

    readonly property color success:   "#50FA7B"  // Green
    readonly property color warning:   "#FFB86C"  // Orange
    readonly property color error:     "#FF5555"  // Red
    readonly property color info:      "#8BE9FD"  // Cyan

    readonly property color metricCpu:  "#FF5555"  // Red
    readonly property color metricRam:  "#BD93F9"  // Purple
    readonly property color metricGpu:  "#50FA7B"  // Green
    readonly property color metricNet:  "#8BE9FD"  // Cyan
    readonly property color metricDisk: "#FFB86C"  // Orange

    readonly property string fontUi:   "Inter"
    readonly property string fontMono: "FiraCode Nerd Font"

    readonly property string name:         "dracula"
    readonly property string wallpaperDir: "dracula"
    readonly property bool isDark:         true
    readonly property bool blur:           true
    readonly property real opacity:        1.0
}
