import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property var tabButtonList: [
        {"name": Translation.tr("Pomodoro"), "icon": "search_activity"},
        {"name": Translation.tr("Stopwatch"), "icon": "timer"},
        {"name": Translation.tr("Countdown"), "icon": "hourglass_top"}
    ]

    function subTabNext() {
        tabBar.incrementCurrentIndex();
    }

    function subTabPrev() {
        tabBar.decrementCurrentIndex();
    }

    /**
     * Keyboard control for the timers, shared by this widget's own focus
     * handling and by the sidebar's bottom group (which forwards keys while it
     * holds focus). Always returns whether the key was used.
     */
    function handleSidebarKey(event) {
        const key = event.key
        if ((key === Qt.Key_PageDown || key === Qt.Key_PageUp) && event.modifiers === Qt.NoModifier) { // Switch tabs
            if (key === Qt.Key_PageDown) tabBar.incrementCurrentIndex()
            else tabBar.decrementCurrentIndex()
            return true
        }
        if (key === Qt.Key_Space || key === Qt.Key_S || key === Qt.Key_Return || key === Qt.Key_Enter) { // Start/pause
            if (tabBar.currentIndex === 0) TimerService.togglePomodoro()
            else if (tabBar.currentIndex === 1) TimerService.toggleStopwatch()
            else TimerService.countdownToggle()
            return true
        }
        if (key === Qt.Key_R) { // Reset
            if (tabBar.currentIndex === 0) TimerService.resetPomodoro()
            else if (tabBar.currentIndex === 1) TimerService.stopwatchReset()
            else TimerService.countdownReset()
            return true
        }
        if (key === Qt.Key_L) { // Record lap
            if (tabBar.currentIndex === 1) {
                TimerService.stopwatchRecordLap()
                return true
            }
            return false
        }
        if (key === Qt.Key_Plus || key === Qt.Key_Equal || key === Qt.Key_Minus) { // Add/remove a minute
            const delta = key === Qt.Key_Minus ? -1 : 1
            if (tabBar.currentIndex === 0) {
                const next = Math.max(1, Math.min(180, (Config.options.time.pomodoro.focus ?? 25) + delta))
                Config.options.time.pomodoro.focus = next
                TimerService.resetPomodoro()
                return true
            }
            if (tabBar.currentIndex === 2) {
                TimerService.addCountdownMinutes(delta)
                return true
            }
            return false
        }
        return false
    }

    Keys.onPressed: (event) => {
        if (root.handleSidebarKey(event)) event.accepted = true
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        SecondaryTabBar {
            id: tabBar
            currentIndex: swipeView.currentIndex

            Repeater {
                model: root.tabButtonList
                delegate: SecondaryTabButton {
                    buttonText: modelData.name
                    buttonIcon: modelData.icon
                }
            }
        }

        SwipeView {
            id: swipeView
            Layout.topMargin: 10
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            clip: true
            currentIndex: tabBar.currentIndex

            // Tabs
            PomodoroTimer {}
            Stopwatch {}
            CountdownTimer {}
        }
    }
}
