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

    // The desktop background is a layer-shell surface with no keyboard focus by
    // default, which left its text inputs (notes, to-do, the world clock's
    // timezone search) unable to receive typing. Raised only while one of them is
    // being edited, so ordinary widget clicks do not steal focus from the active
    // window.
    property bool desktopWidgetKeyboardFocus: false

    property bool appLauncherOpen: false
    property bool binarySelectorOpen: false
    property string binarySelectorTargetFolderId: ""
    property bool bluetoothConnectionPopupOpen: false
    property var bluetoothConnectionPopupDevice: null
    property bool barOpen: true
    property bool crosshairOpen: false
    property bool mediaControlsOpen: false
    // Where the media pill sat when it was clicked, so the controls panel can line up with
    // it. Deliberately transient: screen coordinates are meaningless in the next session
    // (another layout, another monitor), and a stale persisted rect used to park the panel
    // in the top-left corner.
    property var mediaPopupRect: Qt.rect(0, 0, 0, 0)
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
    onFullscreenActiveChanged: console.log(`[cull] fullscreenActive = ${fullscreenActive}`)
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
                    const fs = JSON.parse(text).fullscreen;
                    // hyprctl fullscreen enum: 0 = none, 1 = MAXIMIZED, 2 = FULLSCREEN.
                    // Maximized windows respect the bar's exclusive zone (bar stays
                    // visible) — only true fullscreen covers it, so only 2 culls.
                    root.fullscreenActive = Number(fs ?? 0) === 2;
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
    property var settingsTarget: null

    function openSettingsAt(pageId, label, section, subsection) {
        root.settingsOpen = true;
        Qt.callLater(() => {
            root.settingsTarget = { page: pageId, label: label ?? "", section: section ?? "", subsection: subsection ?? "" };
        });
    }
    function openSettingsPage(pageId, subPage, sectionTitle) {
        openSettingsAt(pageId, "", sectionTitle ?? "", subPage ?? "");
    }
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

    // Actions selectable for the bottom hot corners (settings → Interface → Hot Corners).
    // Values are GlobalStates property names so toggleState() can flip them by name.
    readonly property var hotCornerOptions: [
        { displayName: Translation.tr("None"), value: "none" },
        { displayName: Translation.tr("Left Sidebar"), value: "sidebarLeftOpen" },
        { displayName: Translation.tr("Right Sidebar"), value: "sidebarRightOpen" },
        { displayName: Translation.tr("Overview"), value: "overviewOpen" },
        { displayName: Translation.tr("Wallpaper Selector"), value: "wallpaperSelectorOpen" },
        { displayName: Translation.tr("Media Controls"), value: "mediaControlsOpen" },
        { displayName: Translation.tr("Overlay"), value: "overlayOpen" },
        { displayName: Translation.tr("Screenshot Region"), value: "regionSelectorOpen" },
        { displayName: Translation.tr("Screen Translator"), value: "screenTranslatorOpen" },
        { displayName: Translation.tr("On-screen Keyboard"), value: "oskOpen" },
        { displayName: Translation.tr("Session Menu"), value: "sessionOpen" }
    ]

    function toggleState(name) {
        if (!name || name === "none")
            return
        // Only allow known panel states: a stale/typo'd config value must not
        // scribble arbitrary properties onto this singleton.
        if (!root.hotCornerOptions.some(option => option.value === name))
            return
        root[name] = !root[name]
    }

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
