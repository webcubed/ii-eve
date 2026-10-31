import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import qs.modules.ii.bar

// The bar's sleep hint in full. On a school night: the bedtime that keeps the alarm at
// a cycle edge, how long that leaves, and the later boundaries if this one is too
// early. On a weekend or break the alarm is hypothetical, so the same list becomes
// predicted wake times from falling asleep now. The alarm itself is adjustable here,
// because on a school night the whole hint counts back from it.
StyledPopup {
    id: root

    // The pointer has to be able to travel the few pixels between the bar item and
    // this panel without the popup vanishing underneath it.
    stickyHover: true
    graceInterval: 380

    // Five minutes a press: the alarm is a round alarm time, not a sleep boundary, so
    // the useful adjustments are the small ones (06:15 -> 06:20).
    readonly property int wakeStepMinutes: 5

    ColumnLayout {
        implicitWidth: 236
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 2
            spacing: 6

            MaterialSymbol {
                text: SleepSchedule.freeNight ? "wb_twilight" : "bedtime"
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colPrimary
            }
            StyledText {
                Layout.fillWidth: true
                text: SleepSchedule.titleLabel
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnSurface
            }
            StyledText {
                text: SleepSchedule.next.label
                font.pixelSize: 22
                font.weight: Font.DemiBold
                color: Appearance.colors.colPrimary
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: SleepSchedule.detailLabel
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnSurface
            opacity: 0.65
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.bottomMargin: 4
            visible: SleepSchedule.options.length > 1
            implicitHeight: 1
            color: Appearance.colors.colLayer0Border
        }

        // The rest of tonight's boundaries, so an early one never looks like the only
        // option. The recommendation itself is the headline above. On a free night
        // these are the shorter sleeps from now, ending in earlier wakes.
        Repeater {
            model: SleepSchedule.options.slice(1)
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 6

                StyledText {
                    text: modelData.label
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnSurface
                    opacity: 0.85
                }
                StyledText {
                    Layout.fillWidth: true
                    text: modelData.cycles + " " + Translation.tr("cycles")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSurface
                    opacity: 0.55
                }
                StyledText {
                    text: modelData.inBedLabel
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSurface
                    opacity: 0.55
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: 4
            visible: SleepSchedule.options.length <= 1
            text: Translation.tr("Past the last boundary for tonight's alarm — the next one is tomorrow evening.")
            wrapMode: Text.WordWrap
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnSurface
            opacity: 0.55
        }

        // The alarm the boundaries are counted back from. Stepped rather than typed:
        // this popup follows the pointer, so a text field would lose focus the moment
        // the mouse crossed to it.
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 4

            MaterialSymbol {
                text: "alarm"
                iconSize: Appearance.font.pixelSize.smaller + 2
                color: Appearance.colors.colOnSurface
                opacity: 0.6
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Alarm")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSurface
                opacity: 0.6
            }

            SleepStepButton {
                icon: "remove"
                onActivated: Config.options.sleep.wakeTime = SleepSchedule.shiftedWake(-root.wakeStepMinutes)
            }
            StyledText {
                text: SleepSchedule.wakeLabel
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnSurface
            }
            SleepStepButton {
                icon: "add"
                onActivated: Config.options.sleep.wakeTime = SleepSchedule.shiftedWake(root.wakeStepMinutes)
            }
        }

        // Whether the hint counts back from the alarm or predicts a natural wake. Auto
        // hands the decision to the school calendar.
        SleepModeToggle {
            Layout.fillWidth: true
            Layout.topMargin: 2
            fgColor: Appearance.colors.colOnSurface
            value: SleepSchedule.mode
            onSelected: selectedMode => Config.options.sleep.mode = selectedMode
        }
    }
}
