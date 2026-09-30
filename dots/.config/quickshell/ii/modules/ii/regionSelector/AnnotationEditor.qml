pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Built-in snip annotation editor: opens on the screen the region was cut from,
// shows the crop, lets you draw on it, then copies/saves the composited result.
PanelWindow {
    id: root
    visible: false
    color: "transparent"
    WlrLayershell.namespace: "quickshell:annotationEditor"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    property string imagePath: ""
    property var targetScreen: null
    screen: root.targetScreen ?? Quickshell.screens[0]

    signal dismiss()

    // Tool state (persists across snips: last-used tool/color/size stick)
    property string tool: "pen" // pen | highlight | arrow | rect | ellipse | triangle | text
    readonly property bool shapeTool: root.tool === "rect" || root.tool === "ellipse" || root.tool === "triangle"
    readonly property var shapeList: [
        { tool: "rect", icon: "crop_square", name: Translation.tr("Rectangle") },
        { tool: "ellipse", icon: "circle", name: Translation.tr("Ellipse") },
        { tool: "triangle", icon: "change_history", name: Translation.tr("Triangle") }
    ]
    function shapeIcon() {
        if (root.tool === "ellipse") return "circle";
        if (root.tool === "triangle") return "change_history";
        return "crop_square";
    }
    property bool shapeMenuOpen: false
    property string drawColor: "#e53935"
    property int penWidth: 4
    property var swatchColors: ["#e53935", "#fb8c00", "#fdd835", "#43a047", "#1e88e5", "#8e24aa", "#fafafa", "#212121"]
    property var sizes: [2, 4, 8]
    readonly property int textSize: root.penWidth === 2 ? 14 : (root.penWidth === 4 ? 20 : 28)

    property var shapes: []
    property var draft: null

    // Device pixel ratio of this window's output; the crop file is in physical
    // pixels, so display it at physical/dpr to match how it looked on screen.
    readonly property real dpr: (Screen.devicePixelRatio > 0) ? Screen.devicePixelRatio : 1
    readonly property real baseW: img.sourceSize.width > 0 ? img.sourceSize.width / dpr : 0
    readonly property real baseH: img.sourceSize.height > 0 ? img.sourceSize.height / dpr : 0
    readonly property real fit: (baseW > 0 && root.width > 0)
        ? Math.min(1, (root.width - 80) / baseW, (root.height - 150) / baseH)
        : 1

    function resetState() {
        root.shapes = [];
        root.draft = null;
        textInput.text = "";
        textInput.visible = false;
        // Repaint: the canvas bitmap survives a hide/show, so without this the
        // previous snip's drawings stay on screen over the new crop.
        canvas.requestPaint();
    }

    onVisibleChanged: {
        if (visible) {
            root.resetState();
            Qt.callLater(() => view.forceActiveFocus());
        }
    }
    // New crop path = new session; reset even if visibleChanged misfires.
    onImagePathChanged: root.resetState()
    // Picking a tool from anywhere closes the shape drop-up.
    onToolChanged: root.shapeMenuOpen = false

    function cancel() {
        if (root.imagePath.length > 0)
            Quickshell.execDetached(["rm", "-f", root.imagePath]);
        root.dismiss();
    }

    function withExported(cb) {
        view.grabToImage(result => {
            const tmp = `${Directories.screenshotTemp}/annotated-export.png`;
            if (!result.saveToFile(tmp)) {
                console.warn("[Annotation Editor] Failed to save grab to", tmp);
                root.dismiss();
                return;
            }
            cb(tmp);
        });
    }

    function doCopy() {
        root.withExported(tmp => {
            Quickshell.execDetached(["bash", "-c",
                `wl-copy -t image/png < '${StringUtils.shellSingleQuoteEscape(tmp)}' && rm -f '${StringUtils.shellSingleQuoteEscape(tmp)}' '${StringUtils.shellSingleQuoteEscape(root.imagePath)}'`]);
            root.dismiss();
        });
    }

    function doSave() {
        const dir = Config.options.screenSnip.savePath !== ""
            ? Config.options.screenSnip.savePath
            : `${Directories.pictures}/Screenshots`;
        root.withExported(tmp => {
            Quickshell.execDetached(["bash", "-c",
                `mkdir -p '${StringUtils.shellSingleQuoteEscape(dir)}' && mv '${StringUtils.shellSingleQuoteEscape(tmp)}' '${StringUtils.shellSingleQuoteEscape(dir)}/screenshot-'$(date '+%Y-%m-%d_%H.%M.%S')'.png' && rm -f '${StringUtils.shellSingleQuoteEscape(root.imagePath)}'`]);
            root.dismiss();
        });
    }

    // Hand the raw crop to swappy (or satty if configured) and let it take over.
    function doExternal() {
        const editor = Config.options.regionSelector.annotation.useSatty ? "satty" : "swappy";
        Quickshell.execDetached(["bash", "-c",
            `${editor} -f '${StringUtils.shellSingleQuoteEscape(root.imagePath)}'; rm -f '${StringUtils.shellSingleQuoteEscape(root.imagePath)}'`]);
        root.dismiss();
    }

    function commitDraft() {
        const d = root.draft;
        if (!d) return;
        const isFreehand = d.type === "pen" || d.type === "highlight";
        const moved = isFreehand
            ? (d.pts?.length ?? 0) > 2
            : (Math.abs(d.x2 - d.x1) + Math.abs(d.y2 - d.y1)) > 4;
        if (moved) root.shapes.push(d);
        root.draft = null;
        canvas.requestPaint();
    }

    function beginText(x, y) {
        textInput.text = "";
        textInput.x = Math.min(x, Math.max(0, view.width - textInput.width));
        textInput.y = Math.min(y, Math.max(0, view.height - textInput.height));
        textInput.visible = true;
        textInput.forceActiveFocus();
    }

    Rectangle {
        // Dim backdrop; consumes clicks so they don't reach windows below
        anchors.fill: parent
        color: "#b3000000"
    }

    Item {
        id: view
        anchors.centerIn: parent
        width: root.baseW * root.fit
        height: root.baseH * root.fit
        visible: img.status === Image.Ready
        focus: true

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                if (root.shapeMenuOpen) {
                    root.shapeMenuOpen = false; // close the shape drop-up first
                } else {
                    root.cancel();
                }
                event.accepted = true;
            }
        }

        Image {
            id: img
            anchors.fill: parent
            source: root.imagePath.length > 0 ? "file://" + root.imagePath : ""
            asynchronous: false
        }

        Canvas {
            id: canvas
            anchors.fill: parent
            contextType: "2d"

            function drawShape(ctx, s) {
                ctx.save();
                ctx.strokeStyle = s.color;
                ctx.fillStyle = s.color;
                ctx.lineWidth = s.width;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                if (s.type === "pen" || s.type === "highlight") {
                    if (s.type === "highlight") {
                        ctx.globalAlpha = 0.35;
                        ctx.lineWidth = s.width * 5;
                    }
                    ctx.beginPath();
                    s.pts.forEach((p, i) => {
                        if (i === 0) ctx.moveTo(p.x, p.y);
                        else ctx.lineTo(p.x, p.y);
                    });
                    ctx.stroke();
                } else if (s.type === "rect") {
                    ctx.strokeRect(
                        Math.min(s.x1, s.x2), Math.min(s.y1, s.y2),
                        Math.abs(s.x2 - s.x1), Math.abs(s.y2 - s.y1));
                } else if (s.type === "ellipse") {
                    // ctx.ellipse isn't in Qt's Canvas subset; 4-bezier approximation.
                    const cx = (s.x1 + s.x2) / 2, cy = (s.y1 + s.y2) / 2;
                    const rx = Math.abs(s.x2 - s.x1) / 2, ry = Math.abs(s.y2 - s.y1) / 2;
                    const k = 0.5522847498;
                    ctx.beginPath();
                    ctx.moveTo(cx + rx, cy);
                    ctx.bezierCurveTo(cx + rx, cy + ry * k, cx + rx * k, cy + ry, cx, cy + ry);
                    ctx.bezierCurveTo(cx - rx * k, cy + ry, cx - rx, cy + ry * k, cx - rx, cy);
                    ctx.bezierCurveTo(cx - rx, cy - ry * k, cx - rx * k, cy - ry, cx, cy - ry);
                    ctx.bezierCurveTo(cx + rx * k, cy - ry, cx + rx, cy - ry * k, cx + rx, cy);
                    ctx.closePath();
                    ctx.stroke();
                } else if (s.type === "triangle") {
                    const mx1 = Math.min(s.x1, s.x2), mx2 = Math.max(s.x1, s.x2);
                    const my1 = Math.min(s.y1, s.y2), my2 = Math.max(s.y1, s.y2);
                    ctx.beginPath();
                    ctx.moveTo((mx1 + mx2) / 2, my1);
                    ctx.lineTo(mx2, my2);
                    ctx.lineTo(mx1, my2);
                    ctx.closePath();
                    ctx.stroke();
                } else if (s.type === "arrow") {
                    ctx.beginPath();
                    ctx.moveTo(s.x1, s.y1);
                    ctx.lineTo(s.x2, s.y2);
                    ctx.stroke();
                    const a = Math.atan2(s.y2 - s.y1, s.x2 - s.x1);
                    const h = Math.max(12, s.width * 4);
                    ctx.beginPath();
                    ctx.moveTo(s.x2, s.y2);
                    ctx.lineTo(s.x2 - h * Math.cos(a - 0.42), s.y2 - h * Math.sin(a - 0.42));
                    ctx.moveTo(s.x2, s.y2);
                    ctx.lineTo(s.x2 - h * Math.cos(a + 0.42), s.y2 - h * Math.sin(a + 0.42));
                    ctx.stroke();
                } else if (s.type === "text") {
                    ctx.font = `${root.textSize}px sans-serif`;
                    ctx.textBaseline = "top";
                    ctx.fillText(s.text, s.x, s.y);
                }
                ctx.restore();
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                for (const s of root.shapes) drawShape(ctx, s);
                if (root.draft) drawShape(ctx, root.draft);
            }
        }

        MouseArea {
            id: drawArea
            anchors.fill: parent
            enabled: !textInput.visible
            cursorShape: root.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor
            acceptedButtons: Qt.LeftButton

            onPressed: (mouse) => {
                if (root.tool === "text") {
                    root.beginText(mouse.x, mouse.y);
                    return;
                }
                root.draft = {
                    type: root.tool,
                    color: root.drawColor,
                    width: root.penWidth,
                    pts: [{ x: mouse.x, y: mouse.y }],
                    x1: mouse.x, y1: mouse.y, x2: mouse.x, y2: mouse.y
                };
            }
            onPositionChanged: (mouse) => {
                if (!pressed || !root.draft) return;
                if (root.draft.type === "pen" || root.draft.type === "highlight") {
                    root.draft.pts.push({ x: mouse.x, y: mouse.y });
                } else {
                    root.draft.x2 = mouse.x;
                    root.draft.y2 = mouse.y;
                }
                canvas.requestPaint();
            }
            onReleased: () => root.commitDraft()
        }

        TextField {
            id: textInput
            visible: false
            width: 240
            padding: 4
            color: root.drawColor
            font.pixelSize: root.textSize
            background: Rectangle {
                color: "#cc000000"
                radius: 4
                border.color: root.drawColor
                border.width: 1
            }
            onAccepted: {
                const t = textInput.text.trim();
                if (t.length > 0) {
                    root.shapes.push({ type: "text", text: t, x: textInput.x, y: textInput.y, color: root.drawColor, width: root.penWidth });
                    canvas.requestPaint();
                }
                textInput.text = "";
                textInput.visible = false;
                view.forceActiveFocus();
            }
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    textInput.text = "";
                    textInput.visible = false;
                    view.forceActiveFocus();
                    event.accepted = true;
                }
            }
        }
    }

    Row {
        id: toolbar
        z: 10
        spacing: 12
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 24
        }

        Toolbar {
            spacing: 4

            IconToolbarButton {
                text: "draw"
                toggled: root.tool === "pen"
                onClicked: root.tool = "pen"
                StyledToolTip { text: Translation.tr("Pen") }
            }
            IconToolbarButton {
                text: "highlight"
                toggled: root.tool === "highlight"
                onClicked: root.tool = "highlight"
                StyledToolTip { text: Translation.tr("Highlight") }
            }
            IconToolbarButton {
                text: "arrow_outward"
                toggled: root.tool === "arrow"
                onClicked: root.tool = "arrow"
                StyledToolTip { text: Translation.tr("Arrow") }
            }

            // Shape tool with drop-up (opens upward: toolbar sits at screen bottom)
            Item {
                id: shapeGroup
                Layout.fillHeight: true
                implicitWidth: shapeBtn.implicitWidth

                IconToolbarButton {
                    id: shapeBtn
                    anchors.fill: parent
                    text: root.shapeIcon()
                    toggled: root.shapeTool
                    onClicked: root.shapeMenuOpen = !root.shapeMenuOpen
                    StyledToolTip { text: Translation.tr("Shape") }
                }

            }
            IconToolbarButton {
                text: "text_fields"
                toggled: root.tool === "text"
                onClicked: root.tool = "text"
                StyledToolTip { text: Translation.tr("Text") }
            }

            Row {
                Layout.alignment: Qt.AlignVCenter
                spacing: 6
                Repeater {
                    model: root.swatchColors
                    delegate: Rectangle {
                        id: swatch
                        required property var modelData
                        width: 22
                        height: 22
                        radius: 11
                        color: swatch.modelData
                        border.width: root.drawColor === swatch.modelData ? 3 : 0
                        border.color: Appearance.colors.colPrimary
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.drawColor = swatch.modelData
                        }
                    }
                }
            }

            Row {
                Layout.alignment: Qt.AlignVCenter
                spacing: 4
                Repeater {
                    model: root.sizes
                    delegate: Item {
                        id: sizeBtn
                        required property var modelData
                        width: 28
                        height: 28
                        Rectangle {
                            anchors.centerIn: parent
                            width: sizeBtn.modelData * 2 + 8
                            height: width
                            radius: width / 2
                            color: root.penWidth === sizeBtn.modelData
                                ? Appearance.colors.colPrimary
                                : Appearance.colors.colOnSurfaceVariant
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.penWidth = sizeBtn.modelData
                        }
                    }
                }
            }
        }

        Toolbar {
            spacing: 4

            IconToolbarButton {
                text: "undo"
                onClicked: {
                    root.shapes.pop();
                    canvas.requestPaint();
                }
                StyledToolTip { text: Translation.tr("Undo") }
            }
            IconToolbarButton {
                text: "clear_all"
                onClicked: {
                    root.shapes = [];
                    canvas.requestPaint();
                }
                StyledToolTip { text: Translation.tr("Clear all") }
            }
            IconToolbarButton {
                text: "open_in_new"
                onClicked: root.doExternal()
                StyledToolTip { text: Translation.tr("Open in external editor") }
            }
            IconToolbarButton {
                text: "content_copy"
                onClicked: root.doCopy()
                StyledToolTip { text: Translation.tr("Copy to clipboard") }
            }
            IconToolbarButton {
                text: "save"
                onClicked: root.doSave()
                StyledToolTip { text: Translation.tr("Save to file") }
            }
            IconToolbarButton {
                text: "close"
                onClicked: root.cancel()
                StyledToolTip { text: Translation.tr("Cancel") }
            }
        }
    }

    // Shape drop-up host. Hit-testing only descends into items whose *ancestors*
    // contain the point, so a menu overflowing the toolbar would never get
    // clicks — it lives in this full-screen layer instead (same idea as a Popup
    // overlay). The transparent backdrop eats outside clicks; the menu sits on
    // top of it. Only exists while the menu is open.
    Item {
        id: menuHost
        anchors.fill: parent
        z: 11
        visible: root.shapeMenuOpen

        MouseArea {
            anchors.fill: parent
            onClicked: root.shapeMenuOpen = false
        }

        Rectangle {
            id: shapeMenu
            width: 172
            height: shapeCol.implicitHeight + 12
            // Centered above the shape button; explicit property reads in the
            // bindings keep the mapping fresh as the toolbar settles.
            x: {
                root.width;
                toolbar.x;
                const p = shapeBtn.mapToItem(menuHost, shapeBtn.width / 2, 0);
                return p.x - width / 2;
            }
            y: {
                root.height;
                toolbar.y;
                const p = shapeBtn.mapToItem(menuHost, 0, 0);
                return p.y - height - 16;
            }
            color: Appearance.m3colors.m3surfaceContainer
            radius: 16

            Column {
                id: shapeCol
                anchors.fill: parent
                anchors.margins: 6
                spacing: 2

                Repeater {
                    model: root.shapeList
                    delegate: Item {
                        id: opt
                        required property var modelData
                        width: shapeCol.width
                        height: 36

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: root.tool === opt.modelData.tool
                                ? Appearance.colors.colSecondaryContainer
                                : optMouse.containsMouse
                                    ? Appearance.colors.colSurfaceContainerHighestHover
                                    : "transparent"
                        }
                        Row {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            MaterialSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                iconSize: 20
                                text: opt.modelData.icon
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: opt.modelData.name
                                color: Appearance.colors.colOnSurface
                                font.family: Appearance.font.family.main
                                font.pixelSize: 14
                            }
                        }
                        MouseArea {
                            id: optMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.tool = opt.modelData.tool;
                                root.shapeMenuOpen = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
