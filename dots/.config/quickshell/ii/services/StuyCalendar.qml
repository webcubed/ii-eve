pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Stuyvesant's 2026-2027 school calendar, read from the same JSON the Sophomore
// Caucus site publishes. Only data and derivations live here: block letters,
// categories, bell schedules and the month grid, so the schedule widget and the
// calendar widget stay in sync.
//
// The published file is the source of truth, not the copy bundled with the shell:
// the school issues calendar revisions through the year (v10 on October 5, v13 on
// October 29 in 2026), so every run re-fetches it and the newest revision wins.
// The bundled copy only seeds the first paint, and the last fetch is cached so a
// boot without network still shows the newest data instead of that seed.
Singleton {
    id: root

    // Catppuccin Macchiato tones, matching the site's block/category colors.
    readonly property var palette: ({
        red: "#ed8796",
        blue: "#8aadf4",
        yellow: "#eed49f",
        sapphire: "#7dc4e4",
        green: "#a6da95",
        mauve: "#c6a0f6",
        subtext: "#a5adcb"
    })

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    readonly property var weekdayNames: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property var shortWeekdayNames: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    // The Sophomore Caucus banner sets its block letters in Google Sans Flex with the
    // round axis pinned — fontVariationSettings: '"ROND" 100, "wght" 700' — which is
    // what over-rounds the bowls of "B2" and "A". The day numbers keep the plainer
    // rounded face; this pair is only ever used for the A/B block letters.
    readonly property string blockFontFamily: "Google Sans Flex"
    readonly property var blockFontAxes: ({ "ROND": 100, "wght": 700 })

    readonly property var categoryLabels: ({
        school_day: "School day",
        holiday: "Holiday",
        recess: "Recess",
        regents: "Regents exams",
        no_students: "No students",
        special_schedule: "Special schedule",
        parent_teacher: "Parent-teacher conferences",
        rating_day: "Rating day",
        last_day: "Last day",
        exam_day: "Exam day",
        professional_development: "Professional development",
        remote_learning: "Remote learning"
    })

    readonly property string remoteUrl: "https://raw.githubusercontent.com/webcubed/sophomore-caucus/refs/heads/main/src/data/calendar.json"
    readonly property string cachePath: Quickshell.cacheDir + "/stuy/calendar.json"
    // Revisions land weeks apart, so polling can be rare; after a miss, retry
    // sooner so a boot that came up before the network did recovers on its own.
    readonly property int refreshInterval: 6 * 60 * 60 * 1000
    readonly property int retryInterval: 15 * 60 * 1000

    property bool ready: false
    // The PDF revision the loaded data describes, e.g. "October 29, 2026, Version 13".
    property string version: ""
    property string versionDate: ""
    property var days: ({})
    property var bellSchedules: ({})
    property var regents: []
    property string minDate: ""
    property string maxDate: ""

    // The date the shell is living in. Reading it from a clock rather than calling
    // `new Date()` once when the singleton loads is what lets the calendars notice
    // midnight: todayKey only changes when the day does.
    readonly property string todayKey: root.dateKey(dayClock.date)

    // Minute precision is all a date needs, and SystemClock re-reads the time every
    // minute, so the binding above rolls over at 00:00 with no timer of its own.
    SystemClock {
        id: dayClock
        precision: SystemClock.Minutes
    }

    // The last successful fetch outranks the bundled copy. A missing cache is the
    // normal state of a first run; FileView reports it itself, so there is nothing
    // to handle here.
    FileView {
        id: cachedSource
        path: root.cachePath
        onLoaded: root.apply(cachedSource.text(), "the cached fetch")
    }

    // The seed: whatever the shell shipped with. Kept under watch so editing the
    // bundled JSON by hand still lands while the shell runs.
    FileView {
        id: bundledSource
        path: Quickshell.shellDir + "/assets/stuy/calendar.json"
        watchChanges: true
        onLoaded: root.apply(bundledSource.text(), "the bundled copy")
        onFileChanged: root.apply(bundledSource.text(), "the bundled copy")
        onLoadFailed: error => console.warn("StuyCalendar: could not read the bundled calendar.json:", error)
    }

    // Three sources race — the bundled copy usually loads first, the cache and the
    // network fetch land later in no fixed order — so the newest revision wins
    // rather than the last arrival. That keeps a cache from before a dotfiles
    // update from undoing it, and the bundled copy from undoing a fresh fetch.
    function apply(text, from) {
        let parsed = null;
        try {
            parsed = JSON.parse(text);
        } catch (error) {
            console.warn("StuyCalendar: ignoring unusable calendar JSON from", from + ":", error);
            return;
        }
        const revision = String(parsed?.calendar?.sourceVersionDate ?? "");
        if (root.ready && revision !== "" && revision < root.versionDate) return;
        // The fetch is on a timer: an unchanged revision should not re-parse the
        // file and re-render every widget bound to it.
        if (text === root._appliedText) return;
        const byDate = {};
        const list = parsed.days ?? [];
        for (let i = 0; i < list.length; i++) byDate[list[i].date] = list[i];
        root.days = byDate;
        root.bellSchedules = parsed.bellSchedules ?? ({});
        root.regents = parsed.regentsTimedEvents ?? [];
        root.minDate = list.length > 0 ? list[0].date : "";
        root.maxDate = list.length > 0 ? list[list.length - 1].date : "";
        root.versionDate = revision;
        root.version = String(parsed?.calendar?.calendarVersion ?? revision);
        root._appliedText = text;
        root.ready = true;
        console.info("StuyCalendar: loaded", root.version, "from", from + ".");
    }
    property string _appliedText: ""

    // Download into a temp file beside the cache, check that it is calendar-shaped,
    // then move it into place: a truncated or HTML-error response can never replace
    // a good cache, and stdout only carries data that already passed both checks.
    function fetchRemote() {
        const script =
            'set -o pipefail; ' +
            'URL="$1"; CACHE="$2"; ' +
            'DIR=${CACHE%/*}; mkdir -p "$DIR" || exit 1; ' +
            'TMP=$(mktemp "$DIR/.calendar.XXXXXX") || exit 1; ' +
            'if ! curl -fsSL --max-time 20 "$URL" -o "$TMP"; then rm -f "$TMP"; exit 1; fi; ' +
            'if ! jq -e \'.days | type == "array" and length > 0\' "$TMP" >/dev/null 2>&1; then rm -f "$TMP"; exit 1; fi; ' +
            'mv -f "$TMP" "$CACHE" || exit 1; ' +
            'cat "$CACHE"';
        // Restart rather than stack: a manual refresh during a slow request would
        // otherwise leave two cursors on the same cache file.
        fetcher.running = false;
        fetcher.command = ["bash", "-c", script, "stuy-calendar-fetch", root.remoteUrl, root.cachePath];
        fetcher.running = true;
    }

    Process {
        id: fetcher
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) root.apply(text, "the published calendar");
            }
        }
        onExited: (code, signal) => {
            if (code === 0) {
                retryTimer.stop();
                return;
            }
            // Offline, DNS not up yet, or an error page: keep the data we have and
            // try again sooner than the regular poll.
            retryTimer.restart();
        }
    }

    Timer {
        id: refreshTimer
        interval: root.refreshInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetchRemote()
    }

    Timer {
        id: retryTimer
        interval: root.retryInterval
        repeat: false
        onTriggered: root.fetchRemote()
    }

    // ---- Dates -----------------------------------------------------------

    function pad(number) {
        return number < 10 ? "0" + number : String(number);
    }
    function dateKey(date) {
        return date.getFullYear() + "-" + root.pad(date.getMonth() + 1) + "-" + root.pad(date.getDate());
    }
    function parseKey(key) {
        const parts = String(key).split("-");
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    }
    function addDays(key, delta) {
        const date = root.parseKey(key);
        date.setDate(date.getDate() + delta);
        return root.dateKey(date);
    }
    function weekdayName(key) {
        return root.weekdayNames[root.parseKey(key).getDay()];
    }
    // The card header is narrow: the year is only worth its width when the day is
    // not in the current year.
    function formatDate(key) {
        const date = root.parseKey(key);
        const label = root.monthNames[date.getMonth()] + " " + date.getDate();
        return date.getFullYear() === new Date().getFullYear()
            ? label
            : label + ", " + date.getFullYear();
    }
    function entryFor(key) {
        return root.days[key] ?? null;
    }

    // Mornings a student has to be at school. Regular days, special schedules, remote
    // days and the last day all start early; holidays, recess, regents, exam days and
    // the no-student days do not. Weekends are not in the file at all, and a date past
    // the end of the calendar (summer) is not a school day either.
    readonly property var schoolDayCategories: ["school_day", "special_schedule", "remote_learning", "last_day"]
    function isSchoolDay(key) {
        const entry = root.days[key];
        return !!entry && root.schoolDayCategories.indexOf(entry.category) >= 0;
    }

    // Always 42 cells (six weeks) so the month never changes height under the
    // cursor: empty leading/trailing cells are null.
    function monthGrid(year, month) {
        const cells = [];
        const firstWeekday = new Date(year, month, 1).getDay();
        const dayCount = new Date(year, month + 1, 0).getDate();
        for (let i = 0; i < firstWeekday; i++) cells.push(null);
        for (let day = 1; day <= dayCount; day++) cells.push({ day: day, key: root.dateKey(new Date(year, month, day)) });
        while (cells.length < 42) cells.push(null);
        return cells;
    }

    // ---- School calendar -------------------------------------------------

    function blockColor(block) {
        if (!block) return root.palette.subtext;
        if (block.indexOf("A") === 0) return root.palette.red;
        if (block.indexOf("B") === 0) return root.palette.blue;
        return root.palette.subtext;
    }
    function categoryLabel(category) {
        return root.categoryLabels[category] ?? (category ?? "");
    }
    // Same mapping as the site: red no-school, yellow exams/regents,
    // sapphire special schedules, green last day.
    function categoryDot(category) {
        switch (category) {
        case "holiday":
        case "no_students":
        case "recess":
        case "professional_development":
            return root.palette.red;
        case "regents":
        case "exam_day":
        case "parent_teacher":
        case "rating_day":
            return root.palette.yellow;
        case "special_schedule":
            return root.palette.sapphire;
        case "last_day":
            return root.palette.green;
        default:
            return "";
        }
    }

    // ---- Bell schedules --------------------------------------------------

    function bellSchedule(scheduleType) {
        return scheduleType ? (root.bellSchedules[scheduleType] ?? null) : null;
    }
    function bellRows(scheduleType) {
        const bell = root.bellSchedule(scheduleType);
        if (!bell) return [];
        const rows = [];
        const periods = bell.periods ?? [];
        for (let i = 0; i < periods.length; i++) {
            rows.push({ label: String(i + 1), start: periods[i][0], end: periods[i][1], special: false, summary: "" });
        }
        const extra = bell.additionalEvents ?? [];
        for (let i = 0; i < extra.length; i++) {
            rows.push({ label: "HR", start: extra[i].start, end: extra[i].end, special: true, summary: extra[i].summary ?? "" });
        }
        rows.sort((a, b) => a.start.localeCompare(b.start));
        return rows;
    }
    function minutesOf(time) {
        if (!time) return -1;
        const parts = String(time).split(":");
        return Number(parts[0]) * 60 + Number(parts[1]);
    }
    function currentRowIndex(rows, nowMinutes) {
        for (let i = 0; i < rows.length; i++) {
            if (nowMinutes >= root.minutesOf(rows[i].start) && nowMinutes <= root.minutesOf(rows[i].end)) return i;
        }
        return -1;
    }
    function nextRowIndex(rows, nowMinutes) {
        for (let i = 0; i < rows.length; i++) {
            if (root.minutesOf(rows[i].start) > nowMinutes) return i;
        }
        return -1;
    }
}
