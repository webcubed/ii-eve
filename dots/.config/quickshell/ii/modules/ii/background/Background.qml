pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.utils //FIXME. remove
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.common.functions as CF
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.modules.ii.background.widgets
import qs.modules.ii.background.widgets.clock
import qs.modules.ii.background.widgets.weather
import qs.modules.ii.background.widgets.media
import qs.modules.ii.background.widgets.calendar
import qs.modules.ii.background.widgets.images
import qs.modules.ii.background.widgets.notes
import qs.modules.ii.background.widgets.resources
import qs.modules.ii.background.widgets.usercard
import qs.modules.ii.background.widgets.visualizer
import qs.modules.ii.background.widgets.worldclock
import qs.modules.ii.background.widgets.timer
import qs.modules.ii.background.widgets.timers
import qs.modules.ii.background.widgets.customtext
import qs.modules.ii.background.widgets.todo
import qs.modules.ii.background.widgets.stuy

Variants {
    id: root
    model: Quickshell.screens
    
    PanelWindow {
        id: bgRoot

        required property var modelData

        // Hide when fullscreen
        property list<HyprlandWorkspace> workspacesForMonitor: Hyprland.workspaces.values.filter(workspace => workspace.monitor && workspace.monitor.name == monitor.name)
        property var activeWorkspaceWithFullscreen: workspacesForMonitor.filter(workspace => ((workspace.toplevels.values.filter(window => window.wayland?.fullscreen)[0] != undefined) && workspace.active))[0]
        visible: GlobalStates.screenLocked || (!(activeWorkspaceWithFullscreen != undefined)) || !Config?.options.background.hideWhenFullscreen

        // The background normally never takes keyboard focus, so clicking a card
        // leaves focus with the active window. Widget text inputs raise the flag
        // while they are open; on-demand then lets the click that lands in the
        // input focus it, without holding the keyboard hostage once focus moves
        // back to an app window.
        WlrLayershell.keyboardFocus: GlobalStates.desktopWidgetKeyboardFocus
            ? WlrKeyboardFocus.OnDemand
            : WlrKeyboardFocus.None

        // Workspaces
        property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)

        readonly property int activeWorkspaceId: monitor?.activeWorkspace?.id ?? -1

        readonly property bool isCovered: {
            if (activeWorkspaceId === -1 || !monitor) return false;
            return HyprlandData.windowList.some(w => w.workspace?.id === activeWorkspaceId && w.monitor === monitor.id && !w.floating);
        }

        property list<var> relevantWindows: HyprlandData.windowList.filter(win => win.monitor == monitor?.id && win.workspace.id >= 0).sort((a, b) => a.workspace.id - b.workspace.id)
        property int firstWorkspaceId: relevantWindows[0]?.workspace.id || 1
        property int lastWorkspaceId: relevantWindows[relevantWindows.length - 1]?.workspace.id || 10

        // Wallpaper
        property bool wallpaperIsVideo: Config.options.background.wallpaperPath.endsWith(".mp4") || Config.options.background.wallpaperPath.endsWith(".webm") || Config.options.background.wallpaperPath.endsWith(".mkv") || Config.options.background.wallpaperPath.endsWith(".avi") || Config.options.background.wallpaperPath.endsWith(".mov")
        property string wallpaperPath: wallpaperIsVideo ? Config.options.background.thumbnailPath : Config.options.background.wallpaperPath
        property bool wallpaperSafetyTriggered: {
            const enabled = Config.options.workSafety.enable.wallpaper;
            const sensitiveWallpaper = (CF.StringUtils.stringListContainsSubstring(wallpaperPath.toLowerCase(), Config.options.workSafety.triggerCondition.fileKeywords));
            const sensitiveNetwork = (CF.StringUtils.stringListContainsSubstring(Network.networkName.toLowerCase(), Config.options.workSafety.triggerCondition.networkNameKeywords));
            return enabled && sensitiveWallpaper && sensitiveNetwork;
        }
        property real wallpaperToScreenRatio: Math.min(wallpaperWidth / screen.width, wallpaperHeight / screen.height)
        property real preferredWallpaperScale: Config.options.background.parallax.workspaceZoom
        property real effectiveWallpaperScale: 1 // Some reasonable init value, to be updated
        property int wallpaperWidth: modelData.width // Some reasonable init value, to be updated
        property int wallpaperHeight: modelData.height // Some reasonable init value, to be updated
        property real movableXSpace: ((wallpaperWidth / wallpaperToScreenRatio * effectiveWallpaperScale) - screen.width) / 2
        property real movableYSpace: ((wallpaperHeight / wallpaperToScreenRatio * effectiveWallpaperScale) - screen.height) / 2

        readonly property bool verticalParallax: (Config.options.background.parallax.autoVertical && wallpaperHeight > wallpaperWidth) || Config.options.background.parallax.vertical
        // Colors
        property bool shouldBlur: (GlobalStates.screenLocked && Config.options.lock.blur.enable)
        property color dominantColor: Appearance.colors.colPrimary // Default, to be changed
        property bool dominantColorIsDark: dominantColor.hslLightness < 0.5
        property color colText: {
            if (wallpaperSafetyTriggered)
                return CF.ColorUtils.mix(Appearance.colors.colOnLayer0, Appearance.colors.colPrimary, 0.75);
            return (GlobalStates.screenLocked && shouldBlur) ? Appearance.colors.colOnLayer0 : CF.ColorUtils.colorWithLightness(Appearance.colors.colPrimary, (dominantColorIsDark ? 0.8 : 0.12));
        }
        Behavior on colText {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        readonly property bool isScrollingLayout: Persistent.states.hyprland.layout === "scrolling"

        property var zoomLevels: {  // has to be reverted compared to background
            "in": { default: 1.04, zoomed: 1 },
            "out": { default: 1, zoomed: 1.04 }
        }

        property real defaultRatio: zoomInStyle ? zoomLevels.in.default : zoomLevels.out.default
        property real zoomedRatio: zoomInStyle ? zoomLevels.in.zoomed : zoomLevels.out.zoomed

        readonly property bool zoomInStyle: Config.options.overview.scrollingStyle.zoomStyle === "in"
        readonly property bool showOpeningAnimation: Config.options.overview.showOpeningAnimation

        property bool overviewOpen: GlobalStates.overviewOpen

        property real scaleAnimated: GlobalStates.overviewOpen && showOpeningAnimation ? zoomedRatio : defaultRatio
        Behavior on scaleAnimated {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        // Layer props
        screen: modelData
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: (GlobalStates.screenLocked && !scaleAnim.running) ? WlrLayer.Top : WlrLayer.Bottom
        // WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell:background"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: {
            if (!bgRoot.wallpaperSafetyTriggered || bgRoot.wallpaperIsVideo)
                return "transparent";
            return CF.ColorUtils.mix(Appearance.colors.colLayer0, Appearance.colors.colPrimary, 0.75);
        }
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        onWallpaperPathChanged: {
            bgRoot.updateZoomScale();
            // Clock position gets updated after zoom scale is updated
        }

        // Wallpaper zoom scale
        function updateZoomScale() {
            getWallpaperSizeProc.path = bgRoot.wallpaperPath;
            getWallpaperSizeProc.running = true;
        }
        Process {
            id: getWallpaperSizeProc
            property string path: bgRoot.wallpaperPath
            command: ["magick", "identify", "-format", "%w %h", path]
            stdout: StdioCollector {
                id: wallpaperSizeOutputCollector
                onStreamFinished: {
                    const output = wallpaperSizeOutputCollector.text;
                    const [width, height] = output.split(" ").map(Number);
                    const [screenWidth, screenHeight] = [bgRoot.screen.width, bgRoot.screen.height];
                    bgRoot.wallpaperWidth = width;
                    bgRoot.wallpaperHeight = height;

                    if (width <= screenWidth || height <= screenHeight) {
                        // Undersized/perfectly sized wallpapers
                        bgRoot.effectiveWallpaperScale = Math.max(screenWidth / width, screenHeight / height);
                    } else {
                        // Oversized = can be zoomed for parallax, yay
                        bgRoot.effectiveWallpaperScale = Math.min(bgRoot.preferredWallpaperScale, width / screenWidth, height / screenHeight);
                    }
                }
            }
        }

        property bool mediaModeOpen: mediaModeLoader.active && MprisController.activePlayer
        // Cull only when a fullscreen window covers the desktop, not on transient overlays
        // like search. The lock screen is excluded on purpose: while locked each widget
        // decides for itself through `visibleWhenLocked`, so a global cull would also hide
        // the clock the lock screen asks for.
        readonly property bool widgetsOccluded: !GlobalStates.screenLocked
            && GlobalStates.widgetsHidden
            && Config.options.background.widgets.cullWhenOccluded
        property bool draggingWidget: false
        property var draggingWidgetCell: Qt.point(-1, -1) // {x: col, y: row} or invalid
        property var draggingWidgetSpan: Qt.point(1, 1) // footprint of the card being dragged, in cells

        // Bar-aware widget grid. The bar is its own full-width surface, so reserve its
        // band before laying widgets out; otherwise the first row of cards ends up
        // underneath it. Everything outside that band belongs to the grid: the last
        // column/row is stretched by the rounding remainder so the lines reach the
        // screen edges instead of stopping at a dead strip. Shared by the overlay, the
        // drag hitbox and every widget (see AbstractBackgroundWidget.qml) so all three
        // agree on one set of lines.
        readonly property real gridInsetTop: (!Config.options.bar.vertical && !Config.options.bar.bottom)
            ? Appearance.sizes.barHeight : 0
        readonly property real gridInsetBottom: (!Config.options.bar.vertical && Config.options.bar.bottom)
            ? Appearance.sizes.barHeight : 0
        readonly property real gridAvailableWidth: Math.max(WidgetGrid.cellWidth, screen.width)
        readonly property real gridAvailableHeight: Math.max(WidgetGrid.cellHeight, screen.height - gridInsetTop - gridInsetBottom)
        readonly property int gridColumns: WidgetGrid.effectiveColumns(gridAvailableWidth, Config.options.background.widgets.grid.columns)
        readonly property int gridRows: WidgetGrid.effectiveRows(gridAvailableHeight, Config.options.background.widgets.grid.rows)
        readonly property real gridCellWidth: WidgetGrid.fittedCellWidth(gridAvailableWidth, gridColumns)
        readonly property real gridCellHeight: WidgetGrid.fittedCellHeight(gridAvailableHeight, gridRows)
        readonly property real gridOriginX: 0
        readonly property real gridOriginY: gridInsetTop
        function gridSpanWidth(cells) { return Math.round(cells * gridCellWidth - WidgetGrid.gutter) }
        function gridSpanHeight(cells) { return Math.round(cells * gridCellHeight - WidgetGrid.gutter) }
        onMediaModeOpenChanged: {
            if (!mediaModeOpen && Config.options.appearance.palette.type.startsWith("scheme")) {
                Wallpapers.apply(Config.options.background.wallpaperPath)
                LyricsService.shellColorChanged = false
            }
        }

        property var _extensionBgWidgetEntries: []
        property var _pendingWidgetSaves: ({})

        Timer {
            id: bgWidgetSaveTimer
            interval: 300
            repeat: false
            onTriggered: {
                for (let key in bgRoot._pendingWidgetSaves) {
                    let p = bgRoot._pendingWidgetSaves[key]
                    ExtensionManager.saveExtensionWidgetConfig(p.extId, p.wid, p.config)
                }
                bgRoot._pendingWidgetSaves = {}
            }
        }

        function refreshExtensionBgWidgets() {
            // Destroy all existing extension widget objects
            for (let i = 0; i < _extensionBgWidgetEntries.length; i++) {
                let entry = _extensionBgWidgetEntries[i]
                if (entry) {
                    if (entry.cfg) entry.cfg.destroy()
                    if (entry.widget) entry.widget.destroy()
                }
            }
            _extensionBgWidgetEntries = []

            let list = ExtensionManager.getContributionPoint("backgroundWidgets")

            for (let wi = 0; wi < list.length; wi++) {
                let entry = list[wi]
                let fullPath = entry.fullPath
                let extId = entry.extensionId
                let wid = entry.identifier
                let x = entry.x
                let y = entry.y
                let strat = entry.placementStrategy || "free"

                let comp = ExtensionManager.loadExtensionQmlComponent(fullPath)

                let createWidget = (comp, entry, fullPath, extId, wid, x, y, strat) => {
                    let savedWidgetConfig = ExtensionManager.getExtensionWidgetConfig(extId, wid)
                    let savedX = savedWidgetConfig ? savedWidgetConfig.x : x
                    let savedY = savedWidgetConfig ? savedWidgetConfig.y : y
                    let qml = 'import QtQml; QtObject { property bool enable: true; property real x: ' + savedX + '; property real y: ' + savedY + '; property string placementStrategy: "' + strat + '" }'
                    let cfg = Qt.createQmlObject(qml,bgRoot)

                    let onPosChanged = () => {
                        bgRoot._pendingWidgetSaves[extId + "/" + wid] = {
                            extId: extId,
                            wid: wid,
                            config: { enable: cfg.enable, x: cfg.x, y: cfg.y }
                        }
                        bgWidgetSaveTimer.restart()
                    }
                    cfg.xChanged.connect(onPosChanged)
                    cfg.yChanged.connect(onPosChanged)

                    let widget = comp.createObject(widgetCanvas, {
                        configEntry: cfg,
                        bgRoot: bgRoot,
                        screenWidth: bgRoot.screen.width,
                        screenHeight: bgRoot.screen.height,
                        scaledScreenWidth: bgRoot.screen.width,
                        scaledScreenHeight: bgRoot.screen.height,
                        wallpaperScale: bgRoot.effectiveWallpaperScale
                    })

                    if (widget && extId) {
                        if ("extensionId" in widget) {
                            widget.extensionId = extId
                        } else {
                            Object.defineProperty(widget, "extensionId", {
                                value: extId,
                                writable: true,
                                configurable: true,
                                enumerable: true
                            })
                        }
                        let entries = _extensionBgWidgetEntries.slice()
                        entries.push({ widget: widget, cfg: cfg })
                        _extensionBgWidgetEntries = entries
                    }
                }

                if (comp.status === Component.Ready) {
                    createWidget(comp, entry, fullPath, extId, wid, x, y, strat)
                } else if (comp.status === Component.Error) {
                    console.warn("Background: failed to load extension widget component for", extId, wid, ":", comp.errorString())
                } else {
                    comp.statusChanged.connect(() => {
                        if (comp.status === Component.Ready) {
                            createWidget(comp, entry, fullPath, extId, wid, x, y, strat)
                        } else if (comp.status === Component.Error) {
                            console.warn("Background: async component error for", extId, wid, ":", comp.errorString())
                        }
                    })
                }
            }

        }

        Component.onCompleted: {
            refreshExtensionBgWidgets()
            if (!mediaModeOpen && Config.options.appearance.palette.type.startsWith("scheme")) {
                Wallpapers.apply(Config.options.background.wallpaperPath)
            }
        }

        Connections {
            target: ExtensionManager
            function onRefreshExtensions() { refreshExtensionBgWidgets() }
        }

        Item {
            id: wallpaperItem
            anchors.fill: parent
            clip: true
            scale: showOpeningAnimation && overviewOpen && bgRoot.isScrollingLayout ? zoomedRatio : defaultRatio
            opacity: mediaModeOpen ? 0 : 1
            
            Behavior on opacity {
                NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
            }

            Behavior on scale {
                animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
            }

            // Wallpaper
            TransitionImage {
                id: wallpaper
                visible: opacity > 0 && !blurLoader.active && !bgRoot.wallpaperIsVideo
                opacity: !bgRoot.wallpaperIsVideo ? 1 : 0
                // Range = groups that workspaces span on
                property int chunkSize: Config?.options.bar.workspaces.shown ?? 10
                property int lower: Math.floor(bgRoot.firstWorkspaceId / chunkSize) * chunkSize
                property int upper: Math.ceil(bgRoot.lastWorkspaceId / chunkSize) * chunkSize
                property int range: upper - lower
                property real valueX: {
                    let result = 0.5;
                    if (Config.options.background.parallax.enableWorkspace && !bgRoot.verticalParallax) {
                        result = ((bgRoot.monitor.activeWorkspace?.id - lower) / range);

                    }
                    return result;
                }
                property real sidebarOffsetX: {
                    if (!Config.options.background.parallax.enableSidebar) return 0;
                    return (0.15 * GlobalStates.effectiveRightOpen - 0.15 * GlobalStates.effectiveLeftOpen);

                }
                property real valueY: {
                    let result = 0.5;
                    if (Config.options.background.parallax.enableWorkspace && bgRoot.verticalParallax) {
                        result = ((bgRoot.monitor.activeWorkspace?.id - lower) / range);
                    }
                    return result;
                }
                property real effectiveValueX: Math.max(0, Math.min(1, valueX)) + sidebarOffsetX
                property real effectiveValueY: Math.max(0, Math.min(1, valueY))
                x: -(bgRoot.movableXSpace) - (effectiveValueX - 0.5) * 2 * bgRoot.movableXSpace
                y: -(bgRoot.movableYSpace) - (effectiveValueY - 0.5) * 2 * bgRoot.movableYSpace

                imageSource: bgRoot.wallpaperSafetyTriggered ? "" : bgRoot.wallpaperPath
                animated: !bgRoot.wallpaperIsVideo
                fillMode: Image.PreserveAspectCrop
                Behavior on x {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on width {
                    NumberAnimation {
                        duration: 800
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on height {
                    NumberAnimation {
                        duration: 800
                        easing.type: Easing.OutCubic
                    }
                }
                width: bgRoot.wallpaperWidth / bgRoot.wallpaperToScreenRatio * bgRoot.effectiveWallpaperScale
                height: bgRoot.wallpaperHeight / bgRoot.wallpaperToScreenRatio * bgRoot.effectiveWallpaperScale
            }

            Loader {
                id: blurLoader
                active: Config.options.lock.blur.enable && (GlobalStates.screenLocked || scaleAnim.running)
                anchors.fill: wallpaper
                scale: GlobalStates.screenLocked ? Config.options.lock.blur.extraZoom : 1
                Behavior on scale {
                    NumberAnimation {
                        id: scaleAnim
                        duration: 400
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
                    }
                }
                sourceComponent: GaussianBlur {
                    source: wallpaper
                    radius: GlobalStates.screenLocked ? Config.options.lock.blur.radius : 0
                    samples: Math.max(1, Math.round(Config.options.lock.blur.size ?? 20))

                    Rectangle {
                        opacity: GlobalStates.screenLocked ? 1 : 0
                        anchors.fill: parent
                        color: CF.ColorUtils.transparentize(Appearance.colors.colLayer0, 0.7)
                    }
                }
            }

            // Widgets live in screen space, not wallpaper space. Their grid slots, the
            // alignment overlay and the drag hitbox all share the same origin as the real
            // screen, so a card cannot drift under the bar or past an edge when the
            // wallpaper is zoomed or has a different aspect ratio to the monitor.
            WidgetCanvas {
                id: widgetCanvas
                anchors.fill: parent
                readonly property real parallaxFactor: Config.options.background.parallax.widgetsFactor
                // Every card shares this one offset: the wallpaper drifts by the parallax
                // factor, and the cards drift with it as a block instead of each widget
                // deciding its own position.
                transform: Translate {
                    x: (wallpaper.effectiveValueX - 0.5) * -2 * bgRoot.movableXSpace * widgetCanvas.parallaxFactor
                    y: (wallpaper.effectiveValueY - 0.5) * -2 * bgRoot.movableYSpace * widgetCanvas.parallaxFactor
                    Behavior on x {
                        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                    }
                    Behavior on y {
                        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                    }
                }

                // Grid overlay for visual alignment — only shows while dragging a widget
                Canvas {
                    id: gridOverlay
                    width: parent.width
                    height: parent.height
                    z: 100
                    visible: Config.options.background.widgets.grid.enabled
                        && Config.options.background.showGrid
                        && !Config.options.background.widgetsLocked
                        && bgRoot.draggingWidget

                    onWidthChanged: if (visible) requestPaint()
                    onHeightChanged: if (visible) requestPaint()
                    onVisibleChanged: {
                        if (visible) {
                            Qt.callLater(() => requestPaint());
                        }
                    }
                    
                    // Trigger repaint when grid config changes (poll since JsonObject may not emit signals)
                    Timer {
                        id: gridUpdateTimer
                        interval: 200
                        repeat: true
                        running: gridOverlay.visible
                        onTriggered: { if (gridOverlay.visible) gridOverlay.requestPaint(); }
                    }

                    // Repaint when draggingWidget changes (for immediate grid appearance)
                    Connections {
                        target: bgRoot
                        function onDraggingWidgetChanged() {
                            if (gridOverlay.visible) {
                                gridOverlay.requestPaint();
                                Qt.callLater(() => gridOverlay.requestPaint());
                            }
                        }
                    }
                    
                    onPaint: {
                        var ctx = getContext('2d');
                        ctx.clearRect(0, 0, width, height);
                        if (!Config.options.background.widgets.grid.enabled || Config.options.background.widgetsLocked) return;
                        var cols = bgRoot.gridColumns;
                        var rows = bgRoot.gridRows;
                        var originX = bgRoot.gridOriginX;
                        var originY = bgRoot.gridOriginY;
                        var cellW = bgRoot.gridCellWidth;
                        var cellH = bgRoot.gridCellHeight;
                        // Full cell lines, plus the finer snap steps the cards actually
                        // move by, so the resolution of a drag is visible.
                        var subdivisions = WidgetGrid.subdivisions;
                        var snapW = cellW / subdivisions;
                        var snapH = cellH / subdivisions;
                        ctx.lineWidth = 1;
                        ctx.setLineDash([]);
                        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.18);
                        ctx.beginPath();
                        for (var s = 0; s <= cols * subdivisions; s++) {
                            if (s % subdivisions === 0) continue;
                            var sx = originX + s * snapW;
                            ctx.moveTo(sx, 0);
                            ctx.lineTo(sx, height);
                        }
                        for (var t = 0; t <= rows * subdivisions; t++) {
                            if (t % subdivisions === 0) continue;
                            var sy = originY + t * snapH;
                            ctx.moveTo(0, sy);
                            ctx.lineTo(width, sy);
                        }
                        ctx.stroke();

                        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.55);
                        ctx.lineWidth = 2;
                        ctx.setLineDash([4, 3]);
                        ctx.beginPath();
                        for (var i = 0; i <= cols; i++) {
                            var x = originX + i * cellW;
                            ctx.moveTo(x, 0);
                            ctx.lineTo(x, height);
                        }
                        for (var j = 0; j <= rows; j++) {
                            var y = originY + j * cellH;
                            ctx.moveTo(0, y);
                            ctx.lineTo(width, y);
                        }
                        ctx.stroke();
                    }
                }

                // Widget hitbox indicator — highlights the current grid cell while dragging
                Rectangle {
                    id: widgetHitbox
                    z: 99
                    visible: bgRoot.draggingWidget && bgRoot.draggingWidgetCell.x >= 0
                        && Config.options.background.widgets.grid.enabled
                        && Config.options.background.showSnapLines
                    color: Qt.rgba(1, 1, 1, 0.1)
                    border.color: Qt.rgba(1, 1, 1, 0.5)
                    border.width: 2
                    x: bgRoot.gridOriginX + bgRoot.draggingWidgetCell.x * bgRoot.gridCellWidth
                    y: bgRoot.gridOriginY + bgRoot.draggingWidgetCell.y * bgRoot.gridCellHeight
                    // Outline the card's real footprint, not a single cell: a 2x2 card
                    // lands across four cells and that is what should be previewed.
                    width: bgRoot.gridSpanWidth(bgRoot.draggingWidgetSpan.x)
                    height: bgRoot.gridSpanHeight(bgRoot.draggingWidgetSpan.y)
                    radius: 4
                }

                // Each widget keeps the stacking order its config asks for: the visualizer
                // (z: -1000) is decoration behind everything else, so it no longer sits on
                // top of the cards sharing its band and eats their clicks.
                FadeLoader {
                    z: Config.options.background.widgets.weather.z ?? 0
                    shown: Config.options.background.widgets.weather.enable && !bgRoot.widgetsOccluded
                    sourceComponent: WeatherWidget {
                        bgRoot: bgRoot
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: bgRoot.effectiveWallpaperScale
                    }
                }

                FadeLoader {
                    z: Config.options.background.widgets.clock.z ?? 0
                    shown: Config.options.background.widgets.clock.enable && !bgRoot.widgetsOccluded
                    sourceComponent: ClockWidget {
                        bgRoot: bgRoot
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: bgRoot.effectiveWallpaperScale
                        wallpaperSafetyTriggered: bgRoot.wallpaperSafetyTriggered
                        isCovered: bgRoot.isCovered
                        wallpaperItem: wallpaper
                    }
                }

                Timer {
                    id: mediaTimer
                    interval: 200
                    onTriggered: mediaLoader.enableLoading = true
                }

                FadeLoader {
                    id: mediaLoader
                    property bool enableLoading: true
                    z: Config.options.background.widgets.media.z ?? 0
                    shown: Config.options.background.widgets.media.enable && enableLoading && !bgRoot.widgetsOccluded
                    sourceComponent: MediaWidget {
                        bgRoot: bgRoot
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: bgRoot.effectiveWallpaperScale
                    }
                    onLoaded: {
                        if (item && item.requestReset) {
                            item.requestReset.connect(() => { // hard reset
                                mediaLoader.enableLoading = false
                                mediaTimer.running = true
                            })
                        }
                    }
                }

                FadeLoader {
                z: Config.options.background.widgets.calendar.z ?? 0
                shown: Config.options.background.widgets.calendar.enable && !bgRoot.widgetsOccluded
                sourceComponent: CalendarWidget {
                    bgRoot: bgRoot
                    screenWidth: bgRoot.screen.width
                    screenHeight: bgRoot.screen.height
                    scaledScreenWidth: bgRoot.screen.width
                    scaledScreenHeight: bgRoot.screen.height
                    wallpaperScale: bgRoot.effectiveWallpaperScale
                }
            }

            FadeLoader {
                z: Config.options.background.widgets.stuySchedule.z ?? 0
                shown: Config.options.background.widgets.stuySchedule.enable && !bgRoot.widgetsOccluded
                sourceComponent: StuyScheduleWidget {
                    bgRoot: bgRoot
                    screenWidth: bgRoot.screen.width
                    screenHeight: bgRoot.screen.height
                    scaledScreenWidth: bgRoot.screen.width
                    scaledScreenHeight: bgRoot.screen.height
                    wallpaperScale: bgRoot.effectiveWallpaperScale
                }
            }

            FadeLoader {
                z: Config.options.background.widgets.stuyCalendar.z ?? 0
                shown: Config.options.background.widgets.stuyCalendar.enable && !bgRoot.widgetsOccluded
                sourceComponent: StuyCalendarWidget {
                    bgRoot: bgRoot
                    screenWidth: bgRoot.screen.width
                    screenHeight: bgRoot.screen.height
                    scaledScreenWidth: bgRoot.screen.width
                    scaledScreenHeight: bgRoot.screen.height
                    wallpaperScale: bgRoot.effectiveWallpaperScale
                }
            }

            FadeLoader {
                z: Config.options.background.widgets.customImage.z ?? 0
                shown: Config.options.background.widgets.customImage.enable && !bgRoot.widgetsOccluded
                sourceComponent: CustomImage {
                    bgRoot: bgRoot
                    screenWidth: bgRoot.screen.width
                    screenHeight: bgRoot.screen.height
                    scaledScreenWidth: bgRoot.screen.width
                    scaledScreenHeight: bgRoot.screen.height
                    wallpaperScale: bgRoot.effectiveWallpaperScale
                }
            }

            FadeLoader {
                z: Config.options.background.widgets.images.z ?? 0
                shown: Config.options.background.widgets.images.enable && !bgRoot.widgetsOccluded
                sourceComponent: ImageConverterWidget {
                    bgRoot: bgRoot
                    screenWidth: bgRoot.screen.width
                    screenHeight: bgRoot.screen.height
                    scaledScreenWidth: bgRoot.screen.width
                    scaledScreenHeight: bgRoot.screen.height
                    wallpaperScale: bgRoot.effectiveWallpaperScale
                }
            }

            FadeLoader {
                z: Config.options.background.widgets.imageCard.z ?? 0
                shown: Config.options.background.widgets.imageCard.enable && !bgRoot.widgetsOccluded
                sourceComponent: ImageCardWidget {
                    bgRoot: bgRoot
                    screenWidth: bgRoot.screen.width
                    screenHeight: bgRoot.screen.height
                    scaledScreenWidth: bgRoot.screen.width
                    scaledScreenHeight: bgRoot.screen.height
                    wallpaperScale: bgRoot.effectiveWallpaperScale
                }
            }

            FadeLoader {
                z: Config.options.background.widgets.sticker.z ?? 0
                shown: Config.options.background.widgets.sticker.enable && !bgRoot.widgetsOccluded
                sourceComponent: StickerWidget {
                    bgRoot: bgRoot
                    screenWidth: bgRoot.screen.width
                    screenHeight: bgRoot.screen.height
                    scaledScreenWidth: bgRoot.screen.width
                    scaledScreenHeight: bgRoot.screen.height
                    wallpaperScale: bgRoot.effectiveWallpaperScale
                }
            }

            FadeLoader {
                z: Config.options.background.widgets.notes.z ?? 0
                shown: Config.options.background.widgets.notes.enable && !bgRoot.widgetsOccluded
                sourceComponent: NotesWidget {
                    bgRoot: bgRoot
                    screenWidth: bgRoot.screen.width
                    screenHeight: bgRoot.screen.height
                    scaledScreenWidth: bgRoot.screen.width
                    scaledScreenHeight: bgRoot.screen.height
                    wallpaperScale: bgRoot.effectiveWallpaperScale
                }
            }

            FadeLoader {
                z: Config.options.background.widgets.resources.z ?? 0
                shown: Config.options.background.widgets.resources.enable && !bgRoot.widgetsOccluded
                sourceComponent: ResourcesWidget {
                    bgRoot: bgRoot
                    screenWidth: bgRoot.screen.width
                    screenHeight: bgRoot.screen.height
                    scaledScreenWidth: bgRoot.screen.width
                    scaledScreenHeight: bgRoot.screen.height
                    wallpaperScale: bgRoot.effectiveWallpaperScale
                }
            }

            FadeLoader {
                z: Config.options.background.widgets.customText.z ?? 0
                shown: Config.options.background.widgets.customText.enable && !bgRoot.widgetsOccluded
                sourceComponent: CustomTextWidget {
                    bgRoot: bgRoot
                    wallpaperItem: wallpaper
                    screenWidth: bgRoot.screen.width
                    screenHeight: bgRoot.screen.height
                    scaledScreenWidth: bgRoot.screen.width
                    scaledScreenHeight: bgRoot.screen.height
                    wallpaperScale: bgRoot.effectiveWallpaperScale
                }
            }

            FadeLoader {
                z: Config.options.background.widgets.todo.z ?? 0
                shown: Config.options.background.widgets.todo.enable && !bgRoot.widgetsOccluded
                sourceComponent: TodoWidget {
                    bgRoot: bgRoot
                    wallpaperItem: wallpaper
                    screenWidth: bgRoot.screen.width
                    screenHeight: bgRoot.screen.height
                    scaledScreenWidth: bgRoot.screen.width
                    scaledScreenHeight: bgRoot.screen.height
                    wallpaperScale: bgRoot.effectiveWallpaperScale
                }
            }

            FadeLoader {
                z: Config.options.background.widgets.timers.z ?? 0
                shown: Config.options.background.widgets.timers.enable && !bgRoot.widgetsOccluded
                sourceComponent: MultiTimerWidget {
                    bgRoot: bgRoot
                    wallpaperItem: wallpaper
                    screenWidth: bgRoot.screen.width
                    screenHeight: bgRoot.screen.height
                    scaledScreenWidth: bgRoot.screen.width
                    scaledScreenHeight: bgRoot.screen.height
                    wallpaperScale: bgRoot.effectiveWallpaperScale
                }
            }

            FadeLoader {
                z: Config.options.background.widgets.userCard.z ?? 0
                shown: Config.options.background.widgets.userCard.enable && !bgRoot.widgetsOccluded
                sourceComponent: UserCardWidget {
                    bgRoot: bgRoot
                    screenWidth: bgRoot.screen.width
                    screenHeight: bgRoot.screen.height
                    scaledScreenWidth: bgRoot.screen.width
                    scaledScreenHeight: bgRoot.screen.height
                    wallpaperScale: bgRoot.effectiveWallpaperScale
                }
            }

            FadeLoader {
                z: Config.options.background.widgets.visualizer.z ?? 0
                shown: Config.options.background.widgets.visualizer.enable && !bgRoot.widgetsOccluded
                sourceComponent: VisualizerWidget {
                    bgRoot: bgRoot
                    screenWidth: bgRoot.screen.width
                    screenHeight: bgRoot.screen.height
                    scaledScreenWidth: bgRoot.screen.width
                    scaledScreenHeight: bgRoot.screen.height
                    wallpaperScale: bgRoot.effectiveWallpaperScale
                }
            }

            FadeLoader {
                z: Config.options.background.widgets.worldClock.z ?? 0
                shown: Config.options.background.widgets.worldClock.enable && !bgRoot.widgetsOccluded
                sourceComponent: WorldClockWidget {
                    bgRoot: bgRoot
                    screenWidth: bgRoot.screen.width
                    screenHeight: bgRoot.screen.height
                    scaledScreenWidth: bgRoot.screen.width
                    scaledScreenHeight: bgRoot.screen.height
                    wallpaperScale: bgRoot.effectiveWallpaperScale
                }
            }

            FadeLoader {
                z: Config.options.background.widgets.timer.z ?? 0
                shown: Config.options.background.widgets.timer.enable && !bgRoot.widgetsOccluded
                sourceComponent: TimerWidget {
                    bgRoot: bgRoot
                    screenWidth: bgRoot.screen.width
                    screenHeight: bgRoot.screen.height
                    scaledScreenWidth: bgRoot.screen.width
                    scaledScreenHeight: bgRoot.screen.height
                    wallpaperScale: bgRoot.effectiveWallpaperScale
                }
            }
            } // WidgetCanvas: every desktop card above is a child of it, in screen space

        }

        GlobalShortcut {
            name: "mediaModeToggle"
            description: "Toggles media mode on press"

            onPressed: {
                if (!monitor.focused && Config.options.background.mediaMode.togglePerMonitor) return
                mediaModeLoader.active = !mediaModeLoader.active
                LyricsService.mediaModeOpenCount += mediaModeLoader.active ? 1 : -1
            }
        }
        
        Loader {
            id: mediaModeLoader
            anchors.fill: parent
            active: false
            asynchronous: true
            sourceComponent: MediaMode {}
            opacity: status === Loader.Ready ? 1 : 0
            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }
    }
}
