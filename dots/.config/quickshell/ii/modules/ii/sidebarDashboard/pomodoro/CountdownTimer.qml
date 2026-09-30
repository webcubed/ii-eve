import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: countdownTab
    Layout.fillWidth: true
    Layout.fillHeight: true

    readonly property bool hasStarted: Persistent.states.timer.countdown.start > 0

    property bool presetModalOpen: false
    property int selectedPresetMinutes: 5

    function openPresetModal() {
        selectedPresetMinutes = TimerService.countdownDuration > 0 ? Math.round(TimerService.countdownDuration / 60) : 5;
        presetModalOpen = true;
    }
    function closePresetModal() { presetModalOpen = false; }
    function applyPreset(minutes: int) {
        TimerService.countdownSet(minutes);
        presetModalOpen = false;
        selectedPresetMinutes = minutes;
    }
    function adjustMinutes(delta: int) {
        let currentMins = TimerService.countdownDuration > 0 ? Math.round(TimerService.countdownDuration / 60) : 1;
        let newMins = Math.max(1, Math.min(999, currentMins + delta));
        TimerService.countdownSet(newMins);
    }

    // Main timer content
    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12
        visible: !countdownTab.presetModalOpen

        // Timer display (centered, takes space)
        CircularProgress {
            id: timerDisplay
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: true
            lineWidth: 6
            implicitSize: 170
            enableAnimation: true
            // Completed countdown: full ring in accent instead of an empty track
            value: (TimerService.countdownDuration > 0 && TimerService.countdownLeft <= 0)
                ? 1
                : (TimerService.countdownDuration <= 0 ? 0 : TimerService.countdownLeft / TimerService.countdownDuration)
            colPrimary: (TimerService.countdownDuration > 0 && TimerService.countdownLeft <= 0)
                ? Appearance.colors.colPrimary
                : Appearance.m3colors.m3onSecondaryContainer

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 2

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: {
                        let total = Math.max(0, TimerService.countdownLeft);
                        let h = Math.floor(total / 3600);
                        let m = Math.floor((total % 3600) / 60).toString().padStart(2, '0');
                        let s = Math.floor(total % 60).toString().padStart(2, '0');
                        return h > 0 ? `${h}:${m}:${s}` : `${m}:${s}`;
                    }
                    font.pixelSize: 40
                    font.weight: Font.DemiBold
                    color: Appearance.m3colors.m3onSurface
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: TimerService.countdownRunning ? Translation.tr("Running") :
                          TimerService.countdownLeft <= 0 && TimerService.countdownDuration > 0 ? Translation.tr("Finished") :
                          !countdownTab.hasStarted ? (TimerService.countdownDuration > 0 ? Translation.tr("Ready") : Translation.tr("Countdown")) :
                          Translation.tr("Paused")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: TimerService.countdownDuration > 0 && TimerService.countdownLeft <= 0 ? Font.DemiBold : Font.Normal
                    color: TimerService.countdownDuration > 0 && TimerService.countdownLeft <= 0
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colSubtext
                }
            }
        }

        // Time control: coarse jumps flanking the ±1m stepper — one row.
        // With ±15m/±1h available, only a few direct presets are needed.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            RippleButton {
                implicitWidth: 46
                implicitHeight: 38
                buttonRadius: Appearance.rounding.small
                enabled: !TimerService.countdownRunning
                onClicked: adjustMinutes(-60)
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: "-1h"
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer2
                }
            }
            RippleButton {
                implicitWidth: 46
                implicitHeight: 38
                buttonRadius: Appearance.rounding.small
                enabled: !TimerService.countdownRunning
                onClicked: adjustMinutes(-15)
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: "-15m"
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer2
                }
            }

            Rectangle {
                implicitWidth: stepperRow.implicitWidth + 8
                implicitHeight: 38
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2

                RowLayout {
                    id: stepperRow
                    anchors.centerIn: parent
                    spacing: 2

                    RippleButton {
                        implicitWidth: 36
                        implicitHeight: 36
                        buttonRadius: Appearance.rounding.small
                        enabled: !TimerService.countdownRunning
                        onClicked: adjustMinutes(-1)
                        colBackground: Appearance.colors.colLayer3
                        colBackgroundHover: Appearance.colors.colLayer3Hover

                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "remove"
                            iconSize: 20
                            color: Appearance.colors.colOnLayer2
                        }
                    }

                    StyledText {
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        text: {
                            const mins = TimerService.countdownDuration > 0
                                ? Math.round(TimerService.countdownDuration / 60) : 1;
                            return `${mins}m`;
                        }
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer2
                    }

                    RippleButton {
                        implicitWidth: 36
                        implicitHeight: 36
                        buttonRadius: Appearance.rounding.small
                        enabled: !TimerService.countdownRunning
                        onClicked: adjustMinutes(1)
                        colBackground: Appearance.colors.colLayer3
                        colBackgroundHover: Appearance.colors.colLayer3Hover

                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "add"
                            iconSize: 20
                            color: Appearance.colors.colOnLayer2
                        }
                    }
                }
            }

            RippleButton {
                implicitWidth: 46
                implicitHeight: 38
                buttonRadius: Appearance.rounding.small
                enabled: !TimerService.countdownRunning
                onClicked: adjustMinutes(15)
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: "+15m"
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer2
                }
            }
            RippleButton {
                implicitWidth: 46
                implicitHeight: 38
                buttonRadius: Appearance.rounding.small
                enabled: !TimerService.countdownRunning
                onClicked: adjustMinutes(60)
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: "+1h"
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer2
                }
            }
        }

        // A few direct presets (the coarse jumps cover everything else)
        GridLayout {
            columns: 4
            columnSpacing: 6
            rowSpacing: 6
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true

            Repeater {
                model: [10, 25, 60, 90]
                delegate: RippleButton {
                    required property int modelData
                    property bool isSelected: TimerService.countdownDuration === modelData * 60
                    implicitWidth: 48
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.small
                    enabled: !TimerService.countdownRunning
                    onClicked: TimerService.countdownSet(modelData)
                    colBackground: isSelected ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer2
                    colBackgroundHover: isSelected ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer2Hover

                    contentItem: StyledText {
                        anchors.centerIn: parent
                        text: modelData >= 60 ? `${modelData / 60}h` : `${modelData}m`
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: isSelected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
                    }
                }
            }
        }

        // Action buttons row
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            RippleButton {
                implicitHeight: 36
                implicitWidth: 100
                buttonRadius: Appearance.rounding.small
                onClicked: TimerService.countdownToggle()
                colBackground: TimerService.countdownRunning ? Appearance.colors.colSecondaryContainer : Appearance.colors.colPrimary
                colBackgroundHover: TimerService.countdownRunning ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colPrimaryHover
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: TimerService.countdownRunning ? Translation.tr("Pause") :
                          !countdownTab.hasStarted ? Translation.tr("Start") : Translation.tr("Resume")
                    color: TimerService.countdownRunning ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnPrimary
                    font.weight: Font.Medium
                }
            }

            RippleButton {
                implicitHeight: 36
                implicitWidth: 86
                buttonRadius: Appearance.rounding.small
                onClicked: TimerService.countdownReset()
                enabled: (TimerService.countdownDuration > 0 && TimerService.countdownLeft !== TimerService.countdownDuration) || TimerService.countdownRunning || countdownTab.hasStarted
                colBackground: Appearance.colors.colErrorContainer
                colBackgroundHover: Appearance.colors.colErrorContainerHover
                colRipple: Appearance.colors.colErrorContainerActive
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: Translation.tr("Reset")
                    color: Appearance.colors.colOnErrorContainer
                    font.weight: Font.Medium
                }
            }

            RippleButton {
                implicitHeight: 36
                implicitWidth: 86
                buttonRadius: Appearance.rounding.small
                onClicked: openPresetModal()
                enabled: !TimerService.countdownRunning
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                contentItem: Row {
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "add"
                        iconSize: 18
                        color: Appearance.colors.colOnLayer2
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Translation.tr("Custom")
                        color: Appearance.colors.colOnLayer2
                        font.weight: Font.Medium
                    }
                }
            }
        }
    }

    // Modal overlay - custom time input
    Rectangle {
        id: presetOverlay
        anchors.fill: parent
        color: "#99000000"
        visible: countdownTab.presetModalOpen
        z: 100

        MouseArea {
            anchors.fill: parent
            onClicked: closePresetModal()
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(320, parent.width - 20)
            implicitHeight: modalContent.implicitHeight + 36
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1

            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                id: modalContent
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("Custom Duration")
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnSurface
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 46
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer2

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 8

                        RippleButton {
                            implicitWidth: 38
                            implicitHeight: 38
                            buttonRadius: Appearance.rounding.small
                            enabled: presetModalOpen
                            onClicked: selectedPresetMinutes = Math.max(1, selectedPresetMinutes - 1)
                            colBackground: Appearance.colors.colLayer3
                            colBackgroundHover: Appearance.colors.colLayer3Hover
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "remove"
                                iconSize: 20
                                color: Appearance.colors.colOnLayer2
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            StyledText {
                                anchors.centerIn: parent
                                text: `${selectedPresetMinutes} ${selectedPresetMinutes === 1 ? Translation.tr("minute") : Translation.tr("minutes")}`
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnSurface
                            }
                        }

                        RippleButton {
                            implicitWidth: 38
                            implicitHeight: 38
                            buttonRadius: Appearance.rounding.small
                            enabled: presetModalOpen
                            onClicked: selectedPresetMinutes = Math.min(999, selectedPresetMinutes + 1)
                            colBackground: Appearance.colors.colLayer3
                            colBackgroundHover: Appearance.colors.colLayer3Hover
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "add"
                                iconSize: 20
                                color: Appearance.colors.colOnLayer2
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6

                    Repeater {
                        model: [5, 10, 15, 25, 30, 45, 60]
                        delegate: RippleButton {
                            required property int modelData
                            property bool isSelected: selectedPresetMinutes === modelData
                            implicitWidth: 40
                            implicitHeight: 28
                            buttonRadius: Appearance.rounding.small
                            onClicked: selectedPresetMinutes = modelData
                            colBackground: isSelected ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
                            colBackgroundHover: isSelected ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer2Hover
                            contentItem: StyledText {
                                anchors.centerIn: parent
                                text: modelData >= 60 ? `${modelData / 60}h` : `${modelData}m`
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.DemiBold
                                color: isSelected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12

                    RippleButton {
                        implicitHeight: 34
                        implicitWidth: 85
                        buttonRadius: Appearance.rounding.small
                        onClicked: closePresetModal()
                        colBackground: Appearance.colors.colLayer2
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        contentItem: StyledText {
                            anchors.centerIn: parent
                            text: Translation.tr("Cancel")
                            color: Appearance.colors.colOnLayer2
                            font.weight: Font.Medium
                        }
                    }

                    RippleButton {
                        implicitHeight: 34
                        implicitWidth: 85
                        buttonRadius: Appearance.rounding.small
                        onClicked: applyPreset(Math.max(1, selectedPresetMinutes))
                        enabled: selectedPresetMinutes > 0
                        colBackground: Appearance.colors.colPrimary
                        colBackgroundHover: Appearance.colors.colPrimaryHover
                        contentItem: StyledText {
                            anchors.centerIn: parent
                            text: Translation.tr("Apply")
                            color: Appearance.colors.colOnPrimary
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }
    }
}