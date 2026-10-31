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
// last day) and the selected day's wording. Clicking a day previews it in the strip
// under the grid; the wording line itself opens the full entry. The month navigates
// like the site's calendar.
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
    // The month grid sizes its own tiles from the card (see gridSlot). The tiles get
    // the room first and the gutters take what is left, so the days read as the
    // calendar's content instead of small squares floating in empty card.
    readonly property real cellMaxWidth: 38
    readonly property real cellMaxHeight: root.withDetail ? 38 : 22
    readonly property real cellBaseSpacing: 8
    readonly property real cellMaxSpacing: 14
    // The site sets its day numbers and block letters in a rounded face; Google
    // Sans Rounded is that design with the roundness axis pinned, and it ships
    // with the shell's fonts.
    readonly property string dayFontFamily: "Google Sans Rounded"
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

    // Start on today's month through todayParts rather than new Date() once at
    // construction. Until the user navigates, the binding keeps following the clock,
    // so midnight on the 1st carries the grid into the new month instead of leaving
    // it on the month that just ended.
    property int cursorYear: root.todayParts.getFullYear()
    property int cursorMonth: root.todayParts.getMonth()
    property string selectedDate: StuyCalendar.todayKey

    // The day whose whole entry is open over the card, "" when the sheet is closed.
    // The strip under the grid gets one line, so anything the school wrote at length
    // (special schedules especially) ends in an ellipsis with no way to read it; the
    // sheet is that way, and its arrows walk day to day instead of making the reader
    // close it, click the next cell and open it again.
    property string detailDate: ""
    readonly property var detailEntry: root.detailDate !== "" ? StuyCalendar.entryFor(root.detailDate) : null
    readonly property string detailTitle: root.detailDate === ""
        ? ""
        : StuyCalendar.weekdayName(root.detailDate) + ", " + StuyCalendar.formatDate(root.detailDate)

    function openDetail(key) {
        root.selectedDate = key;
        root.detailDate = key;
    }
    function shiftDetail(delta) {
        if (root.detailDate === "") return;
        const next = StuyCalendar.addDays(root.detailDate, delta);
        if (next < StuyCalendar.minDate || next > StuyCalendar.maxDate) return;
        root.openDetail(next);
    }

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
                // Seven equal shares and no gaps: the same division the day grid slots
                // use below, so every weekday label sits over its own column.
                spacing: 0
                Repeater {
                    model: StuyCalendar.shortWeekdayNames.length
                    delegate: StyledText {
                        required property int index
                        Layout.fillWidth: true
                        // fillWidth alone hands each label a share proportional to its
                        // own text width, so the seven columns came out uneven — "Thu"
                        // landed 21px right of its tiles on a 402px card and 30px on a
                        // 592px one, which is what put the 1st between Wed and Thu.
                        // Identical preferred widths make the seven shares identical;
                        // measured centres then match the tile slots to a fifth of a pixel.
                        Layout.preferredWidth: 0
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
                // Seven equal column slots, the same division the weekday labels above
                // use. Sizing the tiles from the gaps instead (a narrower tile spread
                // back out to the full width) stretched the pitch past a slot, so while
                // the middle days stayed put the outer ones crept away from their
                // labels. A seventh of the width, tile centred inside it, lines up.
                readonly property real slotWidth: width / 7
                readonly property real cellWidth: Math.min(root.cellMaxWidth, Math.max(14, slotWidth - root.cellBaseSpacing))
                readonly property real cellHeight: Math.max(14, Math.min(root.cellMaxHeight, (height - (weekCount - 1) * root.cellBaseSpacing) / weekCount))
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
                    columnSpacing: 0
                    rowSpacing: gridSlot.rowSpacing

                    Repeater {
                        model: root.cells
                        // One delegate per column slot, with the tile centred inside it.
                        delegate: Item {
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

                            width: gridSlot.slotWidth
                            height: gridSlot.cellHeight
                            // The month's leading/trailing blanks have to keep their slot:
                            // a positioner skips invisible items, which was pulling every
                            // day four columns left in October (the 1st is a Thursday, and
                            // it was landing under Sunday). Fade them out instead.
                            opacity: dayCell.modelData !== null ? 1 : 0

                            Rectangle {
                                id: dayBox
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: gridSlot.cellWidth
                                height: parent.height
                                radius: 8
                                // Like the site's cells: nothing but the day until the
                                // pointer is on it, a filled surface once it is the
                                // selected day, and an inset ring on today whether or not
                                // it is selected.
                                color: dayCell.isSelected
                                    ? ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, cellArea.containsMouse ? 0.8 : 0.84)
                                    : cellArea.containsMouse
                                        ? ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.89)
                                        : "transparent"
                                border.width: dayCell.isToday ? 2 : 0
                                border.color: Appearance.colors.colPrimary

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 0

                                    StyledText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: dayCell.modelData ? dayCell.modelData.day : ""
                                        font.family: root.dayFontFamily
                                        font.pixelSize: root.withDetail ? 13 : 11
                                        font.variableAxes: ({ "wght": dayCell.isToday || dayCell.isSelected ? 550 : 450 })
                                        color: Appearance.colors.colOnPrimaryContainer
                                        opacity: dayCell.isWeekend ? 0.55 : 1
                                    }

                                    // The site keeps the category dot and the block letter on
                                    // one line under the number, rather than tucking the dot
                                    // into a corner where it competes with the day.
                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 3
                                        visible: dayCell.dot !== "" || (dayCell.dayEntry?.block ?? "") !== ""

                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: dayCell.dot !== ""
                                            width: 4
                                            height: 4
                                            radius: 2
                                            color: dayCell.dot
                                        }
                                        StyledText {
                                            text: dayCell.dayEntry?.block ?? ""
                                            font.family: StuyCalendar.blockFontFamily
                                            font.pixelSize: root.withDetail ? 9 : 7
                                            font.variableAxes: StuyCalendar.blockFontAxes
                                            color: StuyCalendar.blockColor(dayCell.dayEntry?.block)
                                            opacity: dayCell.isWeekend ? 0.6 : 1
                                        }
                                    }
                                }

                                MouseArea {
                                    id: cellArea
                                    anchors.fill: parent
                                    // A blank is not a day: it must not hover, click or select.
                                    enabled: dayCell.modelData !== null
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    // A click previews the day in the strip below rather than
                                    // covering the card: most of the time the block letter and
                                    // one line of wording are the whole answer. The sheet is
                                    // reserved for the wording line — the one thing the strip
                                    // cannot show in full — and for the compact card, which has
                                    // no strip to preview in.
                                    onClicked: {
                                        root.selectedDate = dayCell.cellKey;
                                        if (!root.withDetail) root.openDetail(dayCell.cellKey);
                                    }
                                }
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
                    font.family: StuyCalendar.blockFontFamily
                    font.pixelSize: 16
                    font.variableAxes: StuyCalendar.blockFontAxes
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

                    // The line is what gets cut off, so the line itself is the way in.
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openDetail(root.selectedDate)
                    }
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

        // The day sheet: the selected day's whole entry, wrapped, over the card.
        // Clicking the card behind it closes it, and the arrows walk through the
        // school year so a long wording can be compared with the days around it.
        Rectangle {
            id: daySheet
            anchors.fill: parent
            radius: card.radius
            color: Appearance.colors.colPrimaryContainer
            border.width: 1
            border.color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.82)
            visible: root.detailDate !== ""
            z: 10

            MouseArea {
                anchors.fill: parent
                onClicked: root.detailDate = ""
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
                        Layout.fillWidth: true
                        text: root.detailTitle
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimaryContainer
                        elide: Text.ElideRight
                    }

                    NavButton {
                        icon: "chevron_left"
                        opacity: root.detailDate > StuyCalendar.minDate ? 1 : 0.3
                        onActivated: root.shiftDetail(-1)
                    }
                    NavButton {
                        icon: "chevron_right"
                        opacity: root.detailDate < StuyCalendar.maxDate ? 1 : 0.3
                        onActivated: root.shiftDetail(1)
                    }

                    Rectangle {
                        implicitWidth: 20
                        implicitHeight: 20
                        radius: Appearance.rounding.full
                        color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, closeArea.containsMouse ? 0.78 : 0.88)

                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "close"
                            iconSize: 14
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.detailDate = ""
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    spacing: 8

                    // A holiday has no block letter: the column simply starts with the
                    // category instead of leaving a gap where a letter would be.
                    StyledText {
                        visible: text !== ""
                        text: root.detailEntry?.block ?? ""
                        font.family: StuyCalendar.blockFontFamily
                        font.pixelSize: root.withDetail ? 30 : 24
                        font.variableAxes: StuyCalendar.blockFontAxes
                        color: StuyCalendar.blockColor(root.detailEntry?.block)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: root.detailEntry
                                ? StuyCalendar.categoryLabel(root.detailEntry.category)
                                : "No school information"
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnPrimaryContainer
                            elide: Text.ElideRight
                        }
                        StyledText {
                            visible: text !== ""
                            text: {
                                const schedule = root.detailEntry?.scheduleType ?? "";
                                return schedule === "" ? "" : schedule + " schedule";
                            }
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                            elide: Text.ElideRight
                        }
                    }
                }

                // The wording itself: the part that was being cut off everywhere else.
                StyledText {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: 4
                    visible: text !== ""
                    text: {
                        const entry = root.detailEntry;
                        if (!entry) return "";
                        const label = StuyCalendar.categoryLabel(entry.category);
                        return entry.sourceWording && entry.sourceWording !== label ? entry.sourceWording : "";
                    }
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignTop
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnPrimaryContainer
                    opacity: 0.8
                    clip: true
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
