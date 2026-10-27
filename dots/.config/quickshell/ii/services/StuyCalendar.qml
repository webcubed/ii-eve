pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Stuyvesant's 2026-2027 school calendar, read from the same JSON the Sophomore
// Caucus site ships (assets/stuy/calendar.json). Only data and derivations live
// here: block letters, categories, bell schedules and the month grid, so the
// schedule widget and the calendar widget stay in sync.
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

    property bool ready: false
    property var days: ({})
    property var bellSchedules: ({})
    property var regents: []
    property string minDate: ""
    property string maxDate: ""

    readonly property string todayKey: root.dateKey(new Date())

    FileView {
        id: source
        path: Quickshell.shellDir + "/assets/stuy/calendar.json"
        watchChanges: true
        onLoaded: root.apply(source.text())
        onFileChanged: root.apply(source.text())
        onLoadFailed: error => console.warn("StuyCalendar: could not read calendar.json:", error)
    }

    function apply(text) {
        try {
            const parsed = JSON.parse(text);
            const byDate = {};
            const list = parsed.days ?? [];
            for (let i = 0; i < list.length; i++) byDate[list[i].date] = list[i];
            root.days = byDate;
            root.bellSchedules = parsed.bellSchedules ?? ({});
            root.regents = parsed.regentsTimedEvents ?? [];
            root.minDate = list.length > 0 ? list[0].date : "";
            root.maxDate = list.length > 0 ? list[list.length - 1].date : "";
            root.ready = true;
        } catch (error) {
            console.warn("StuyCalendar: invalid calendar.json:", error);
        }
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
