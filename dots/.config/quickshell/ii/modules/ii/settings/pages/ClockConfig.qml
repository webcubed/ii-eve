import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * Clock settings. Currently the bedtime planner, including the intrusive mode
 * that takes over the screen (and can force a shutdown) once bedtime passes.
 */
ContentPage {
    id: page
    forceWidth: true

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 20

        ContentSection {
            icon: "bedtime"
            shape: MaterialShape.Shape.Cookie12Sided
            title: Translation.tr("Bedtime")
            hint: Translation.tr("Winds the desktop down at a fixed time. Reminders, a full-screen prompt and an optional forced shutdown hang off this.")

            GroupedList {
                ConfigSwitch {
                    Layout.fillWidth: true
                    buttonIcon: "bedtime"
                    text: Translation.tr("Enable bedtime")
                    checked: Config.options.clockApp.bedtime.enable
                    onCheckedChanged: {
                        if (Config.options.clockApp.bedtime.enable === checked) return
                        Config.options.clockApp.bedtime.enable = checked
                    }
                }

                TimeField {
                    Layout.fillWidth: true
                    icon: "schedule"
                    text: Translation.tr("Bedtime")
                    value: Config.options.clockApp.bedtime.time
                    onEdited: (value) => Config.options.clockApp.bedtime.time = value
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "timer"
                    text: Translation.tr("Wind-down before bedtime (minutes)")
                    value: Config.options.clockApp.bedtime.windDownMinutes
                    from: 0
                    to: 180
                    stepSize: 5
                    onValueChanged: {
                        if (Config.options.clockApp.bedtime.windDownMinutes !== value)
                            Config.options.clockApp.bedtime.windDownMinutes = value
                    }
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "notifications_active"
                    text: Translation.tr("Remind me every (minutes)")
                    value: Config.options.clockApp.bedtime.remindEveryMinutes
                    from: 0
                    to: 120
                    stepSize: 5
                    onValueChanged: {
                        if (Config.options.clockApp.bedtime.remindEveryMinutes !== value)
                            Config.options.clockApp.bedtime.remindEveryMinutes = value
                    }
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "wb_twilight"
                    text: Translation.tr("Night ends at (hour)")
                    value: Config.options.clockApp.bedtime.nightEndsHour
                    from: 0
                    to: 12
                    stepSize: 1
                    onValueChanged: {
                        if (Config.options.clockApp.bedtime.nightEndsHour !== value)
                            Config.options.clockApp.bedtime.nightEndsHour = value
                    }
                }
            }
        }

        ContentSection {
            icon: "screen_lock_portrait"
            shape: MaterialShape.Shape.Cookie7Sided
            title: Translation.tr("Intrusive mode")
            hint: Translation.tr("Past bedtime a full-screen prompt takes over, with a few short snoozes, then a countdown and a forced shutdown.")

            GroupedList {
                ConfigSwitch {
                    Layout.fillWidth: true
                    buttonIcon: "screen_lock_portrait"
                    text: Translation.tr("Take over the screen past bedtime")
                    checked: Config.options.clockApp.bedtime.intrusive
                    onCheckedChanged: {
                        if (Config.options.clockApp.bedtime.intrusive === checked) return
                        Config.options.clockApp.bedtime.intrusive = checked
                    }
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "snooze"
                    text: Translation.tr("Snooze length (minutes)")
                    enabled: Config.options.clockApp.bedtime.intrusive
                    value: Config.options.clockApp.bedtime.snoozeMinutes
                    from: 1
                    to: 60
                    stepSize: 1
                    onValueChanged: {
                        if (Config.options.clockApp.bedtime.snoozeMinutes !== value)
                            Config.options.clockApp.bedtime.snoozeMinutes = value
                    }
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "repeat"
                    text: Translation.tr("Snoozes allowed")
                    enabled: Config.options.clockApp.bedtime.intrusive
                    value: Config.options.clockApp.bedtime.maxSnoozes
                    from: 0
                    to: 10
                    stepSize: 1
                    onValueChanged: {
                        if (Config.options.clockApp.bedtime.maxSnoozes !== value)
                            Config.options.clockApp.bedtime.maxSnoozes = value
                    }
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "power_settings_new"
                    text: Translation.tr("Shutdown countdown (seconds)")
                    enabled: Config.options.clockApp.bedtime.intrusive
                    value: Config.options.clockApp.bedtime.shutdownGraceSeconds
                    from: 0
                    to: 300
                    stepSize: 5
                    onValueChanged: {
                        if (Config.options.clockApp.bedtime.shutdownGraceSeconds !== value)
                            Config.options.clockApp.bedtime.shutdownGraceSeconds = value
                    }
                }
            }
        }
    }
}
