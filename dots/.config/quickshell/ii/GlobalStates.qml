import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root

    property alias sidebarLeftOpen: root.policiesPanelOpen // Until all sidebars naming is fixed
    property alias sidebarRightOpen: root.dashboardPanelOpen // Until all sidebars naming is fixed

    property bool appLauncherOpen: false
    property bool binarySelectorOpen: false
    property string binarySelectorTargetFolderId: ""
    property bool bluetoothConnectionPopupOpen: false
    property var bluetoothConnectionPopupDevice: null
    property bool barOpen: true
    property bool crosshairOpen: false
    property bool mediaControlsOpen: false
    property bool osdBrightnessOpen: false
    property bool osdVolumeOpen: false
    property bool oskOpen: false
    property bool overlayOpen: false
    property bool overviewOpen: false
    property bool regionSelectorOpen: false
    property bool searchOpen: false
    property bool screenLocked: false
    property bool screenLockContainsCharacters: false
    property bool screenUnlockFailed: false
    property bool screenTranslatorOpen: false
    property var screenTranslatorRegionInfo: null
    property bool sessionOpen: false
    property bool superDown: false
    property bool superReleaseMightTrigger: true
    property bool wallpaperSelectorOpen: false
    property bool workspaceShowNumbers: false
    readonly property bool widgetsOccluded: screenLocked || overviewOpen || appLauncherOpen || searchOpen || crosshairOpen || oskOpen || regionSelectorOpen || sessionOpen
    readonly property bool widgetsVisible: !widgetsOccluded

    // Focused window is fullscreen → the bar is covered, so its per-second
    // widgets get culled (BarComponent) and pollers pause (ResourceUsage).
    // Fed by the Hyprland socket2 `fullscreen` event (data 0/1) via onRawEvent.
    property bool fullscreenActive: false
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "fullscreen")
                root.fullscreenActive = event.data === "1";
        }
    }
    // Initial sync — the event only fires on change, not at startup.
    Process {
        command: ["hyprctl", "activewindow", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.fullscreenActive = Number(JSON.parse(text).fullscreen ?? 0) > 0;
                } catch (e) {} // no focused window / non-JSON error output
            }
        }
    }
    property bool settingsOpen: false
    property list<real> visualizerPoints: []
    property bool phoneMicRunning: false
    property bool phoneCameraRunning: false

    property bool dashboardPanelOpen: false // formerly sidebarRightOpen
    property bool policiesPanelOpen: false  // formerly sidebarLeftOpen

    /** AiChat asks for a screen snip to attach; RegionSelector answers. */
    signal snipForAiRequested()

    // P3DROVFX fork additions: detached/pinned sidebar
    property bool policiesDetached: false
    property bool policiesPinned: false
    property bool policiesExtended: false
    readonly property real policiesWidth: Config.options.sidebar.policiesWidth ?? 400

    readonly property bool effectiveLeftOpen: {
        switch (Config.options.sidebar.position) {
            case "default":  return policiesPanelOpen;  
            case "inverted": return dashboardPanelOpen;  
            case "left":     return dashboardPanelOpen || policiesPanelOpen;
            case "right":    return false;
            default:         return policiesPanelOpen;
        }
    }
    readonly property bool effectiveRightOpen: {
        switch (Config.options.sidebar.position) {
            case "default":  return dashboardPanelOpen; 
            case "inverted": return policiesPanelOpen; 
            case "left":     return false;
            case "right":    return dashboardPanelOpen || policiesPanelOpen;
            default:         return dashboardPanelOpen;
        }
    }

    // helper properties
    readonly property bool policiesOnLeft: Config.options.sidebar.position === "default" || Config.options.sidebar.position === "left"
    readonly property bool dashboardOnLeft: Config.options.sidebar.position === "inverted" || Config.options.sidebar.position === "left"

    onPoliciesPanelOpenChanged: {
        if (policiesPanelOpen) {
            if (Config.options.sidebar.position == "right" || Config.options.sidebar.position == "left") {
                GlobalStates.dashboardPanelOpen = false
            }
        }
        
    }

    onDashboardPanelOpenChanged: {
        if (dashboardPanelOpen) {
            Notifications.timeoutAll();
            Notifications.markAllRead();
            if (Config.options.sidebar.position == "right" || Config.options.sidebar.position == "left") {
                GlobalStates.policiesPanelOpen = false
            }
        }
        
    }

    GlobalShortcut {
        name: "workspaceNumber"
        description: "Hold to show workspace numbers, release to show icons"
        onPressed: {
            root.superDown = true
        }
        onReleased: {
            root.superDown = false
        }
    }
}