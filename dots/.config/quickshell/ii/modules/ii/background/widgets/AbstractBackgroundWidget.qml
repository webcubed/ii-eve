import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets.widgetCanvas

AbstractWidget {
    id: root

    required property string configEntryName
    required property int screenWidth
    required property int screenHeight
    required property int scaledScreenWidth
    required property int scaledScreenHeight
    required property real wallpaperScale
    property var bgRoot
    property bool visibleWhenLocked: Config.options.lock.showWidgets
    property var configEntry: Config.options.background.widgets[configEntryName] ?? ({})
    property string placementStrategy: configEntry.placementStrategy ?? "free"
    readonly property bool gridEnabled: Config.options.background.widgets.grid.enabled
    readonly property int gridColumns: Config.options.background.widgets.grid.columns
    readonly property int gridRows: Config.options.background.widgets.grid.rows
    readonly property real gridCellWidth: scaledScreenWidth / gridColumns
    readonly property real gridCellHeight: scaledScreenHeight / gridRows
    property int gridColumn: {
        if (!Config.ready) return 0;
        const col = configEntry.gridColumn ?? 0;
        return Math.max(0, Math.min(col, gridColumns - 1));
    }
    property int gridRow: {
        if (!Config.ready) return 0;
        const row = configEntry.gridRow ?? 0;
        return Math.max(0, Math.min(row, gridRows - 1));
    }
    property real targetX: gridEnabled
        ? Math.max(0, Math.min(gridColumn * gridCellWidth, scaledScreenWidth - width))
        : Math.max(0, Math.min(configEntry.x ?? 0, scaledScreenWidth - width))
    property real targetY: gridEnabled
        ? Math.max(0, Math.min(gridRow * gridCellHeight, scaledScreenHeight - height))
        : Math.max(0, Math.min(configEntry.y ?? 0, scaledScreenHeight - height))
    x: targetX
    y: targetY
    opacity: {
        if (GlobalStates.screenLocked && !visibleWhenLocked) return 0;
        if (Config.options.background.widgets.cullWhenOccluded && GlobalStates.widgetsOccluded) return 0;
        return 1;
    }
    Behavior on opacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }
    scale: (draggable && containsPress) ? 1.05 : 1
    Behavior on scale {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    // Show grid hitbox while dragging when grid is enabled
    property bool showGridHitbox: draggable && containsPress && gridEnabled

    function resolveBgRoot() {
        if (bgRoot) return bgRoot;
        var item = root.parent;
        while (item) {
            if ("draggingWidget" in item) return item;
            item = item.parent;
        }
        return null;
    }

    draggable: placementStrategy === "free" && !Config.options.background.widgetsLocked
    function restoreXYBinding() {
        root.x = Qt.binding(() => root.targetX);
        root.y = Qt.binding(() => root.targetY);
    }
    onPressed: {
        if (draggable) {
            var bg = resolveBgRoot();
            if (bg) bg.draggingWidget = true;
        }
    }
    
    // Update the highlighted grid cell during drag
    Timer {
        id: dragCellUpdateTimer
        interval: 20
        repeat: true
        running: root.draggable && root.containsPress && gridEnabled
        onTriggered: {
            var bg = resolveBgRoot();
            if (!bg) return;
            const col = Math.floor(root.x / gridCellWidth);
            const row = Math.floor(root.y / gridCellHeight);
            bg.draggingWidgetCell = Qt.point(Math.max(0, Math.min(col, gridColumns - 1)), Math.max(0, Math.min(row, gridRows - 1)));
        }
    }
    onReleased: {
        var bg = resolveBgRoot();
        if (bg) bg.draggingWidget = false;
        if (gridEnabled) {
            const col = Math.round(root.x / gridCellWidth);
            const row = Math.round(root.y / gridCellHeight);
            const snappedCol = Math.max(0, Math.min(col, gridColumns - 1));
            const snappedRow = Math.max(0, Math.min(row, gridRows - 1));
            configEntry.gridColumn = snappedCol;
            configEntry.gridRow = snappedRow;
            root.gridColumn = Qt.binding(() => {
                if (!Config.ready) return 0;
                const col = configEntry.gridColumn ?? 0;
                return Math.max(0, Math.min(col, gridColumns - 1));
            });
            root.gridRow = Qt.binding(() => {
                if (!Config.ready) return 0;
                const row = configEntry.gridRow ?? 0;
                return Math.max(0, Math.min(row, gridRows - 1));
            });
            root.x = Qt.binding(() => root.targetX);
            root.y = Qt.binding(() => root.targetY);
        } else {
            configEntry.x = root.x;
            configEntry.y = root.y;
            root.targetX = Qt.binding(() => Math.max(0, Math.min(configEntry.x, scaledScreenWidth - width)));
            root.targetY = Qt.binding(() => Math.max(0, Math.min(configEntry.y, scaledScreenHeight - height)));
            root.restoreXYBinding();
        }
    }

    property bool needsColText: false
    property color dominantColor: Appearance.colors.colPrimary
    property bool dominantColorIsDark: dominantColor.hslLightness < 0.5
    property color colText: {
        const onNormalBackground = (GlobalStates.screenLocked && Config.options.lock.blur.enable)
        const adaptiveColor = ColorUtils.colorWithLightness(Appearance.colors.colPrimary, (dominantColorIsDark ? 0.8 : 0.12))
        return onNormalBackground ? Appearance.colors.colOnLayer0 : adaptiveColor;
    }

    property bool wallpaperIsVideo: Config.options.background.wallpaperPath.endsWith(".mp4") || Config.options.background.wallpaperPath.endsWith(".webm") || Config.options.background.wallpaperPath.endsWith(".mkv") || Config.options.background.wallpaperPath.endsWith(".avi") || Config.options.background.wallpaperPath.endsWith(".mov")
    property string wallpaperPath: wallpaperIsVideo ? Config.options.background.thumbnailPath : Config.options.background.wallpaperPath
    
    onWallpaperPathChanged: refreshPlacementIfNeeded()
    onPlacementStrategyChanged: refreshPlacementIfNeeded()
    Connections {
        target: Config
        function onReadyChanged() { refreshPlacementIfNeeded() }
    }
    function refreshPlacementIfNeeded() {
        if (!Config.ready) return;
        if (root.placementStrategy === "free" && !root.needsColText) return;
        leastBusyRegionProc.wallpaperPath = root.wallpaperPath;
        leastBusyRegionProc.running = false;
        leastBusyRegionProc.running = true;
    }
    Process {
        id: leastBusyRegionProc
        property string wallpaperPath: root.wallpaperPath
        // TODO: make these less arbitrary
        property int contentWidth: 300
        property int contentHeight: 300
        property int horizontalPadding: 200
        property int verticalPadding: 200
        command: [Quickshell.shellPath("scripts/images/least-busy-region-venv.sh") // Comments to force the formatter to break lines
            , "--screen-width", Math.round(root.scaledScreenWidth) //
            , "--screen-height", Math.round(root.scaledScreenHeight) //
            , "--width", contentWidth //
            , "--height", contentHeight //
            , "--horizontal-padding", horizontalPadding //
            , "--vertical-padding", verticalPadding //
            , wallpaperPath //
            , ...(root.placementStrategy === "mostBusy" ? ["--busiest"] : [])
            // "--visual-output",
        ]
        stdout: StdioCollector {
            id: leastBusyRegionOutputCollector
            onStreamFinished: {
                const output = leastBusyRegionOutputCollector.text;
                // console.log("[Background] Least busy region output:", output)
                if (output.length === 0) return;
                const parsedContent = JSON.parse(output);
                root.dominantColor = parsedContent.dominant_color || Appearance.colors.colPrimary;
                if (root.placementStrategy === "free") return;
                root.targetX = parsedContent.center_x * root.wallpaperScale - root.width / 2;
                root.targetY  = parsedContent.center_y * root.wallpaperScale - root.height / 2;
            }
        }
    }
}