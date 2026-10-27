import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

// Today's Stuyvesant day plan: block letter, what the day is, and the bell
// schedule for its schedule type. Mirrors the Sophomore Caucus home banner:
// identity on the left, periods on the right, with the live period picked out.
AbstractBackgroundWidget {
    id: root
    configEntryName: "stuySchedule"
    hoverEnabled: true

    // Drag the corner handle narrower to drop to the compact card, which keeps the
    // block letter and the day's wording but no bell table.
    property string sizeMode: root.configEntry.sizeMode ?? "3x2"
    readonly property bool withBell: root.sizeMode === "3x2"
    property real widgetWidth: root.withBell ? root.spanWidth(3) : root.spanWidth(2)
    property real widgetHeight: root.spanHeight(2)
    implicitWidth: widgetWidth
    implicitHeight: widgetHeight

    Behavior on widgetWidth {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    function modeForWidth(value) {
        return value < (root.spanWidth(2) + root.spanWidth(3)) / 2 ? "2x2" : "3x2";
    }

    property string selectedDate: StuyCalendar.todayKey
    readonly property var entry: StuyCalendar.entryFor(root.selectedDate)
    readonly property var rows: StuyCalendar.bellRows(root.entry?.scheduleType)
    readonly property var columnA: root.rows.slice(0, Math.ceil(root.rows.length / 2))
    readonly property var columnB: root.rows.slice(Math.ceil(root.rows.length / 2))
    readonly property bool isToday: root.selectedDate === StuyCalendar.todayKey
    readonly property int nowMinutes: DateTime.hour24 * 60 + Number(DateTime.minuteStr)
    readonly property int currentIndex: root.isToday ? StuyCalendar.currentRowIndex(root.rows, root.nowMinutes) : -1

    function step(delta) {
        const next = StuyCalendar.addDays(root.selectedDate, delta);
        if (next < StuyCalendar.minDate || next > StuyCalendar.maxDate) return;
        root.selectedDate = next;
    }

    component NavButton: Rectangle {
        id: button
        property string icon
        signal activated()

        implicitWidth: 22
        implicitHeight: 22
        radius: Appearance.rounding.full
        color: buttonArea.containsMouse
            ? ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.88)
            : "transparent"

        MaterialSymbol {
            anchors.centerIn: parent
            text: button.icon
            iconSize: 15
            color: Appearance.colors.colOnPrimaryContainer
            opacity: 0.75
        }
        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.activated()
        }
    }

    component TodayChip: Rectangle {
        id: chip
        signal activated()

        implicitWidth: chipText.implicitWidth + 14
        implicitHeight: 18
        radius: 9
        color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, chipArea.containsMouse ? 0.82 : 0.88)
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        StyledText {
            id: chipText
            anchors.centerIn: parent
            text: "Today"
            font.pixelSize: 10
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnPrimaryContainer
        }
        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.activated()
        }
    }

    component PeriodRow: Rectangle {
        id: periodRow
        property var rowData
        property bool highlighted: false

        Layout.fillWidth: true
        implicitHeight: 16
        radius: 5
        color: periodRow.highlighted
            ? ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.88)
            : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 2
            spacing: 4

            Rectangle {
                implicitWidth: 14
                implicitHeight: 14
                radius: 7
                color: periodRow.highlighted
                    ? Appearance.colors.colPrimary
                    : ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.88)

                StyledText {
                    anchors.centerIn: parent
                    text: periodRow.rowData?.label ?? ""
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    color: periodRow.highlighted
                        ? Appearance.colors.colOnPrimary
                        : Appearance.colors.colOnPrimaryContainer
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: (periodRow.rowData?.start ?? "") + "–" + (periodRow.rowData?.end ?? "")
                font.pixelSize: 10
                color: periodRow.highlighted
                    ? Appearance.colors.colOnPrimaryContainer
                    : ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.25)
                elide: Text.ElideRight
            }
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Appearance.rounding?.verylarge ?? 30
        color: Appearance.colors.colPrimaryContainer

        StyledRectangularShadow {
            target: card
            z: -2
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: 14
            }
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: StuyCalendar.formatDate(root.selectedDate)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnPrimaryContainer
                    elide: Text.ElideRight
                }

                TodayChip {
                    visible: !root.isToday
                    onActivated: root.selectedDate = StuyCalendar.todayKey
                }
                NavButton {
                    icon: "chevron_left"
                    onActivated: root.step(-1)
                }
                NavButton {
                    icon: "chevron_right"
                    onActivated: root.step(1)
                }
            }

            // Compact card: identity only, centered.
            ColumnLayout {
                visible: !root.withBell
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Item { Layout.fillHeight: true }

                StyledText {
                    text: root.entry?.block ?? "--"
                    font.pixelSize: 52
                    font.weight: Font.Bold
                    color: StuyCalendar.blockColor(root.entry?.block)
                }
                RowLayout {
                    spacing: 4
                    StyledText {
                        text: StuyCalendar.weekdayName(root.selectedDate)
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.7
                    }
                    StyledText {
                        visible: root.isToday
                        text: "· Today"
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: StuyCalendar.palette.green
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    Layout.topMargin: 3
                    text: root.entry?.sourceWording ?? "Outside calendar range"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnPrimaryContainer
                    wrapMode: Text.WordWrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    visible: root.rows.length > 0
                    text: (root.entry?.scheduleType ?? "") + " schedule · " + root.rows.length + " periods"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnPrimaryContainer
                    opacity: 0.55
                    elide: Text.ElideRight
                }

                Item { Layout.fillHeight: true }
            }

            RowLayout {
                visible: root.withBell
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

                // Identity: block letter, weekday, what the day is.
                ColumnLayout {
                    Layout.preferredWidth: 118
                    Layout.fillHeight: true
                    spacing: 0

                    StyledText {
                        text: root.entry?.block ?? "--"
                        font.pixelSize: 46
                        font.weight: Font.Bold
                        color: StuyCalendar.blockColor(root.entry?.block)
                    }

                    RowLayout {
                        spacing: 4
                        StyledText {
                            text: StuyCalendar.weekdayName(root.selectedDate)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.7
                        }
                        StyledText {
                            visible: root.isToday
                            text: "· Today"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            color: StuyCalendar.palette.green
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        text: root.entry?.sourceWording ?? "Outside calendar range"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnPrimaryContainer
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }

                    Item { Layout.fillHeight: true }
                }

                // Bell schedule for that day's schedule type.
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        StyledText {
                            text: "BELL SCHEDULE"
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.7
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.55
                        }
                        Item { Layout.fillWidth: true }
                        StyledText {
                            text: root.entry?.scheduleType ?? ""
                            font.pixelSize: 10
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.7
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Repeater {
                                model: root.columnA
                                delegate: PeriodRow {
                                    required property int index
                                    rowData: root.columnA[index]
                                    highlighted: index === root.currentIndex
                                }
                            }
                            Item { Layout.fillHeight: true }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Repeater {
                                model: root.columnB
                                delegate: PeriodRow {
                                    required property int index
                                    rowData: root.columnB[index]
                                    highlighted: root.columnA.length + index === root.currentIndex
                                }
                            }
                            Item { Layout.fillHeight: true }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.rows.length === 0
                        text: root.entry
                            ? StuyCalendar.categoryLabel(root.entry.category) + " · no scheduled periods"
                            : "No school calendar data"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.6
                        wrapMode: Text.WordWrap
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }

        // Bottom-right handle: drag it sideways to switch card size. Only visible
        // while the card is hovered, so it does not clutter the desktop.
        Rectangle {
            id: resizeHandle
            width: 16
            height: 16
            radius: 4
            color: Appearance.colors.colOnPrimaryContainer
            anchors {
                right: card.right
                bottom: card.bottom
                margins: 4
            }
            opacity: (root.containsMouse || resizeArea.containsMouse || resizeArea.pressed) ? 0.5 : 0
            visible: opacity > 0 && !Config.options.background.widgetsLocked

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }

            MouseArea {
                id: resizeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor
                preventStealing: true

                property real startWidth: 0
                property real startX: 0

                onPressed: (mouse) => {
                    startWidth = root.widgetWidth
                    startX = mapToItem(null, mouse.x, mouse.y).x
                }
                onPositionChanged: (mouse) => {
                    if (!pressed) return
                    const globalX = mapToItem(null, mouse.x, mouse.y).x
                    root.sizeMode = root.modeForWidth(startWidth + (globalX - startX))
                }
                onReleased: {
                    root.configEntry.sizeMode = root.sizeMode
                }
            }
        }
    }
}
