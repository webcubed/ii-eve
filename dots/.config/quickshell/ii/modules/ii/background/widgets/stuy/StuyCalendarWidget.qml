import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

// The Sophomore Caucus events-page calendar, on the desktop: a month grid of the
// school year with A/B block days, category dots (no school, exams, special,
// last day) and the selected day's wording. Days are clickable; the month
// navigates like the site's calendar.
AbstractBackgroundWidget {
    id: root
    configEntryName: "stuyCalendar"
    hoverEnabled: true

    // A month grid plus a day detail needs three rows at this grid pitch; two rows
    // squeezed the cells and pushed the legend off the card. Dragging the corner
    // handle narrower drops to the grid-only card.
    property string sizeMode: root.configEntry.sizeMode ?? "3x3"
    readonly property bool withDetail: root.sizeMode === "3x3"
    property real widgetWidth: root.withDetail ? root.spanWidth(3) : root.spanWidth(2)
    property real widgetHeight: root.withDetail ? root.spanHeight(3) : root.spanHeight(2)
    // The month grid sizes its own tiles from the card (see gridSlot) and turns the
    // leftover into spacing, so a roomier card means more air between days rather
    // than bigger day tiles.
    readonly property real cellMaxWidth: root.withDetail ? 34 : 32
    readonly property real cellMaxHeight: root.withDetail ? 34 : 22
    readonly property real cellBaseSpacing: 9
    readonly property real cellMaxSpacing: 14
    implicitWidth: widgetWidth
    implicitHeight: widgetHeight

    Behavior on widgetWidth {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }
    Behavior on widgetHeight {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    function modeForWidth(value) {
        return value < (root.spanWidth(2) + root.spanWidth(3)) / 2 ? "2x2" : "3x3";
    }

    // How many week rows the month actually uses (five or six), so the grid can size
    // its tiles to the rows it draws instead of always assuming six.
    function usedWeekRows(cells) {
        let last = -1;
        for (let i = 0; i < cells.length; ++i) if (cells[i] !== null) last = i;
        return Math.max(1, Math.floor(last / 7) + 1);
    }

    property int cursorYear: new Date().getFullYear()
    property int cursorMonth: new Date().getMonth()
    property string selectedDate: StuyCalendar.todayKey

    readonly property var cells: StuyCalendar.monthGrid(root.cursorYear, root.cursorMonth)
    readonly property var selectedEntry: StuyCalendar.entryFor(root.selectedDate)
    readonly property var todayParts: StuyCalendar.parseKey(StuyCalendar.todayKey)
    readonly property bool showingCurrentMonth: root.cursorYear === root.todayParts.getFullYear()
        && root.cursorMonth === root.todayParts.getMonth()

    function moveMonth(delta) {
        const date = new Date(root.cursorYear, root.cursorMonth + delta, 1);
        root.cursorYear = date.getFullYear();
        root.cursorMonth = date.getMonth();
    }
    function jumpToToday() {
        root.cursorYear = root.todayParts.getFullYear();
        root.cursorMonth = root.todayParts.getMonth();
        root.selectedDate = StuyCalendar.todayKey;
    }

    component NavButton: Rectangle {
        id: button
        property string icon
        signal activated()

        implicitWidth: 20
        implicitHeight: 20
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
                margins: 15
            }
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    text: StuyCalendar.monthNames[root.cursorMonth] + " " + root.cursorYear
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnPrimaryContainer
                }
                Item { Layout.fillWidth: true }

                Rectangle {
                    id: todayChip
                    visible: !root.showingCurrentMonth || root.selectedDate !== StuyCalendar.todayKey
                    implicitWidth: todayText.implicitWidth + 12
                    implicitHeight: 18
                    radius: 9
                    color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, todayArea.containsMouse ? 0.82 : 0.88)

                    Behavior on color {
                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                    }

                    StyledText {
                        id: todayText
                        anchors.centerIn: parent
                        text: "Today"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                    MouseArea {
                        id: todayArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.jumpToToday()
                    }
                }

                NavButton {
                    icon: "chevron_left"
                    onActivated: root.moveMonth(-1)
                }
                NavButton {
                    icon: "chevron_right"
                    onActivated: root.moveMonth(1)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Repeater {
                    model: StuyCalendar.shortWeekdayNames.length
                    delegate: StyledText {
                        required property int index
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: StuyCalendar.shortWeekdayNames[index]
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.5
                    }
                }
            }

            Item {
                id: gridSlot
                Layout.fillWidth: true
                Layout.fillHeight: true

                // The tiles are sized here instead of by the layout: GridLayout stretched
                // them to fill the card, which made the days large and the gutters thin.
                // Tiles stay capped and spread out; a month that only spans five weeks
                // keeps the same tile size as a six-week one and centres its block
                // instead of stretching the days to fill the card.
                readonly property int weekCount: root.usedWeekRows(root.cells)
                readonly property real cellWidth: Math.min(root.cellMaxWidth, Math.max(14, (width - 6 * root.cellBaseSpacing) / 7))
                readonly property real cellHeight: Math.max(14, Math.min(root.cellMaxHeight, (height - (weekCount - 1) * root.cellBaseSpacing) / weekCount))
                readonly property real columnSpacing: Math.max(2, (width - 7 * cellWidth) / 6)
                readonly property real rowSpacing: Math.max(2, weekCount > 1
                    ? Math.min(root.cellMaxSpacing, (height - weekCount * cellHeight) / (weekCount - 1))
                    : 0)
                readonly property real gridHeight: weekCount * cellHeight + (weekCount - 1) * rowSpacing

                Grid {
                    columns: 7
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: gridSlot.width
                    height: gridSlot.gridHeight
                    columnSpacing: gridSlot.columnSpacing
                    rowSpacing: gridSlot.rowSpacing

                    Repeater {
                        model: root.cells
                        delegate: Rectangle {
                            id: dayCell
                            required property var modelData

                            readonly property var cellKey: dayCell.modelData ? dayCell.modelData.key : ""
                            readonly property var dayEntry: dayCell.cellKey ? StuyCalendar.entryFor(dayCell.cellKey) : null
                            readonly property string dot: dayCell.dayEntry ? StuyCalendar.categoryDot(dayCell.dayEntry.category) : ""
                            readonly property bool isToday: dayCell.cellKey === StuyCalendar.todayKey
                            readonly property bool isSelected: dayCell.cellKey === root.selectedDate
                            readonly property bool isWeekend: dayCell.modelData
                                ? (StuyCalendar.parseKey(dayCell.cellKey).getDay() === 0 || StuyCalendar.parseKey(dayCell.cellKey).getDay() === 6)
                                : false

                            width: gridSlot.cellWidth
                            height: gridSlot.cellHeight
                            radius: 6
                            visible: dayCell.modelData !== null
                            // A faint surface per day keeps the month reading as a grid of
                            // days rather than numbers floating in empty card.
                            color: dayCell.isSelected
                                ? ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.84)
                                : dayCell.isToday
                                    ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.8)
                                    : ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, cellArea.containsMouse ? 0.88 : 0.94)

                            Column {
                                anchors.centerIn: parent
                                spacing: 0

                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: dayCell.modelData ? dayCell.modelData.day : ""
                                    font.pixelSize: root.withDetail ? 12 : 11
                                    font.weight: dayCell.isToday || dayCell.isSelected ? Font.DemiBold : Font.Normal
                                    color: Appearance.colors.colOnPrimaryContainer
                                    opacity: dayCell.isWeekend ? 0.55 : 1
                                }

                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: dayCell.dayEntry?.block ?? ""
                                    font.pixelSize: root.withDetail ? 8 : 7
                                    font.weight: Font.Bold
                                    color: StuyCalendar.blockColor(dayCell.dayEntry?.block)
                                    opacity: dayCell.isWeekend ? 0.6 : 1
                                }
                            }

                            Rectangle {
                                visible: dayCell.dot !== ""
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.topMargin: 3
                                anchors.rightMargin: 3
                                width: 4
                                height: 4
                                radius: 2
                                color: dayCell.dot
                            }

                            MouseArea {
                                id: cellArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedDate = dayCell.cellKey
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                visible: root.withDetail
                spacing: 6

                StyledText {
                    text: root.selectedEntry?.block ?? "--"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: StuyCalendar.blockColor(root.selectedEntry?.block)
                }
                StyledText {
                    Layout.fillWidth: true
                    text: {
                        if (!root.selectedEntry) return "Outside calendar range";
                        const label = StuyCalendar.categoryLabel(root.selectedEntry.category);
                        return root.selectedEntry.sourceWording && root.selectedEntry.sourceWording !== label
                            ? label + " · " + root.selectedEntry.sourceWording
                            : label;
                    }
                    font.pixelSize: 10
                    color: Appearance.colors.colOnPrimaryContainer
                    opacity: 0.75
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 1
                visible: root.withDetail
                spacing: 9

                RowLayout {
                    spacing: 2
                    StyledText {
                        text: "A"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: StuyCalendar.palette.red
                    }
                    StyledText {
                        text: "B"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: StuyCalendar.palette.blue
                    }
                    StyledText {
                        text: "blocks"
                        font.pixelSize: 9
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.55
                    }
                }

                Repeater {
                    model: [
                        { color: StuyCalendar.palette.red, label: "No school" },
                        { color: StuyCalendar.palette.yellow, label: "Exams" },
                        { color: StuyCalendar.palette.sapphire, label: "Special" },
                        { color: StuyCalendar.palette.green, label: "Last day" }
                    ]
                    delegate: RowLayout {
                        required property var modelData
                        spacing: 3
                        Rectangle {
                            width: 4
                            height: 4
                            radius: 2
                            color: modelData.color
                        }
                        StyledText {
                            text: modelData.label
                            font.pixelSize: 9
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.55
                        }
                    }
                }

                Item { Layout.fillWidth: true }
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
