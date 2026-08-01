pragma Singleton
import QtQuick

QtObject {
    readonly property string name:         "nord"
    readonly property bool   isDark:       true
    readonly property bool   blur:         true
    readonly property real   opacity:      1.0
    readonly property string wallpaperDir: "nord"
    readonly property string fontUi:       "Inter"
    readonly property string fontMono:     "FiraCode Nerd Font"

    // Nord canonical — nordtheme.com
    readonly property color base:    "#2E3440"  // nord0
    readonly property color overlay: "#3B4252"  // nord1

    readonly property color text:    "#ECEFF4"  // nord6
    readonly property color subtext: "#A0B2C6"

    readonly property color border:     "#4C566A"  // nord3
    readonly property color accent:     "#88C0D0"  // nord8
    readonly property color accentAlt:  "#81A1C1"  // nord9
    readonly property color highlight:  "#5E81AC"  // nord10

    readonly property color success: "#A3BE8C"  // nord14
    readonly property color warning: "#EBCB8B"  // nord13
    readonly property color error:   "#BF616A"  // nord11
    readonly property color info:    "#8FBCBB"  // nord7

    readonly property color metricCpu:  "#88C0D0"
    readonly property color metricRam:  "#81A1C1"
    readonly property color metricGpu:  "#BF616A"
    readonly property color metricNet:  "#A3BE8C"
    readonly property color metricDisk: "#EBCB8B"

}
