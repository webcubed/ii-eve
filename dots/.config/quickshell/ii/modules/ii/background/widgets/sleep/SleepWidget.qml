import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

// The next sleep, on the desktop. On a school night that is the bedtime that puts the
// 06:15 alarm at the end of a sleep cycle; on a weekend or break, when the wake time is
// not fixed, it predicts the wakes a night from now would end at instead. Two cells
// wide: the time is the headline, the countdown and the length of the night sit beside
// it, the taller size adds the other boundaries, and the alarm is adjustable here too.
AbstractBackgroundWidget {
    id: root
    configEntryName: "sleep"
    hoverEnabled: true

    property string sizeMode: root.configEntry.sizeMode ?? "2x2"
    readonly property bool withOptions: root.sizeMode !== "2x1"
    property real widgetWidth: root.spanWidth(2)
    property real widgetHeight: root.withOptions ? root.spanHeight(2) : root.spanHeight(1)
    implicitWidth: widgetWidth
    implicitHeight: widgetHeight

    Behavior on widgetWidth {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }
    Behavior on widgetHeight {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    readonly property var next: SleepSchedule.next
    readonly property bool imminent: !SleepSchedule.freeNight && root.next.minutesAway <= 20
    // Five minutes a press, the same step as the bar's popup.
    readonly property int wakeStepMinutes: 5

    function stepWake(deltaMinutes) {
        Config.options.sleep.wakeTime = SleepSchedule.shiftedWake(deltaMinutes);
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
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                spacing: 5

                MaterialSymbol {
                    fill: root.imminent ? 1 : 0
                    text: SleepSchedule.freeNight ? "wb_twilight" : "bedtime"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colPrimary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: SleepSchedule.titleLabel
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnPrimaryContainer
                    opacity: 0.8
                }
                StyledText {
                    // On a free night the countdown would only repeat the night's length
                    // below, so the header says what changed instead: the alarm is off.
                    text: SleepSchedule.freeNight
                        ? Translation.tr("no alarm")
                        : SleepSchedule.countdownLabel
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colPrimary
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    text: root.next.label
                    font.pixelSize: root.withOptions ? 32 : 27
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnPrimaryContainer
                }

                Item { Layout.fillWidth: true }

                ColumnLayout {
                    spacing: -2

                    StyledText {
                        Layout.alignment: Qt.AlignRight
                        text: SleepSchedule.nightLabel
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.65
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignRight
                        text: root.next.cycles + " " + Translation.tr("cycles")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.65
                    }
                }
            }

            // The later boundaries, so the headline does not read as the only choice.
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 1
                // Only a separator when there is something below it: late at night
                // there are no later boundaries left, and a lone rule would hang.
                visible: root.withOptions && SleepSchedule.options.length > 1
                implicitHeight: 1
                color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.82)
            }

            Repeater {
                model: root.withOptions ? SleepSchedule.options.slice(1) : []
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        text: modelData.label
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.85
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.cycles + " " + Translation.tr("cycles")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.5
                    }
                    StyledText {
                        text: modelData.inBedLabel
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.5
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // The alarm every boundary is counted back from, adjustable without opening
            // the bar's popup. The buttons take the card's own tone so they read as part
            // of the card rather than as a floating control.
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                MaterialSymbol {
                    text: "alarm"
                    iconSize: Appearance.font.pixelSize.smaller + 2
                    color: Appearance.colors.colOnPrimaryContainer
                    opacity: 0.6
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Alarm")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnPrimaryContainer
                    opacity: 0.6
                }

                SleepStepButton {
                    icon: "remove"
                    fgColor: Appearance.colors.colOnPrimaryContainer
                    onActivated: root.stepWake(-root.wakeStepMinutes)
                }
                StyledText {
                    text: SleepSchedule.wakeLabel
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnPrimaryContainer
                }
                SleepStepButton {
                    icon: "add"
                    fgColor: Appearance.colors.colOnPrimaryContainer
                    onActivated: root.stepWake(root.wakeStepMinutes)
                }
            }

            // The mode switch the bar popup carries, so the card can be pinned to the
            // alarm or to a prediction without hovering the bar. The one-cell height
            // has no room for it.
            SleepModeToggle {
                Layout.fillWidth: true
                Layout.topMargin: 2
                visible: root.withOptions
                fgColor: Appearance.colors.colOnPrimaryContainer
                value: SleepSchedule.mode
                onSelected: selectedMode => Config.options.sleep.mode = selectedMode
            }
        }
    }
}
