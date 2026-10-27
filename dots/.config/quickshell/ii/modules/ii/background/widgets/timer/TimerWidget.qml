import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "timer"
    hoverEnabled: true

    // Exactly 2x2 grid cells (WidgetGrid) so the widget aligns with the grid
    implicitWidth: root.spanWidth(2)
    implicitHeight: root.spanHeight(2)

    property bool isTimerMode: true

    property int presetMinutes: 25
    property int presetSeconds: 0
    readonly property int presetTotalSeconds: presetMinutes * 60 + presetSeconds
    property int secondsLeft: presetTotalSeconds
    property bool timerRunning: false

    function formatTwoDigits(value) {
        return value.toString().padStart(2, "0");
    }

    function formatTimer(totalSeconds) {
        const m = Math.floor(totalSeconds / 60);
        const s = totalSeconds % 60;
        return `${formatTwoDigits(m)}:${formatTwoDigits(s)}`;
    }

    function formatStopwatch(centis) {
        const m = Math.floor(centis / 6000);
        const s = Math.floor((centis % 6000) / 100);
        const cs = centis % 100;
        return `${formatTwoDigits(m)}:${formatTwoDigits(s)}.${formatTwoDigits(cs)}`;
    }

    function setPreset(minutes, seconds) {
        presetMinutes = minutes;
        presetSeconds = seconds;
        if (!timerRunning)
            secondsLeft = presetTotalSeconds;
    }

    function adjustMinutes(delta) {
        setPreset(Math.max(0, Math.min(99, presetMinutes + delta)), presetSeconds);
    }

    function adjustSeconds(delta) {
        setPreset(presetMinutes, Math.max(0, Math.min(59, presetSeconds + delta)));
    }

    function toggleTimer() {
        if (timerRunning) {
            timerRunning = false;
        } else {
            if (secondsLeft <= 0)
                secondsLeft = presetTotalSeconds;
            timerRunning = secondsLeft > 0;
        }
    }

    function resetTimer() {
        timerRunning = false;
        secondsLeft = presetTotalSeconds;
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.timerRunning
        onTriggered: {
            if (root.secondsLeft > 0)
                root.secondsLeft -= 1;
            if (root.secondsLeft === 0) {
                root.timerRunning = false;
                if (Config.options.sounds.timer)
                    Audio.playSystemSound("alarm-clock-elapsed");
                Quickshell.execDetached(["notify-send", "Timer", "Time is up!", "-a", "Shell"]);
            }
        }
    }

    component PillButton: RippleButton {
        id: pillButton

        property string buttonText: ""
        property string symbolName: ""
        property bool activeState: false

        implicitWidth: labelRow.implicitWidth + 20
        implicitHeight: 30
        buttonRadius: Appearance.rounding.full
        colBackground: activeState ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer1Hover
        colBackgroundHover: activeState ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer1Active
        colBackgroundToggled: colBackground
        colBackgroundToggledHover: colBackgroundHover
        pointingHandCursor: enabled

        Row {
            id: labelRow
            anchors.centerIn: parent
            spacing: 4

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                visible: pillButton.symbolName.length > 0
                text: pillButton.symbolName
                iconSize: 18
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: pillButton.buttonText
                color: Appearance.colors.colOnLayer1
            }
        }
    }

    component StepperButton: RippleButton {
        id: stepperButton

        property string symbolName

        implicitWidth: 24
        implicitHeight: 24
        buttonRadius: Appearance.rounding.full
        colBackground: Appearance.colors.colLayer1Hover
        colBackgroundHover: Appearance.colors.colLayer1Active

        MaterialSymbol {
            anchors.centerIn: parent
            text: stepperButton.symbolName
            iconSize: 16
            color: Appearance.colors.colOnLayer1
        }
    }

    StyledRectangle {
        anchors.fill: parent
        color: Appearance.colors.colPrimaryContainer
        radius: Appearance.rounding.large
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: modeRow.implicitHeight
            Layout.preferredWidth: modeRow.implicitWidth

            Row {
                id: modeRow
                spacing: 6

                PillButton {
                    buttonText: Translation.tr("Timer")
                    activeState: root.isTimerMode
                    onClicked: root.isTimerMode = true
                }
                PillButton {
                    buttonText: Translation.tr("Stopwatch")
                    activeState: !root.isTimerMode
                    onClicked: {
                        root.isTimerMode = false;
                        root.resetTimer();
                    }
                }
            }
        }

        // Countdown
        Item {
            visible: root.isTimerMode
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.formatTimer(root.secondsLeft)
                    font.pixelSize: 44
                    font.weight: Font.Light
                    color: root.colText
                }

                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 5

                    Repeater {
                        model: [1, 5, 10, 25, 45]

                        delegate: PillButton {
                            required property int modelData

                            buttonText: `${modelData}m`
                            enabled: !root.timerRunning
                            activeState: !root.timerRunning && root.presetMinutes === modelData && root.presetSeconds === 0
                            onClicked: root.setPreset(modelData, 0)
                        }
                    }
                }

                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8

                    Row {
                        spacing: 3

                        StepperButton {
                            symbolName: "remove"
                            enabled: !root.timerRunning
                            onClicked: root.adjustMinutes(-1)
                        }
                        StyledText {
                            width: 30
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: `${root.presetMinutes}m`
                            color: root.colText
                        }
                        StepperButton {
                            symbolName: "add"
                            enabled: !root.timerRunning
                            onClicked: root.adjustMinutes(1)
                        }
                    }
                    Row {
                        spacing: 3

                        StepperButton {
                            symbolName: "remove"
                            enabled: !root.timerRunning
                            onClicked: root.adjustSeconds(-1)
                        }
                        StyledText {
                            width: 30
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: `${root.presetSeconds}s`
                            color: root.colText
                        }
                        StepperButton {
                            symbolName: "add"
                            enabled: !root.timerRunning
                            onClicked: root.adjustSeconds(1)
                        }
                    }
                }

                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8

                    PillButton {
                        buttonText: root.timerRunning ? Translation.tr("Pause") : (root.secondsLeft === root.presetTotalSeconds ? Translation.tr("Start") : Translation.tr("Resume"))
                        symbolName: root.timerRunning ? "pause" : "play_arrow"
                        enabled: root.timerRunning || root.secondsLeft > 0
                        onClicked: root.toggleTimer()
                    }
                    PillButton {
                        buttonText: Translation.tr("Reset")
                        symbolName: "refresh"
                        enabled: root.secondsLeft !== root.presetTotalSeconds || root.timerRunning
                        onClicked: root.resetTimer()
                    }
                }
            }
        }

        // Stopwatch
        Item {
            visible: !root.isTimerMode
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 14

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.formatStopwatch(TimerService.stopwatchTime)
                    font.pixelSize: 40
                    font.weight: Font.Light
                    color: root.colText
                }

                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8

                    PillButton {
                        buttonText: TimerService.stopwatchRunning ? Translation.tr("Pause") : (TimerService.stopwatchTime === 0 ? Translation.tr("Start") : Translation.tr("Resume"))
                        symbolName: TimerService.stopwatchRunning ? "pause" : "play_arrow"
                        onClicked: TimerService.toggleStopwatch()
                    }
                    PillButton {
                        buttonText: Translation.tr("Lap")
                        symbolName: "flag"
                        enabled: TimerService.stopwatchRunning
                        onClicked: TimerService.stopwatchRecordLap()
                    }
                    PillButton {
                        buttonText: Translation.tr("Reset")
                        symbolName: "refresh"
                        enabled: TimerService.stopwatchTime !== 0 || TimerService.stopwatchRunning
                        onClicked: TimerService.stopwatchReset()
                    }
                }
            }
        }
    }
}
