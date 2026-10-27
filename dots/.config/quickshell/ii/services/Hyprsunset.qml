pragma Singleton

import QtQuick
import qs.modules.common
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Simple hyprsunset service with automatic mode.
 * In theory we don't need this because hyprsunset has a config file, but it somehow doesn't work.
 * It should also be possible to control it via hyprctl, but it doesn't work consistently either so we're just killing and launching.
 */
Singleton {
    id: root
    signal gammaChangeAttempt()

    readonly property real gammaLowerLimit: 25
    readonly property real gammaUpperLimit: 150

    property string from: Config.options?.light?.night?.from ?? "19:00" 
    property string to: Config.options?.light?.night?.to ?? "06:30"
    property bool followSun: Config.options?.light?.night?.followSun ?? false
    property bool automatic: Config.options?.light?.night?.automatic && (Config?.ready ?? true)
    property int colorTemperature: Config.options?.light?.night?.colorTemperature ?? 5000
    property int defaultColorTemperature: 6000
    property int gamma: 100
    property bool shouldBeOn
    property bool applyingScheduleEdit: false
    property bool firstEvaluation: true
    property bool temperatureActive: false

    // Weather reports wall-clock strings ("07:18" or "7:18 AM" depending on the
    // provider), so normalize to minutes and fall back to the fixed times until
    // the first forecast lands or when following the sun is turned off.
    function parseClock(text) {
        if (!text) return -1;
        const match = String(text).trim().match(/^(\d{1,2}):(\d{2})\s*(AM|PM)?$/i);
        if (!match) return -1;
        let hour = Number(match[1]);
        const minute = Number(match[2]);
        const suffix = (match[3] ?? "").toUpperCase();
        if (suffix === "PM" && hour < 12) hour += 12;
        if (suffix === "AM" && hour === 12) hour = 0;
        if (hour > 23 || minute > 59) return -1;
        return hour * 60 + minute;
    }

    function minutesToClock(minutes) {
        const hour = Math.floor(minutes / 60);
        const minute = minutes % 60;
        return `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;
    }

    readonly property int sunriseMinutes: root.parseClock(Weather?.data?.sunrise ?? "")
    readonly property int sunsetMinutes: root.parseClock(Weather?.data?.sunset ?? "")
    readonly property bool sunTimesReady: root.sunriseMinutes >= 0 && root.sunsetMinutes >= 0
    readonly property string effectiveFrom: (root.followSun && root.sunTimesReady) ? root.minutesToClock(root.sunsetMinutes) : root.from
    readonly property string effectiveTo: (root.followSun && root.sunTimesReady) ? root.minutesToClock(root.sunriseMinutes) : root.to

    property int fromHour: Number(effectiveFrom.split(":")[0])
    property int fromMinute: Number(effectiveFrom.split(":")[1])
    property int toHour: Number(effectiveTo.split(":")[0])
    property int toMinute: Number(effectiveTo.split(":")[1])

    property int clockHour: DateTime.clock.hours
    property int clockMinute: DateTime.clock.minutes

    property var manualActive
    property int manualActiveHour
    property int manualActiveMinute

    onClockMinuteChanged: reEvaluate()
    // Editing the schedule must not switch the screen on retroactively: a start
    // time that already passed today takes effect at its next occurrence, so the
    // current state is only ever turned off here, never on.
    onFromChanged: applyScheduleEdit()
    onToChanged: applyScheduleEdit()
    onFollowSunChanged: applyScheduleEdit()
    onEffectiveFromChanged: applyScheduleEdit()
    onEffectiveToChanged: applyScheduleEdit()
    onAutomaticChanged: {
        root.manualActive = undefined;
        root.firstEvaluation = true;
        reEvaluate();
    }

    function inBetween(t, from, to) {
        if (from < to) {
            return (t >= from && t <= to);
        } else {
            // Wrapped around midnight
            return (t >= from || t <= to);
        }
    }

    /**
     * Recompute the window from an edited schedule. The new value is stored so the
     * next minute tick does not see a change and switch the screen on, and leaving
     * the window still turns it off so the screen is never warm outside it.
     */
    function applyScheduleEdit() {
        const t = clockHour * 60 + clockMinute;
        const from = fromHour * 60 + fromMinute;
        const to = toHour * 60 + toMinute;

        applyingScheduleEdit = true;
        root.shouldBeOn = inBetween(t, from, to);
        applyingScheduleEdit = false;

        if (!root.shouldBeOn) root.ensureState();
    }

    function reEvaluate() {
        const t = clockHour * 60 + clockMinute;
        const from = fromHour * 60 + fromMinute;
        const to = toHour * 60 + toMinute;
        const manualActive = manualActiveHour * 60 + manualActiveMinute;

        if (root.manualActive !== undefined && (inBetween(from, manualActive, t) || inBetween(to, manualActive, t))) {
            root.manualActive = undefined;
        }
        root.shouldBeOn = inBetween(t, from, to);
        if (firstEvaluation) {
            firstEvaluation = false;
            root.ensureState();
        }
    }

    onShouldBeOnChanged: if (!applyingScheduleEdit) ensureState()
    function ensureState() {
        // console.log("[Hyprsunset] Ensuring state:", root.shouldBeOn, "Automatic mode:", root.automatic);
        if (!root.automatic || root.manualActive !== undefined)
            return;
        if (root.shouldBeOn) {
            root.enableTemperature();
        } else {
            root.disableTemperature();
        }
    }

    function startHyprsunset() {
        Quickshell.execDetached(["bash", "-c",
            `pidof hyprsunset > /dev/null || hyprsunset --gamma_max ${root.gammaUpperLimit}`
        ]);
    }

    // Ensure the running hyprsunset accepts gamma above 100%; restart it with --gamma_max if not.
    function ensureHyprsunsetGammaMax() {
        Quickshell.execDetached(["bash", "-c",
            `pid=$(pidof hyprsunset 2>/dev/null); ` +
            `if [ -n "$pid" ] && ! tr '\\0' ' ' < /proc/$pid/cmdline 2>/dev/null | grep -q -- '--gamma_max'; then ` +
            `kill "$pid"; ` +
            `for _ in 1 2 3 4 5 6 7 8 9 10; do pidof hyprsunset > /dev/null || break; sleep 0.1; done; ` +
            `fi; ` +
            `pidof hyprsunset > /dev/null || hyprsunset --gamma_max ${root.gammaUpperLimit}`
        ]);
        updateHyprsunset.restart();
    }

    function load() {
        root.ensureHyprsunsetGammaMax();
        root.ensureState();
    }

    Timer {
        id: updateHyprsunset
        interval: 600
        repeat: false
        onTriggered: {
            root.ensureState();
            root.setGamma(root.gamma);
        }
    }

    function enableTemperature() {
        root.temperatureActive = true;

        // console.log("[Hyprsunset] Enabling");
        root.startHyprsunset();
        Quickshell.execDetached(["bash", "-c", `hyprctl hyprsunset temperature ${root.colorTemperature}`]);
    }

    function disableTemperature() {
        root.temperatureActive = false;
        // console.log("[Hyprsunset] Disabling");
        Quickshell.execDetached(["bash", "-c", `hyprctl hyprsunset temperature ${root.defaultColorTemperature}`]);
    }

    function setGamma(gamma) {
        root.gamma = Math.max(root.gammaLowerLimit, Math.min(root.gammaUpperLimit, gamma));

        root.gammaChangeAttempt();

        root.startHyprsunset();
        Quickshell.execDetached(["bash", "-c", `hyprctl hyprsunset gamma ${root.gamma}`]);
    }

    function fetchState() {
        fetchProc.running = true;
    }

    Process {
        id: fetchProc
        running: true
        command: ["bash", "-c", "hyprctl hyprsunset temperature"]
        stdout: StdioCollector {
            id: stateCollector
            onStreamFinished: {
                const output = stateCollector.text.trim();
                if (output.length == 0 || output.startsWith("Couldn't"))
                    root.temperatureActive = false;
                else
                    root.temperatureActive = (output != root.defaultColorTemperature); // 6000 is the default when off
                // console.log("[Hyprsunset] Fetched state:", output, "->", root.temperatureActive);
            }
        }
    }

    function toggleTemperature(active = undefined) {
        if (root.manualActive === undefined) {
            root.manualActive = root.temperatureActive;
            root.manualActiveHour = root.clockHour;
            root.manualActiveMinute = root.clockMinute;
        }

        root.manualActive = active !== undefined ? active : !root.manualActive;
        if (root.manualActive) {
            root.enableTemperature();
        } else {
            root.disableTemperature();
        }
    }

    // Change temp
    Connections {
        target: Config.options.light.night
        function onColorTemperatureChanged() {
            if (!root.temperatureActive) return;
            Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", `${Config.options.light.night.colorTemperature}`]);
        }
    }
}