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

    // ================= Overview tab ========================================
    // Calendar leads as the centerpiece (left, ~60% width), Clock + Weather
    // stack as smaller companion cards (right, ~40% width). No primary CTA —
    // pure glance. See .ui-craft/spec.md -> "Surface: Overview".
Item {
        id: ovRoot

        readonly property var _today: new Date()

        // Drives Dashboard's per-tab panel height (root.currentTabBodyHeight)
        // — calendarCard's content is the only thing with a real natural
        // size here, so the tab (and companion column, via fillHeight below)
        // sizes to it rather than the other way around.
        implicitHeight: calendarCard.implicitHeight

        RowLayout {
            anchors.fill: parent
            spacing: Tokens.spaceLg

            // ---- Calendar (centerpiece) ----------------------------------
            // Plain Item, not GlassCard — the host panel already supplies one
            // frosted surface; a second same-tint fill+border here just
            // dimmed the tint further and doubled the border ring. Regions
            // are separated by hairlines/dividers instead of nested glass.
            Item {
                id: calendarCard

                Layout.preferredWidth: ovRoot.width * 0.6
                // Not fillHeight — this card's implicit (content) height is
                // what drives the tab's height (see ovRoot.implicitHeight
                // above); the companion column fills to match it instead.
                implicitHeight: calContent.implicitHeight + Tokens.spaceLg * 2

                readonly property var monthNames: [
                    "January", "February", "March", "April", "May", "June",
                    "July", "August", "September", "October", "November", "December"
                ]

                property int displayYear:  ovRoot._today.getFullYear()
                property int displayMonth: ovRoot._today.getMonth()

                readonly property bool isCurrentMonth:
                    displayYear === ovRoot._today.getFullYear() && displayMonth === ovRoot._today.getMonth()

                readonly property int firstDayOfMonth: new Date(displayYear, displayMonth, 1).getDay()
                readonly property int daysInMonth:     new Date(displayYear, displayMonth + 1, 0).getDate()

                function navigate(direction) {
                    var newMonth = displayMonth + direction
                    var newYear  = displayYear
                    if (newMonth < 0)       { newMonth = 11; newYear -= 1 }
                    else if (newMonth > 11) { newMonth = 0;  newYear += 1 }

                    dayGrid.slideBehaviorEnabled = false
                    dayGrid.x = -direction * gridClip.width
                    displayMonth = newMonth
                    displayYear  = newYear
                    dayGrid.slideBehaviorEnabled = !ConfigService.reduceMotion
                    dayGrid.x = 0
                }

                function goToToday() {
                    displayYear  = ovRoot._today.getFullYear()
                    displayMonth = ovRoot._today.getMonth()
                }

                ColumnLayout {
                    id: calContent
                    anchors.fill: parent
                    anchors.margins: Tokens.spaceLg
                    spacing: Tokens.spaceMd

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spaceSm

                        GlassButton {
                            width: 28; height: 28
                            activeFocusOnTab: true
                            active: prevMouse.containsMouse || activeFocus
                            Text {
                                anchors.centerIn: parent
                                text: "‹"
                                font.family: ThemeManager.active.fontUi
                                font.pixelSize: Tokens.textLg
                                color: ThemeManager.active.text
                            }
                            MouseArea {
                                id: prevMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calendarCard.navigate(-1)
                            }
                            Keys.onReturnPressed: calendarCard.navigate(-1)
                            Keys.onSpacePressed:  calendarCard.navigate(-1)
                        }

                        GlassButton {
                            width: 28; height: 28
                            activeFocusOnTab: true
                            active: nextMouse.containsMouse || activeFocus
                            Text {
                                anchors.centerIn: parent
                                text: "›"
                                font.family: ThemeManager.active.fontUi
                                font.pixelSize: Tokens.textLg
                                color: ThemeManager.active.text
                            }
                            MouseArea {
                                id: nextMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calendarCard.navigate(1)
                            }
                            Keys.onReturnPressed: calendarCard.navigate(1)
                            Keys.onSpacePressed:  calendarCard.navigate(1)
                        }

                        Text {
                            text: calendarCard.monthNames[calendarCard.displayMonth] + " " + calendarCard.displayYear
                            font.family: ThemeManager.active.fontUi
                            font.pixelSize: Tokens.typeHeadline
                            font.bold: true
                            color: ThemeManager.active.text
                        }

                        Item { Layout.fillWidth: true }

                        GlassButton {
                            visible: !calendarCard.isCurrentMonth
                            width: 64; height: 26
                            activeFocusOnTab: true
                            active: todayMouse.containsMouse || activeFocus
                            Text {
                                anchors.centerIn: parent
                                text: "Today"
                                font.family: ThemeManager.active.fontUi
                                font.pixelSize: Tokens.textXs
                                color: ThemeManager.active.text
                            }
                            MouseArea {
                                id: todayMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calendarCard.goToToday()
                            }
                            Keys.onReturnPressed: calendarCard.goToToday()
                            Keys.onSpacePressed:  calendarCard.goToToday()
                        }
                    }

                    Divider {}

                    Grid {
                        id: weekdayHeader
                        Layout.fillWidth: true
                        columns: 7

                        Repeater {
                            model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                            delegate: Text {
                                required property string modelData
                                width: weekdayHeader.width / 7
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                font.family: ThemeManager.active.fontUi
                                font.pixelSize: Tokens.text2xs
                                font.bold: true
                                color: ThemeManager.active.subtext
                            }
                        }
                    }

                    Item {
                        id: gridClip
                        Layout.fillWidth: true
                        // Fixed to the grid's actual max size (6 rows) instead
                        // of fillHeight — was stretching to consume the rest
                        // of the card, leaving everything below the last row
                        // as unstyled dead space.
                        Layout.preferredHeight: 6 * 34 + 5 * Tokens.spaceXs
                        clip: true

                        Grid {
                            id: dayGrid

                            property bool slideBehaviorEnabled: !ConfigService.reduceMotion

                            columns: 7
                            rowSpacing: Tokens.spaceXs
                            width: gridClip.width
                            x: 0

                            Behavior on x {
                                enabled: dayGrid.slideBehaviorEnabled
                                NumberAnimation { duration: Tokens.durationNormal; easing.type: Tokens.easeOut }
                            }

                            Repeater {
                                model: calendarCard.firstDayOfMonth + calendarCard.daysInMonth

                                delegate: Item {
                                    id: dayCell
                                    required property int index

                                    readonly property int dayNum: index - calendarCard.firstDayOfMonth + 1
                                    readonly property bool isToday: dayNum >= 1 &&
                                        new Date(calendarCard.displayYear, calendarCard.displayMonth, dayNum).toDateString()
                                            === ovRoot._today.toDateString()

                                    width: dayGrid.width / 7
                                    height: 34

                                    Rectangle {
                                        visible: dayCell.isToday
                                        anchors.centerIn: parent
                                        width: 34; height: 34
                                        radius: 17
                                        color: ThemeManager.active.accent
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: dayCell.dayNum >= 1
                                        text: dayCell.dayNum
                                        font.family: ThemeManager.active.fontUi
                                        font.pixelSize: Tokens.typeBody
                                        color: dayCell.isToday ? ThemeManager.active.base : ThemeManager.active.text
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Accent divider — one visible thread tying the panel's two
            // regions together, instead of relying on a second card border.
            Rectangle {
                Layout.fillHeight: true
                Layout.topMargin: Tokens.spaceLg
                Layout.bottomMargin: Tokens.spaceLg
                width: 1
                color: ThemeManager.active.accent
                opacity: 0.35
            }

            // ---- Clock + Weather (companions) ------------------------------
            ColumnLayout {
                Layout.preferredWidth: ovRoot.width * 0.4
                Layout.fillHeight: true
                spacing: Tokens.spaceLg

                Item {
                    id: clockCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    property var now: new Date()

                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: clockCard.now = new Date()
                    }

                    // Date dropped — the calendar sitting right next to this
                    // already shows it, no need to repeat.
                    Text {
                        anchors.centerIn: parent
                        text: {
                            var h = clockCard.now.getHours()
                            var m = clockCard.now.getMinutes().toString().padStart(2, "0")
                            if (ConfigService.clockFormat === "12h") {
                                var ampm = h >= 12 ? "PM" : "AM"
                                h = h % 12 || 12
                                return h + ":" + m + " " + ampm
                            }
                            return h.toString().padStart(2, "0") + ":" + m
                        }
                        font.family: ThemeManager.active.fontMono
                        font.pixelSize: Tokens.typeDisplay
                        font.bold: true
                        color: ThemeManager.active.text
                    }
                }

                Divider {}

                Item {
                    id: weatherCard
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Tokens.spaceMd

                        Text {
                            text: WeatherService.error ? "⊘" : (WeatherService.loading ? "…" : WeatherService.icon)
                            font.family: ThemeManager.active.fontMono
                            font.pixelSize: Tokens.text3xl
                            color: WeatherService.error ? ThemeManager.active.subtext : ThemeManager.active.text
                        }

                        ColumnLayout {
                            spacing: 2

                            Text {
                                text: WeatherService.error
                                    ? "—°"
                                    : (WeatherService.loading ? "Loading…" : WeatherService.temperature)
                                font.family: ThemeManager.active.fontUi
                                font.pixelSize: Tokens.typeHeadline
                                font.bold: true
                                color: WeatherService.error ? ThemeManager.active.subtext : ThemeManager.active.text
                            }

                            Text {
                                text: WeatherService.error
                                    ? "Weather unavailable"
                                    : (WeatherService.loading ? "" : WeatherService.condition)
                                font.family: ThemeManager.active.fontUi
                                font.pixelSize: Tokens.typeBody
                                color: ThemeManager.active.subtext
                            }
                        }
                    }
                }
            }
        }
    }

