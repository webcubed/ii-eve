pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.utils
import qs.modules.common.widgets
import qs.services

PanelWindow {
    id: root

    // Interface
    signal dismiss

    // Window props
    visible: false
    // color: Appearance.colors.colLayer0
    color: "black"
    WlrLayershell.namespace: "quickshell:screenTranslator"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    // Config
    readonly property string screenshotDir: Directories.screenshotTemp
    property var regionInfo: null
    readonly property bool regionMode: regionInfo !== null
    readonly property string screenshotPath: regionMode
        ? `${root.screenshotDir}/region-${screen.name}.png`
        : `${root.screenshotDir}/image-${screen.name}`

    // Region-mode geometry (logical coords, relative to screen)
    readonly property real regionX: regionMode ? regionInfo.x : 0
    readonly property real regionY: regionMode ? regionInfo.y : 0
    readonly property real regionWidth: regionMode ? regionInfo.width : (screen ? screen.width : 0)
    readonly property real regionHeight: regionMode ? regionInfo.height : (screen ? screen.height : 0)
    readonly property real regionMonitorScale: regionMode ? (regionInfo.monitorScale ?? 1) : 1

    // Preparation
    property bool screenshotReady: false

    function performTranslation() {
        screenshotReady = true;
    }

    TempScreenshotProcess {
        id: screenshotProc
        running: !root.regionMode
        screen: root.screen
        screenshotDir: root.screenshotDir
        screenshotPath: root.screenshotPath
        onExited: (_, __) => {
            if (root.regionMode) return;
            root.visible = true;
            root.performTranslation();
        }
    }

    Process {
        id: regionCropProc
        running: root.regionMode
        command: {
            if (!root.regionMode) return [];
            const src = root.regionInfo.sourcePath;
            const dst = root.screenshotPath;
            const dir = root.screenshotDir;
            const s = root.regionMonitorScale;
            const rx = Math.round(root.regionX * s);
            const ry = Math.round(root.regionY * s);
            const rw = Math.round(root.regionWidth * s);
            const rh = Math.round(root.regionHeight * s);
            return ["bash", "-c",
                `mkdir -p '${StringUtils.shellSingleQuoteEscape(dir)}' && `
                + `magick '${StringUtils.shellSingleQuoteEscape(src)}' `
                + `-crop ${rw}x${rh}+${rx}+${ry} +repage `
                + `'${StringUtils.shellSingleQuoteEscape(dst)}'`];
        }
        onExited: (exitCode, _) => {
            if (!root.regionMode) return;
            if (exitCode !== 0) {
                console.warn("[Region Translator] Crop failed with exit code", exitCode);
                root.dismiss();
                return;
            }
            root.visible = true;
            root.performTranslation();
        }
    }

    // Actual content
    property real scale: 1.0
    property real contentX: 0
    property real contentY: 0

    MouseArea {
        anchors.fill: parent
        clip: true

        property real lastX: 0
        property real lastY: 0

        cursorShape: Qt.SizeAllCursor

        onPressed: mouse => {
            lastX = mouse.x;
            lastY = mouse.y;
        }

        onPositionChanged: mouse => {
            if (pressed) {
                root.contentX += (mouse.x - lastX);
                root.contentY += (mouse.y - lastY);
                lastX = mouse.x;
                lastY = mouse.y;
            }
        }

        onWheel: event => {
            const zoomFactor = event.angleDelta.y > 0 ? 1.1 : 0.9;
            const oldScale = root.scale;
            const newScale = Math.min(Math.max(0.1, oldScale * zoomFactor), 5);

            if (newScale !== oldScale) {
                // Determine mouse position relative to the content's unscaled origin
                const localX = (event.x - root.contentX) / oldScale;
                const localY = (event.y - root.contentY) / oldScale;

                // Apply zoom
                root.scale = newScale;

                // Shift offsets to keep the same local point under the cursor
                root.contentX = event.x - (localX * newScale);
                root.contentY = event.y - (localY * newScale);
            }
        }

        ScreencopyView { // Freeze screen
            id: screencopy
            width: parent.width
            height: parent.height

            x: root.contentX
            y: root.contentY
            scale: root.scale
            transformOrigin: Item.TopLeft

            live: false
            captureSource: root.screen
        }

        Loader {
            width: (root.regionMode ? root.regionWidth : parent.width) * root.scale
            height: (root.regionMode ? root.regionHeight : parent.height) * root.scale

            x: root.contentX + (root.regionMode ? root.regionX * root.scale : 0)
            y: root.contentY + (root.regionMode ? root.regionY * root.scale : 0)

            active: root.screenshotReady
            sourceComponent: ScreenTextOverlay {
                screenshotPath: root.screenshotPath
                scaleFactor: root.scale
                windowWidth: root.regionMode ? root.regionWidth : QsWindow.window.screen.width
                windowHeight: root.regionMode ? root.regionHeight : QsWindow.window.screen.height
            }
        }
    }

    Row {
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: -height
        }
        Behavior on anchors.bottomMargin {
            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
        }
        Component.onCompleted: {
            anchors.bottomMargin = 8;
        }

        spacing: 6

        Toolbar {
            id: toolbar
            focus: root.visible
            Keys.onPressed: event => { // Esc to close
                if (event.key === Qt.Key_Escape) {
                    root.dismiss();
                }
            }
            spacing: 0

            IconToolbarButton {
                id: sleepButton
                onClicked: {
                    toggled = !toggled
                    if (toggled) keyInput.forceActiveFocus()
                }
                text: "key"

                StyledToolTip {
                    z: 9999
                    text: Translation.tr("Key input")
                }
            }

            Revealer {
                reveal: sleepButton.toggled
                Layout.fillHeight: true

                RowLayout {
                    anchors.left: parent.left
                    spacing: 6
                    Item {} // extra padding
                    ToolbarTextField {
                        id: keyInput
                        implicitWidth: 400
                        placeholderText: Translation.tr("Paste service account key JSON here")
                        inputMethodHints: Qt.ImhSensitiveData
                        onAccepted: submit()

                        function submit() {
                            const success = GoogleCloud.setKeyJson(text);
                            if (!success) {
                                invalidJsonAnimation.restart();
                            } else {
                                text = "";
                                sleepButton.toggled = false;
                            }
                        }

                        ErrorShakeAnimation {
                            id: invalidJsonAnimation
                            target: keyInput
                        }
                    }
                    IconToolbarButton {
                        id: submitButton
                        onClicked: keyInput.submit()
                        text: "check"
                        toggled: keyInput.text.length > 0

                        StyledToolTip {
                            z: 9999
                            text: Translation.tr("Confirm")
                        }
                    }
                }
            }
        }

        ToolbarPairedFab {
            Layout.alignment: Qt.AlignVCenter
            iconText: "close"
            onClicked: root.dismiss()
            StyledToolTip {
                text: Translation.tr("Close")
            }
        }
    }
}
