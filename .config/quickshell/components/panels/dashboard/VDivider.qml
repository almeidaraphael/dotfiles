import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Controls
import Qt.labs.platform as Labs
import "../../.."
import "../../shared"

// Neutral hairline seam for the tab strip — deliberately not accent-colored
// (unlike Overview's calendar/companion divider): with 5 tabs, an
// accent-tinted seam between each one would burn the accent budget on
// structure instead of state. Accent stays reserved for the active-tab
// underline in tabRow, matching this file's "one accent, one job" pattern.
Rectangle {
    Layout.fillHeight: true
    width: 1
    color: ThemeManager.active.border
    opacity: 0.4
}
