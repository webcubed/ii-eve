pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

// Sleep timing, two ways round.
//
// On a school night the arithmetic runs backwards from the alarm: sleep is a sequence
// of ~90 minute cycles, and waking at the top of one is what makes a short night feel
// survivable, so the useful times are fixed points before 06:15 — 21:00 (6 cycles),
// 22:30 (5), 00:00 (4), 01:30 (3) — plus the time it takes to actually fall asleep,
// which is why those are not round multiples of 90 from the alarm itself.
//
// On a weekend or a school break there is no alarm to count back from, so the hint
// turns around: the bedtime is now, and the times it shows are the wakes 3-6 cycles
// later — predictions of a natural wake at a cycle edge. The school calendar decides
// which night this is.
Singleton {
    id: root

    readonly property var settings: Config.ready ? (Config.options.sleep ?? ({})) : ({})
    readonly property int cycleMinutes: {
        const value = Number(root.settings.cycleMinutes ?? 90);
        return isNaN(value) ? 90 : Math.max(30, Math.min(180, value));
    }
    readonly property int fallAsleepMinutes: {
        const value = Number(root.settings.fallAsleepMinutes ?? 15);
        return isNaN(value) ? 15 : Math.max(0, Math.min(90, value));
    }
    // Six cycles is a full night; below three (4h30 of actual sleep) the hint stops
    // being advice, so that is where the evening's last boundary sits.
    readonly property int maxCycles: {
        const value = Number(root.settings.maxCycles ?? 6);
        return isNaN(value) ? 6 : Math.max(1, Math.min(8, Math.round(value)));
    }
    readonly property int minCycles: {
        const value = Number(root.settings.minCycles ?? 3);
        return isNaN(value) ? 3 : Math.max(1, Math.min(root.maxCycles, Math.round(value)));
    }

    // Minute precision is all this needs, and SystemClock already re-reads the time
    // every minute for the rest of the shell: no timer of our own, and the hint rolls
    // over to the next boundary by itself.
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    readonly property date now: clock.date
    readonly property int nowMinutes: root.now.getHours() * 60 + root.now.getMinutes()

    readonly property int wakeMinutes: {
        const parts = String(root.settings.wakeTime ?? "06:15").split(":");
        const hours = Number(parts[0]);
        const minutes = Number(parts[1]);
        return (isNaN(hours) ? 6 : Math.max(0, Math.min(23, hours))) * 60
            + (isNaN(minutes) ? 15 : Math.max(0, Math.min(59, minutes)));
    }
    readonly property string wakeLabel: root.timeLabel(root.wakeMinutes)

    // Minutes until the next alarm. The alarm itself is not a bedtime, so at 06:15
    // exactly this already looks at tomorrow morning's.
    readonly property int untilWake: {
        const delta = root.wakeMinutes - root.nowMinutes;
        return delta > 0 ? delta : delta + 1440;
    }
    // Absolute minute markers (minutes since the epoch) rather than times of day, so a
    // candidate after midnight stays later than one before it without wrapping.
    readonly property real nowMarker: Math.floor(root.now.getTime() / 60000)
    readonly property real wakeMarker: root.nowMarker + root.untilWake

    // Which direction the hint runs. "auto" asks the school calendar whether the next
    // wake morning is a school morning; the other two are manual overrides for a day
    // that does not match the calendar (an early practice on a holiday, a late night
    // before school).
    readonly property string mode: {
        const value = String(root.settings.mode ?? "auto");
        return value === "alarm" || value === "predict" ? value : "auto";
    }

    // The morning the next alarm would ring. On a weekend or a school break that alarm
    // is hypothetical — there is nothing forcing the wake time — so the hint predicts
    // a natural wake instead. The Stuy calendar knows the holidays and the recesses;
    // before it has loaded (or for a date past its end) a weekday is the best guess.
    readonly property date wakeDate: new Date(root.wakeMarker * 60000)
    readonly property bool wakeIsCertain: {
        if (StuyCalendar.ready) return StuyCalendar.isSchoolDay(StuyCalendar.dateKey(root.wakeDate));
        const weekday = root.wakeDate.getDay();
        return weekday !== 0 && weekday !== 6;
    }
    readonly property bool freeNight: root.mode === "predict" ? true
        : root.mode === "alarm" ? false
        : !root.wakeIsCertain

    function bedtimeMarker(cycles) {
        return root.wakeMarker - (cycles * root.cycleMinutes + root.fallAsleepMinutes);
    }
    // The other direction: fall asleep now and wake at the end of `cycles` cycles.
    function predictedWakeMarker(cycles) {
        return root.nowMarker + root.fallAsleepMinutes + cycles * root.cycleMinutes;
    }

    // `predicted` only changes what the entry means: a wake time to aim for rather
    // than a bedtime to be in by.
    function describe(cycles, marker, predicted) {
        // The markers are epoch minutes, i.e. UTC: without the local offset a 21:00
        // bedtime reads as 01:00 in New York (UTC-4), which is exactly what it did.
        const offset = -root.now.getTimezoneOffset();
        const minute = (((Math.round(marker) + offset) % 1440) + 1440) % 1440;
        const inBed = cycles * root.cycleMinutes + root.fallAsleepMinutes;
        return {
            cycles: cycles,
            minute: minute,
            label: root.timeLabel(minute),
            inBed: inBed,
            inBedLabel: root.durationLabel(inBed),
            // Negative for a boundary that has already slipped by tonight.
            minutesAway: Math.round(marker - root.nowMarker),
            predicted: predicted === true
        };
    }

    // The headline. School night: the earliest boundary still ahead, i.e. the most
    // cycles still reachable — once the last one slips by, the next chance is tomorrow
    // evening's first. Free night: a full night from now.
    readonly property var next: {
        if (root.freeNight) return root.describe(root.maxCycles, root.predictedWakeMarker(root.maxCycles), true);
        for (let cycles = root.maxCycles; cycles >= root.minCycles; --cycles) {
            const marker = root.bedtimeMarker(cycles);
            if (marker >= root.nowMarker) return root.describe(cycles, marker);
        }
        return root.describe(root.maxCycles, root.bedtimeMarker(root.maxCycles) + 1440);
    }

    // Every option still open: on a school night the bedtimes still ahead, longest
    // night first; on a free night every wake from a full night down to the minimum,
    // so an early appointment can take a shorter one.
    readonly property var options: {
        const list = [];
        for (let cycles = root.maxCycles; cycles >= root.minCycles; --cycles) {
            if (root.freeNight) {
                list.push(root.describe(cycles, root.predictedWakeMarker(cycles), true));
                continue;
            }
            const item = root.describe(cycles, root.bedtimeMarker(cycles));
            if (item.minutesAway >= 0) list.push(item);
        }
        return list.length > 0 ? list : [root.next];
    }

    readonly property string countdownLabel: root.next.minutesAway <= 0
        ? Translation.tr("now")
        : Translation.tr("in") + " " + root.durationLabel(root.next.minutesAway)

    // What the headline means, and the small print under it. Both are decided here so
    // the bar popup and the desktop card cannot drift apart.
    readonly property string titleLabel: root.freeNight
        ? Translation.tr("Likely wake")
        : Translation.tr("Next sleep")
    readonly property string detailLabel: root.freeNight
        ? Translation.tr("if you fall asleep now") + " · " + root.next.inBedLabel
        : root.countdownLabel + " · " + root.next.inBedLabel + " " + Translation.tr("to") + " " + root.wakeLabel
    // The card carries the countdown in its header, so its line only has the night's
    // length to itself.
    readonly property string nightLabel: root.freeNight
        ? root.next.inBedLabel + " " + Translation.tr("in bed")
        : root.next.inBedLabel + " " + Translation.tr("to") + " " + root.wakeLabel

    // A shifted alarm time, for the stepper: the caller writes it back into the config,
    // and every hint re-counts from the new alarm.
    function shiftedWake(deltaMinutes) {
        return root.timeLabel((((root.wakeMinutes + deltaMinutes) % 1440) + 1440) % 1440);
    }

    function timeLabel(minute) {
        const value = ((Math.round(minute) % 1440) + 1440) % 1440;
        return String(Math.floor(value / 60)).padStart(2, "0") + ":" + String(value % 60).padStart(2, "0");
    }

    function durationLabel(minutes) {
        const total = Math.max(0, Math.round(minutes));
        const hours = Math.floor(total / 60);
        const mins = total % 60;
        return (hours > 0 ? hours + "h " : "") + mins + "m";
    }
}
