import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "timers"
    hoverEnabled: true

    // Whole spans of the design grid (WidgetGrid): the card row is exactly
    // 3x1 cells so its edges land on the same lines as the other widgets.
    // "3x1" is the row of three square tiles; "3x2" is one expanded card for a single
    // timer, which the corner handle switches to (drag it down to expand).
    property string sizeMode: root.configEntry.sizeMode ?? "3x1"
    readonly property bool expanded: root.sizeMode === "3x2"
    property string expandedTimer: root.configEntry.expandedTimer ?? "pomodoro"
    property real widgetWidth: root.spanWidth(3)
    property real cardSpacing: WidgetGrid.gutter
    property real cardWidth: (widgetWidth - cardSpacing * 2) / 3
    // Square tiles: the three cards split the row's width, so deriving the height
    // from that same width keeps them square and lands their edges on the same
    // lines as the spacer gutters. A cell-height tile was taller than wide.
    property real cardHeight: root.cardWidth
    property bool isVertical: root.configEntry.vertical ?? false

    implicitWidth: root.expanded ? root.widgetWidth : row.implicitWidth
    implicitHeight: root.expanded ? root.spanHeight(2) : row.implicitHeight

    Behavior on implicitHeight {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    readonly property color expandedFg: Appearance.colors.colOnPrimaryContainer
    readonly property color expandedAccent: Appearance.colors.colPrimary

    // --- Expanded variant: one timer at a time, with the detail a square tile has no
    // room for (cycle position, laps, target duration) and its own controls.
    function expandedTitle() {
        if (root.expandedTimer === "pomodoro") return "Pomodoro";
        if (root.expandedTimer === "stopwatch") return "Stopwatch";
        return "Timer";
    }
    function expandedIcon() {
        if (root.expandedTimer === "pomodoro") return TimerService.pomodoroBreak ? "coffee" : "visibility";
        if (root.expandedTimer === "stopwatch") return "timer";
        return "hourglass_top";
    }
    function expandedRunning() {
        if (root.expandedTimer === "pomodoro") return TimerService.pomodoroRunning;
        if (root.expandedTimer === "stopwatch") return TimerService.stopwatchRunning;
        return TimerService.countdownRunning;
    }
    // Stopwatch ticks are 10ms, so the expanded readout can carry centiseconds
    function formatStopwatch(ticks) {
        const totalSeconds = Math.floor(ticks / 100);
        const centis = Math.floor(ticks % 100);
        return TimerService.formatSeconds(totalSeconds) + "." + centis.toString().padStart(2, "0");
    }
    function expandedValue() {
        if (root.expandedTimer === "pomodoro") return TimerService.formatSeconds(TimerService.pomodoroSecondsLeft);
        if (root.expandedTimer === "stopwatch") return root.formatStopwatch(TimerService.stopwatchTime);
        return TimerService.formatSeconds(TimerService.countdownSecondsLeft);
    }
    function expandedSubtitle() {
        if (root.expandedTimer === "pomodoro") {
            const phase = TimerService.pomodoroLongBreak ? "Long break" : TimerService.pomodoroBreak ? "Break" : "Focus";
            return phase + " · cycle " + (TimerService.pomodoroCycle + 1) + "/" + TimerService.cyclesBeforeLongBreak;
        }
        if (root.expandedTimer === "stopwatch") {
            const laps = TimerService.stopwatchLaps;
            if (!laps || laps.length === 0) return "No laps yet";
            return "Lap " + laps.length + " · last " + root.formatStopwatch(laps[laps.length - 1]);
        }
        return "Target " + TimerService.formatSeconds(TimerService.countdownDuration);
    }
    // Fraction elapsed, or -1 for the stopwatch, which has no target to measure against
    readonly property real expandedProgress: {
        if (root.expandedTimer === "pomodoro")
            return TimerService.pomodoroLapDuration > 0 ? 1 - TimerService.pomodoroSecondsLeft / TimerService.pomodoroLapDuration : 0;
        if (root.expandedTimer === "countdown")
            return TimerService.countdownDuration > 0 ? 1 - TimerService.countdownSecondsLeft / TimerService.countdownDuration : 0;
        return -1;
    }
    function toggleExpandedTimer() {
        if (root.expandedTimer === "pomodoro") TimerService.togglePomodoro();
        else if (root.expandedTimer === "stopwatch") TimerService.toggleStopwatch();
        else TimerService.toggleCountdown();
    }
    function resetExpandedTimer() {
        if (root.expandedTimer === "pomodoro") TimerService.resetPomodoro();
        else if (root.expandedTimer === "stopwatch") TimerService.stopwatchReset();
        else TimerService.resetCountdown();
    }
    function selectExpandedTimer(id) {
        root.expandedTimer = id;
        root.configEntry.expandedTimer = id;
    }

    component TimerCard: WidgetCard {
        id: timerCard
        property string icon: ""
        property string value: ""
        property string label: ""
        property bool running: false
        property int shape: MaterialShape.Shape.Cookie12Sided
        property color bgColor: Appearance.colors.colPrimaryContainer
        // Foreground paired with bgColor — each card sits on a different container tone, so
        // the label, time and pills all read from this instead of the primary container's
        // on-colour.
        property color fgColor: Appearance.colors.colOnPrimaryContainer
        property color shapeColor: Appearance.colors.colPrimary
        property var onToggle: () => {}
        property var onReset: () => {}
        default property alias extraContent: extraSlot.data

        implicitWidth: root.cardWidth
        implicitHeight: root.cardHeight
        widget: root
        color: timerCard.bgColor

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: timerCard.onReset()
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: 12
            }
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                // Play/pause affordance sits top-right; the middle stays free for the time.
                Item { Layout.fillWidth: true }

                MaterialShapeWrappedMaterialSymbol {
                    shape: timerCard.shape
                    color: timerCard.shapeColor
                    colSymbol: Appearance.colors.colOnPrimary
                    text: timerCard.running ? "pause" : timerCard.icon
                    iconSize: 16
                    fill: 1
                    padding: 5
                    implicitWidth: 30
                    implicitHeight: 30

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: timerCard.onToggle()
                    }
                }
            }

            Item { Layout.fillHeight: true }

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 1
                text: timerCard.value
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.DemiBold
                // Tabular figures made the readout look wide and uneven at this size; the value
                // never needs column alignment, so let the font space it naturally.
                color: timerCard.fgColor
                elide: Text.ElideRight
                renderType: Text.QtRendering
            }

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 1
                text: timerCard.label
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: timerCard.fgColor
                opacity: 0.65
                elide: Text.ElideRight
            }

            Item {
                id: extraSlot
                Layout.fillWidth: true
                Layout.preferredHeight: children.length > 0 ? 20 : 0
                Layout.topMargin: children.length > 0 ? 4 : 0
            }
        }
    }

    Grid {
        id: row
        visible: !root.expanded
        columns: root.isVertical ? 1 : 3
        rows: root.isVertical ? 3 : 1
        spacing: root.cardSpacing

        Behavior on columns {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        // Pomodoro
        TimerCard {
            icon: TimerService.pomodoroBreak ? "coffee" : "visibility"
            value: TimerService.formatSeconds(TimerService.pomodoroSecondsLeft)
            label: TimerService.pomodoroBreak ? "Break" : "Focus"
            running: TimerService.pomodoroRunning
            bgColor: Appearance.colors.colTertiaryContainer
            fgColor: Appearance.colors.colOnTertiaryContainer
            shapeColor: Appearance.colors.colTertiary
            shape: MaterialShape.Shape.Flower
            onToggle: () => TimerService.togglePomodoro()
            onReset: () => TimerService.resetPomodoro()
        }

        // Stopwatch
        TimerCard {
            icon: "timer"
            value: TimerService.formatSeconds(TimerService.stopwatchTime / 100)
            label: "Stopwatch"
            running: TimerService.stopwatchRunning
            shape: MaterialShape.Shape.Sunny
            bgColor: Appearance.colors.colSecondaryContainer
            fgColor: Appearance.colors.colOnSecondaryContainer
            shapeColor: Appearance.colors.colSecondary
            onToggle: () => TimerService.toggleStopwatch()
            onReset: () => TimerService.stopwatchReset()
        }

        // Countdown
        TimerCard {
            icon: "hourglass_top"
            value: TimerService.formatSeconds(TimerService.countdownSecondsLeft)
            label: "Countdown"
            running: TimerService.countdownRunning
            shape: MaterialShape.Shape.Bun
            onToggle: () => TimerService.toggleCountdown()
            onReset: () => TimerService.resetCountdown()

            RowLayout {
                anchors.fill: parent
                spacing: 4

                Repeater {
                    model: [1, 5]
                    delegate: Rectangle {
                        required property int modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding.full
                        // Bound to the singletons rather than an id from the enclosing
                        // component: items in this extraContent slot are compiled outside the
                        // TimerCard scope, so `timerCard.fgColor` there fails and the pill
                        // silently falls back to a solid white Rectangle.
                        color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.82)

                        StyledText {
                            anchors.centerIn: parent
                            text: "+" + modelData + "m"
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnPrimaryContainer
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: TimerService.addCountdownMinutes(modelData)
                        }
                    }
                }
            }
        }
    }

    component ControlPill: Rectangle {
        id: pill
        property string icon: ""
        property string text: ""
        property color fgColor: Appearance.colors.colOnPrimaryContainer
        property color bgColor: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.86)
        signal activated()

        implicitHeight: 36
        implicitWidth: pill.text.length > 0
            ? pillText.implicitWidth + (pill.icon.length > 0 ? 42 : 26)
            : 44
        radius: Appearance.rounding.full
        color: pill.bgColor

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 6

            MaterialSymbol {
                visible: pill.icon.length > 0
                text: pill.icon
                iconSize: 17
                fill: 1
                color: pill.fgColor
            }
            StyledText {
                id: pillText
                visible: pill.text.length > 0
                text: pill.text
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: pill.fgColor
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.activated()
        }
    }

    // The expanded variants live in one card: a header that doubles as a timer picker,
    // the readout the tile has no room for, and controls specific to the timer.
    WidgetCard {
        id: expandedCard
        anchors.fill: parent
        visible: root.expanded
        widget: root
        color: Appearance.colors.colPrimaryContainer

        ColumnLayout {
            anchors {
                fill: parent
                margins: 16
            }
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialShapeWrappedMaterialSymbol {
                    shape: MaterialShape.Shape.Cookie12Sided
                    color: root.expandedAccent
                    colSymbol: Appearance.colors.colOnPrimary
                    text: root.expandedIcon()
                    iconSize: 16
                    fill: 1
                    padding: 5
                    implicitWidth: 30
                    implicitHeight: 30
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.expandedTitle()
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.DemiBold
                    color: root.expandedFg
                    elide: Text.ElideRight
                }

                Repeater {
                    model: [
                        { id: "pomodoro", icon: "visibility", name: "Pomodoro" },
                        { id: "stopwatch", icon: "timer", name: "Stopwatch" },
                        { id: "countdown", icon: "hourglass_top", name: "Timer" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool selected: root.expandedTimer === modelData.id

                        implicitWidth: 30
                        implicitHeight: 30
                        radius: Appearance.rounding.full
                        color: selected
                            ? root.expandedAccent
                            : ColorUtils.transparentize(root.expandedFg, 0.88)

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: modelData.icon
                            iconSize: 16
                            fill: selected ? 1 : 0
                            color: selected ? Appearance.colors.colOnPrimary : root.expandedFg
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectExpandedTimer(modelData.id)
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            StyledText {
                Layout.fillWidth: true
                text: root.expandedValue()
                font.pixelSize: Appearance.font.pixelSize.huge
                font.weight: Font.DemiBold
                color: root.expandedFg
                renderType: Text.QtRendering
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.expandedSubtitle()
                font.pixelSize: Appearance.font.pixelSize.small
                color: root.expandedFg
                opacity: 0.65
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 2
                implicitHeight: 6
                visible: root.expandedProgress >= 0
                radius: 3
                color: ColorUtils.transparentize(root.expandedFg, 0.86)

                Rectangle {
                    width: Math.max(0, Math.min(1, root.expandedProgress)) * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: root.expandedAccent

                    Behavior on width {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // Countdown amounts, which the tile's +1/+5 buttons cannot cover
            RowLayout {
                Layout.fillWidth: true
                visible: root.expandedTimer === "countdown"
                spacing: 6

                StyledText {
                    text: "Set"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.expandedFg
                    opacity: 0.6
                }
                Repeater {
                    model: [5, 10, 25, 45]
                    delegate: ControlPill {
                        required property int modelData
                        text: modelData + "m"
                        onActivated: TimerService.countdownSet(modelData)
                    }
                }
                Item { Layout.fillWidth: true }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ControlPill {
                    icon: root.expandedRunning() ? "pause" : "play_arrow"
                    text: root.expandedRunning() ? "Pause" : "Start"
                    bgColor: root.expandedAccent
                    fgColor: Appearance.colors.colOnPrimary
                    onActivated: root.toggleExpandedTimer()
                }

                ControlPill {
                    visible: root.expandedTimer === "stopwatch"
                    icon: "flag"
                    text: "Lap"
                    onActivated: TimerService.stopwatchRecordLap()
                }

                ControlPill {
                    icon: "restart_alt"
                    text: "Reset"
                    onActivated: root.resetExpandedTimer()
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    // Bottom-right handle: drag it down to expand into the single-timer card, up to go
    // back to the row of three tiles. Only visible while the card is hovered.
    Rectangle {
        id: sizeHandle
        width: 16
        height: 16
        radius: 4
        color: Appearance.colors.colOnPrimaryContainer
        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: 4
        }
        opacity: (root.containsMouse || sizeArea.containsMouse || sizeArea.pressed) ? 0.5 : 0
        visible: opacity > 0 && !Config.options.background.widgetsLocked

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        MouseArea {
            id: sizeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeVerCursor
            preventStealing: true

            property real startY: 0
            property real startHeight: 0

            onPressed: (mouse) => {
                startHeight = root.implicitHeight;
                startY = mapToItem(null, mouse.x, mouse.y).y;
            }
            onPositionChanged: (mouse) => {
                if (!pressed) return;
                const dy = mapToItem(null, mouse.x, mouse.y).y - startY;
                // Midway between a tile row and an expanded card is the tipping point
                const midpoint = (root.cardHeight + root.spanHeight(2)) / 2;
                root.sizeMode = (startHeight + dy) > midpoint ? "3x2" : "3x1";
            }
            onReleased: root.configEntry.sizeMode = root.sizeMode
        }
    }

    WidgetFlipHandle {
        anchorItem: root
        hoverActive: root.containsMouse
        locked: Config.options.background.widgetsLocked
        onClicked: {
            root.isVertical = !root.isVertical
            root.configEntry.vertical = root.isVertical
        }
    }
}
