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

    // Typed duration entry → seconds; 0 = unparseable.
    // Accepts: "90" (minutes), "1:30" (mm:ss), "1:30:00" (h:mm:ss), "1h30m", "45s"
    function parseDuration(raw) {
        const s = String(raw).trim().toLowerCase().replace(/\s+/g, "");
        if (!s) return 0;
        let m = s.match(/^(\d+):(\d{1,2}):(\d{1,2})$/);
        if (m) return (+m[1]) * 3600 + (+m[2]) * 60 + (+m[3]);
        m = s.match(/^(\d+):(\d{1,2})$/);
        if (m) return (+m[1]) * 60 + (+m[2]);
        m = s.match(/^(\d+h)?(\d+m)?(\d+s)?$/);
        if (m && (m[1] || m[2] || m[3])) {
            return (m[1] ? parseInt(m[1]) : 0) * 3600 + (m[2] ? parseInt(m[2]) : 0) * 60 + (m[3] ? parseInt(m[3]) : 0);
        }
        if (/^\d+$/.test(s)) return parseInt(s, 10) * 60;
        return 0;
    }

    // h:mm:ss readout (also the value restored to the field when it loses focus)
    readonly property string displayText: {
        const total = Math.max(0, TimerService.countdownLeft);
        const h = Math.floor(total / 3600);
        const m = Math.floor((total % 3600) / 60).toString().padStart(2, '0');
        const s = Math.floor(total % 60).toString().padStart(2, '0');
        return h > 0 ? `${h}:${m}:${s}` : `${m}:${s}`;
    }

    // Keeps the field synced to the live readout whenever the user isn't typing in it
    Binding {
        target: timeField
        property: "text"
        value: countdownTab.displayText
        when: timeField && !timeField.activeFocus
    }

    // Main timer content
    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

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

                // Editable readout: type a time (Enter or click away to apply) while idle
                TextField {
                    id: timeField
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 170
                    Layout.preferredHeight: 52
                    readOnly: TimerService.countdownRunning
                    selectByMouse: true
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Appearance.font.family.main
                    font.pixelSize: 40
                    font.weight: Font.DemiBold
                    color: Appearance.m3colors.m3onSurface
                    leftPadding: 6
                    rightPadding: 6
                    background: Rectangle {
                        radius: Appearance.rounding.small
                        color: timeField.activeFocus ? Appearance.colors.colLayer2 : "transparent"
                    }

                    function applyTyped() {
                        const secs = countdownTab.parseDuration(text);
                        if (secs <= 0) {
                            text = countdownTab.displayText;
                            return;
                        }
                        TimerService.countdownSet(Math.max(1, Math.min(999, Math.round(secs / 60))));
                    }
                    onAccepted: applyTyped()
                    onEditingFinished: applyTyped()
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

        // Basic presets; anything else goes straight into the ring's time field
        GridLayout {
            columns: 4
            columnSpacing: 6
            rowSpacing: 6
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true

            Repeater {
                model: [5, 10, 25, 60]
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

        }
    }

}
