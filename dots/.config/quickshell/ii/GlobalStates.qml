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
    // Widgets are fully hidden (lock screen / fullscreen window) — the only
    // states where culling is correct. Transient overlays (search, overview,
    // launcher, …) leave them visible, so occlusion culling must not fire there.
    readonly property bool widgetsHidden: screenLocked || fullscreenActive

    // Focused window is fullscreen → the bar is covered, so its per-second
    // widgets get culled (BarComponent) and pollers pause (ResourceUsage).
    // Detection must never cull visibly-present widgets, so: resync from
    // `hyprctl activewindow -j` (focused window is the closest observable
    // proxy) on fullscreen/focus/workspace events, AND re-verify every 2 s
    // while the flag is true (heartbeat; no forks when false). Sync failures
    // leave the flag as-is → fail-open toward SHOWING widgets.
    property bool fullscreenActive: false
    function requestFullscreenSync() {
        if (fsSyncProc.running) { fsSyncQueued = true; return; }
        fsSyncProc.exec(["hyprctl", "activewindow", "-j"]);
    }
    property bool fsSyncQueued: false
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "fullscreen" || event.name === "activewindow"
                || event.name === "activewindowv2" || event.name === "workspace"
                || event.name === "workspacev2")
                fsSyncDebounce.restart();
        }
    }
    // Debounced — focus events churn (window title changes), one fork per burst.
    Timer {
        id: fsSyncDebounce
        interval: 150
        onTriggered: root.requestFullscreenSync()
    }
    // Self-healing: a stale `true` can't outlive 2 s (e.g. workspace switches
    // with no activewindow event, or a dropped sync at startup).
    Timer {
        interval: 2000
        repeat: true
        running: root.fullscreenActive
        onTriggered: root.requestFullscreenSync()
    }
    Process {
        id: fsSyncProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.fullscreenActive = Number(JSON.parse(text).fullscreen ?? 0) > 0;
                } catch (e) {} // no focused window / non-JSON error output
            }
        }
        onExited: {
            if (root.fsSyncQueued) {
                root.fsSyncQueued = false;
                fsSyncProc.exec(["hyprctl", "activewindow", "-j"]);
            }
        }
    }
    // Initial sync — events only fire on change, not at startup.
    Component.onCompleted: root.requestFullscreenSync()
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