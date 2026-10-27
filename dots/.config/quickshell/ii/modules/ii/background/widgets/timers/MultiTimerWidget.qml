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
    // 3x1 cells so its edges land on the same lines as the other widgets
    property real widgetWidth: root.spanWidth(3)
    property real cardSpacing: WidgetGrid.gutter
    property real cardHeight: root.gridCellHeight
    property real cardWidth: (widgetWidth - cardSpacing * 2) / 3
    property bool isVertical: root.configEntry.vertical ?? false

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

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
                margins: 9
            }
            spacing: 2

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
                Layout.preferredHeight: children.length > 0 ? 18 : 0
                Layout.topMargin: children.length > 0 ? 3 : 0
            }
        }
    }

    Grid {
        id: row
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
