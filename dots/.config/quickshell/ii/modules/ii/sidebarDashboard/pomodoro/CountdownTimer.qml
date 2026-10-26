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
    readonly property bool finished: TimerService.countdownDuration > 0 && TimerService.countdownLeft <= 0
    readonly property bool running: TimerService.countdownRunning
    /// 0..1 share of the countdown still to go, so the ring drains as it runs.
    readonly property real remainingRatio: {
        if (finished) return 1;
        if (TimerService.countdownDuration <= 0) return 0;
        return Math.max(0, Math.min(1, TimerService.countdownLeft / TimerService.countdownDuration));
    }

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

    /// Wall-clock time the countdown will hit zero, shown while it runs.
    readonly property string endsAt: {
        if (!running) return "";
        const end = new Date(Date.now() + Math.max(0, TimerService.countdownLeft) * 1000);
        return `${end.getHours().toString().padStart(2, "0")}:${end.getMinutes().toString().padStart(2, "0")}`;
    }

    readonly property string statusText: {
        if (finished) return Translation.tr("Finished");
        if (running) return Translation.tr("Running");
        if (hasStarted) return Translation.tr("Paused");
        return TimerService.countdownDuration > 0 ? Translation.tr("Ready") : Translation.tr("Countdown");
    }

    // While the field has focus it owns the text; otherwise it mirrors the live readout.
    property bool typing: false
    property string typedText: ""

    function commitTyped() {
        // Read-only while running: focusing the field must not re-arm the timer with the
        // text it happened to be showing.
        if (countdownTab.running) {
            countdownTab.typing = false;
            return;
        }
        const secs = parseDuration(countdownTab.typedText);
        // Keep the typed precision: "1:30" means 90 seconds, not two minutes.
        if (secs > 0) TimerService.countdownSetSeconds(Math.min(359999, secs));
        countdownTab.typing = false;
    }

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
            lineWidth: 7
            implicitSize: 178
            enableAnimation: true
            animationDuration: 420
            value: countdownTab.remainingRatio
            // A quiet track keeps the remaining time the thing the eye lands on.
            colSecondary: Appearance.colors.colLayer3
            // An idle ring has nothing to show, and a zero-length arc still paints a round
            // cap — a stray dot at twelve o'clock. Keep it invisible until there is progress.
            colPrimary: (countdownTab.finished || countdownTab.remainingRatio > 0)
                ? Appearance.colors.colPrimary
                : "transparent"

            Item {
                anchors.centerIn: parent
                width: timerDisplay.implicitSize - timerDisplay.lineWidth * 5
                height: readoutColumn.implicitHeight

                ColumnLayout {
                    id: readoutColumn
                    anchors.centerIn: parent
                    width: parent.width
                    spacing: 1

                    // Editable readout: type a time (Enter or click away to apply) while idle
                    TextField {
                        id: timeField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        text: countdownTab.typing ? countdownTab.typedText : countdownTab.displayText
                        readOnly: countdownTab.running
                        selectByMouse: true
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Appearance.font.family.main
                        font.pixelSize: text.length > 5 ? 30 : 36
                        font.weight: Font.DemiBold
                        color: countdownTab.finished ? Appearance.colors.colPrimary : Appearance.m3colors.m3onSurface
                        leftPadding: 4
                        rightPadding: 4
                        background: Rectangle {
                            radius: Appearance.rounding.small
                            color: timeField.activeFocus ? Appearance.colors.colLayer2 : "transparent"

                            Behavior on color {
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                            }
                        }

                        onActiveFocusChanged: {
                            if (activeFocus && !countdownTab.running) {
                                countdownTab.typedText = countdownTab.displayText;
                                countdownTab.typing = true;
                            } else if (!activeFocus && countdownTab.typing) {
                                countdownTab.commitTyped();
                            }
                        }
                        onAccepted: {
                            countdownTab.commitTyped();
                            timeField.focus = false;
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: countdownTab.statusText
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: countdownTab.finished ? Font.DemiBold : Font.Normal
                        color: countdownTab.finished ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        visible: text.length > 0
                        text: countdownTab.running ? `${Translation.tr("Ends at")} ${countdownTab.endsAt}` : ""
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        opacity: 0.75
                    }
                }
            }
        }

        // Basic presets; anything else goes straight into the ring's time field
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [5, 10, 25, 60]
                delegate: RippleButton {
                    required property int modelData
                    property bool isSelected: TimerService.countdownDuration === modelData * 60

                    Layout.fillWidth: true
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.small
                    enabled: !countdownTab.running
                    onClicked: TimerService.countdownSet(modelData)
                    colBackground: isSelected ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer2
                    colBackgroundHover: isSelected ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer2Hover

                    contentItem: StyledText {
                        anchors.centerIn: parent
                        text: modelData >= 60 ? `${modelData / 60}h` : `${modelData}m`
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: isSelected ? Font.DemiBold : Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        color: isSelected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
                    }
                }
            }
        }

        // Action buttons row
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 36
                buttonRadius: Appearance.rounding.small
                onClicked: TimerService.countdownToggle()
                colBackground: countdownTab.running ? Appearance.colors.colSecondaryContainer : Appearance.colors.colPrimary
                colBackgroundHover: countdownTab.running ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colPrimaryHover
                colRipple: countdownTab.running ? Appearance.colors.colSecondaryContainerActive : Appearance.colors.colPrimaryActive

                contentItem: RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        text: countdownTab.running ? "pause" : "play_arrow"
                        iconSize: Appearance.font.pixelSize.normal
                        color: countdownTab.running ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnPrimary
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        text: countdownTab.running ? Translation.tr("Pause") : (countdownTab.hasStarted ? Translation.tr("Resume") : Translation.tr("Start"))
                        color: countdownTab.running ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnPrimary
                        font.weight: Font.Medium
                    }
                }
            }

            RippleButton {
                Layout.fillWidth: false
                implicitHeight: 36
                implicitWidth: 92
                buttonRadius: Appearance.rounding.small
                enabled: (TimerService.countdownDuration > 0 && TimerService.countdownLeft !== TimerService.countdownDuration)
                    || countdownTab.running || countdownTab.hasStarted
                onClicked: TimerService.countdownReset()
                colBackground: Appearance.colors.colErrorContainer
                colBackgroundHover: Appearance.colors.colErrorContainerHover
                colRipple: Appearance.colors.colErrorContainerActive

                contentItem: RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        text: "restart_alt"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnErrorContainer
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        text: Translation.tr("Reset")
                        color: Appearance.colors.colOnErrorContainer
                        font.weight: Font.Medium
                    }
                }
            }
        }
    }
}
