import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.ii.bar.weather

import qs.modules.ii.verticalBar as Vertical

Item {
    id: rootItem

    property int barSection // 0: left, 1: center, 2: right
    property var list
    required property var modelData
    required property int index
    property var originalIndex: index
    property bool vertical: false
    property bool highlighted: false

    implicitWidth: wrapper.implicitWidth
    implicitHeight: wrapper.implicitHeight

    function toggleVisible(visibility) {
        visible = visibility;
        const layouts = vertical ? Config.options.bar.verticalLayouts : Config.options.bar.layouts;
        let layout = null;
        if (barSection == 0) layout = layouts.left;
        else if (barSection == 1) layout = layouts.center;
        else if (barSection == 2) layout = layouts.right;
        const entry = layout?.[originalIndex];
        if (entry && entry.visible !== visibility)
            entry.visible = visibility;
    }

    function toggleHighlight(highlight) {
        rootItem.highlighted = highlight;
    }

    property var compMap: ({ // [horizontal, vertical, expressiveHorizontal, expressiveVertical]
            "workspaces": [workspaceComp, workspaceComp, workspaceCompExpressive, workspaceCompExpressive, workspaceCompMinimal, workspaceCompMinimal],
            "music_player": [musicPlayerComp, musicPlayerCompVert, musicPlayerCompExpressive, musicPlayerCompExpressive],
            "system_monitor": [systemMonitorComp, systemMonitorCompVert, systemMonitorComp, systemMonitorCompVert],
            "clock": [clockComp, clockCompVert, clockCompExpressive, clockCompExpressive],
            "battery": [batteryComp, batteryCompVert, batteryCompExpressive, batteryCompExpressive],
            "utility_buttons": [utilityButtonsComp, utilityButtonsComp, utilityButtonsCompExpressive, utilityButtonsCompExpressive],
            "system_tray": [systemTrayComp, systemTrayComp, systemTrayComp, systemTrayComp],
            "active_window": [activeWindowComp, activeWindowComp],
            "date": [dateCompVert, dateCompVert],
            "record_indicator": [recordIndicatorComp, recordIndicatorComp],
            "screen_share_indicator": [screenshareIndicatorComp, screenshareIndicatorComp],
            "timer": [timerComp, timerCompVert],
            "weather": [weatherComp, weatherComp, weatherCompExpressive, weatherCompExpressive],
            "policies_panel_button": [policiesPanelButton, policiesPanelButton, policiesPanelButtonExpressive, policiesPanelButtonExpressive],
            "dashboard_panel_button": [dashboardPanelButton, dashboardPanelButtonVert, dashboardPanelButtonExpressive, dashboardPanelButtonExpressiveVert],
            "network_speed": [networkSpeedComp, networkSpeedComp],
            "aternos": [aternosComp, aternosComp],
            "ai_panel_button": [aiPanelButtonComp, aiPanelButtonComp]
        })

    readonly property bool isMinimal: {
        if (modelData.id === "workspaces" && Config.options.bar.styles.workspaces === "minimal")
            return true;
        return false;
    }

    readonly property bool isExpressive: {
        if (modelData.id === "clock" && Config.options.bar.styles.clock === "expressive")
            return true;
        if (modelData.id === "music_player" && Config.options.bar.styles.media === "expressive")
            return true;
        if (modelData.id === "workspaces" && Config.options.bar.styles.workspaces === "expressive")
            return true;
        if (modelData.id === "utility_buttons" && Config.options.bar.styles.utilButtons === "expressive")
            return true;
        if (modelData.id === "weather" && Config.options.bar.styles.weather === "expressive")
            return true;
        if (modelData.id === "dashboard_panel_button" && Config.options.bar.styles.dashboard === "expressive")
            return true;
        if (modelData.id === "system_monitor" && Config.options.bar.styles.resources === "expressive")
            return true;
        if (modelData.id === "policies_panel_button" && Config.options.bar.styles.policies === "expressive")
            return true;
        if (modelData.id === "battery" && Config.options.bar.styles.battery === "expressive")
            return true;
        if (modelData.id === "system_tray" && Config.options.bar.styles.systray === "expressive")
            return true;
        return false;
    }

    property list<string> primaryBackgroundComps: ["timer", "record_indicator", "screen_share_indicator"] // components that are mostly indicators

    property real startRadius: {
        if (barSection === 0) {
            if (originalIndex == 0)
                return Appearance.rounding.full;
            return Appearance.rounding.verysmall;
        } else if (barSection === 2) {
            let hasVisibleLeft = list.slice(0, originalIndex).some(item => item.visible !== false);
            return hasVisibleLeft ? Appearance.rounding.verysmall : Appearance.rounding.full;
        } else { // barSection 1
            if (list.length === 1)
                return Appearance.rounding.full;
            let hasVisibleLeft = list.slice(0, originalIndex).some(item => item.visible !== false);
            return hasVisibleLeft ? Appearance.rounding.verysmall : Appearance.rounding.full;
        }
    }

    property real endRadius: {
        if (barSection === 2) {
            if (originalIndex == list.length - 1)
                return Appearance.rounding.full;
            return Appearance.rounding.verysmall;
        } else if (barSection === 0) {
            let hasVisibleRight = list.slice(originalIndex + 1).some(item => item.visible !== false);
            return hasVisibleRight ? Appearance.rounding.verysmall : Appearance.rounding.full;
        } else { // barSection 1
            if (list.length === 1)
                return Appearance.rounding.full;
            let hasVisibleRight = list.slice(originalIndex + 1).some(item => item.visible !== false);
            return hasVisibleRight ? Appearance.rounding.verysmall : Appearance.rounding.full;
        }
    }

    BarThemes {
        id: barThemes
    }
    property var activeTheme: barThemes.themes[Config.options.bar.expressiveColorTheme] || barThemes.themes["content"]

    readonly property int barGroupStyle: Config.options.bar.barGroupStyle
    readonly property int barBackgroundStyle: Config.options.bar.barBackgroundStyle
    property color colBackground: Config.options.bar.expressiveColors ? activeTheme.componentBackground : (barGroupStyle == 0 ? Appearance.colors.colLayer1 : (barGroupStyle == 1 && barBackgroundStyle == 1) ? Appearance.colors.colLayer1 : (barGroupStyle == 1) ? Appearance.m3colors.m3surfaceContainerLow : "transparent")

    property color colBackgroundHighlight: {
        if (Config.options.bar.expressiveColors)
            return activeTheme.highlight;
        if (modelData.id === "sports")
            return barGroupStyle == 2 ? "transparent" : Appearance.colors.colPrimaryContainer;
        if (modelData.id === "bluetooth_devices")
            return Qt.lighter(Appearance.m3colors.m3secondaryContainer, 1.2);
        return Appearance.colors.colPrimary;
    }

    property color colOnBackgroundHighlight: {
        if (Config.options.bar.expressiveColors)
            return ColorUtils.getContrastingTextColor(colBackgroundHighlight);
        if (modelData.id === "sports")
            return barGroupStyle == 2 ? Appearance.colors.colOnSurface : Appearance.colors.colOnPrimaryContainer;
        if (modelData.id === "bluetooth_devices")
            return Appearance.m3colors.m3onSecondaryContainer;
        return Appearance.colors.colOnPrimary;
    }

    BarGroup {
        id: wrapper
        vertical: rootItem.vertical
        anchors {
            verticalCenter: root.vertical ? rootItem.verticalCenter : undefined
            horizontalCenter: root.vertical ? undefined : rootItem.horizontalCenter
        }

        padding: (modelData.id === "dashboard_panel_button" || modelData.id === "policies_panel_button") ? 0 : 5
        leftPadding: rootItem.isExpressive ? 0 : padding
        rightPadding: rootItem.isExpressive ? 0 : padding
        topPadding: rootItem.isExpressive ? 0 : padding
        bottomPadding: rootItem.isExpressive ? 0 : padding
        startRadius: rootItem.startRadius
        endRadius: rootItem.endRadius
        colBackground: (rootItem.highlighted || itemLoader.item?.activated || primaryBackgroundComps.includes(modelData.id)) ? rootItem.colBackgroundHighlight : rootItem.colBackground

        Loader {
            id: itemLoader
            active: true
            sourceComponent: {
                BarComponentRegistry._extensionCompVersion; // re-evaluate when extensions change
                let comps = compMap[modelData.id];
                if (!comps)
                    return BarComponentRegistry.getComponentForId(modelData.id, vertical);
                let isVert = vertical ? 1 : 0;
                let isExpressive = rootItem.isExpressive;
                let isMinimal = rootItem.isMinimal;

                if (isMinimal && comps.length > 4 && comps[isVert + 4]) {
                    return comps[isVert + 4];
                }
                if (isExpressive && comps.length > 2 && comps[isVert + 2]) {
                    return comps[isVert + 2];
                }
                return comps[isVert];
            }
            onLoaded: {
                if (item && item.hasOwnProperty("onActivatedColor")) {
                    item.onActivatedColor = Qt.binding(() => rootItem.colOnBackgroundHighlight);
                }
                let extId = BarComponentRegistry.getExtensionIdForComponent(modelData.id);
                if (extId && item) {
                    if ("extensionId" in item) {
                        item.extensionId = extId;
                    } else {
                        Object.defineProperty(item, "extensionId", {
                            value: extId,
                            writable: true,
                            configurable: true,
                            enumerable: true
                        });
                    }
                }
            }
        }
    }

    Component {
        id: weatherComp
        WeatherBar {
            vertical: rootItem.vertical
        }
    }

    Component {
        id: timerComp
        TimerWidget {}
    }
    Component {
        id: timerCompVert
        Vertical.VerticalTimerWidget {}
    }

    Component {
        id: screenshareIndicatorComp
        ScreenShareIndicator {}
    }

    Component {
        id: recordIndicatorComp
        RecordIndicator {
            vertical: rootItem.vertical
        }
    }

    Component {
        id: activeWindowComp
        ActiveWindow {
            vertical: rootItem.vertical
        }
    }

    Component {
        id: systemMonitorComp
        Resources {}
    }
    Component {
        id: systemMonitorCompVert
        Vertical.Resources {}
    }

    Component {
        id: musicPlayerCompVert
        Vertical.VerticalMedia {}
    }
    Component {
        id: musicPlayerComp
        Media {}
    }

    Component {
        id: utilityButtonsComp
        UtilButtons {
            vertical: rootItem.vertical
        }
    }

    Component {
        id: batteryComp
        BatteryIndicator {}
    }
    Component {
        id: batteryCompVert
        Vertical.BatteryIndicator {}
    }

    Component {
        id: clockCompVert
        Vertical.VerticalClockWidget {}
    }
    Component {
        id: clockComp
        ClockWidget {}
    }

    Component {
        id: systemTrayComp
        SysTray {
            vertical: rootItem.vertical
        }
    }

    Component {
        id: dateCompVert
        Vertical.VerticalDateWidget {}
    }

    Component {
        id: workspaceComp
        Workspaces {
            vertical: rootItem.vertical
        }
    }

    Component {
        id: policiesPanelButton
        PoliciesPanelButton {}
    }

    Component {
        id: dashboardPanelButton
        DashboardPanelButton {}
    }
    Component {
        id: dashboardPanelButtonVert
        VerticalDashboardPanelButton {}
    }
    Component {
        id: networkSpeedComp
        NetworkSpeed {
            vertical: rootItem.vertical
        }
    }

    Component {
        id: weatherCompExpressive
        ExpressiveWeatherBar {
            vertical: rootItem.vertical
        }
    }
    Component {
        id: musicPlayerCompExpressive
        ExpressiveMedia {
            vertical: rootItem.vertical
        }
    }
    Component {
        id: utilityButtonsCompExpressive
        ExpressiveUtilButtons {
            vertical: rootItem.vertical
        }
    }
    Component {
        id: clockCompExpressive
        ExpressiveClockWidget {
            vertical: rootItem.vertical
        }
    }
    Component {
        id: workspaceCompMinimal
        MinimalWorkspaces {
            vertical: rootItem.vertical
        }
    }

    Component {
        id: workspaceCompExpressive
        ExpressiveWorkspaces {
            vertical: rootItem.vertical
        }
    }
    Component {
        id: policiesPanelButtonExpressive
        ExpressivePoliciesPanelButton {}
    }
    Component {
        id: dashboardPanelButtonExpressive
        ExpressiveDashboardPanelButton {
            vertical: false
        }
    }
    Component {
        id: dashboardPanelButtonExpressiveVert
        ExpressiveDashboardPanelButton {
            vertical: true
        }
    }
    Component {
        id: batteryCompExpressive
        ExpressiveBattery {
            vertical: rootItem.vertical
        }
    }
    Component {
        id: systemTrayCompExpressive
        ExpressiveSystemTray {
            vertical: rootItem.vertical
        }
    }

    Component {
        id: aternosComp
        Aternos {}
    }

    Component {
        id: aiPanelButtonComp
        AiPanelButton {}
    }
}
