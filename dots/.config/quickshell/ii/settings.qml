//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// Adjust this to make the app smaller or larger
//@ pragma Env QT_SCALE_FACTOR=1

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF
import qs.modules.ii.settings

ApplicationWindow {
    id: root

    visible: true
    onClosing: Qt.quit()
    title: "illogical-impulse Settings"

    minimumWidth: 750
    minimumHeight: 500
    width: 1100
    height: 750
    color: Appearance.m3colors.m3background

    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme()
        Config.readWriteDelay = 0 // Settings app always only sets one var at a time so delay isn't needed
        ExtensionManager.watchFileChanges = false // Settings app doesn't need file watching to prevent loops
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut
        border.width: Config.options.settings.borderSize
        border.color: CF.ColorUtils.transparentize(Appearance.getColorFromName(Config.options.settings.borderColor), 0.8)

        SettingsContent {
            anchors.fill: parent
        }
    }
}
