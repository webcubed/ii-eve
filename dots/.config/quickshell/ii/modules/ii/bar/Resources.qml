import qs.modules.common
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

MouseArea {
    id: root
    implicitWidth: rowLayout.implicitWidth + rowLayout.anchors.leftMargin + rowLayout.anchors.rightMargin
    implicitHeight: Appearance.sizes.barHeight
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    onClicked: {
        btopProc.running = false;
        btopProc.running = true
    }

    Process {
        id: btopProc
        command: ["kitty", "-e", "btop"]
    }

    property bool showCat: Config.options.bar.resources.showCatGif
    property bool enableCatGif: Config.options.bar.resources.showCatGif
    property int catHeight: 35
    readonly property int catWidth: Math.round(catHeight * 1.30)

    property int cpuCatThresholdPercent: 30
    readonly property bool cpuCatRun: (ResourceUsage.cpuUsage * 100.0) >= cpuCatThresholdPercent

    // Color helpers
    function clamp01(x) { return Math.max(0, Math.min(1, x)); }
    function mixColor(c1, c2, t) {
        t = clamp01(t);
        return Qt.rgba(
        c1.r * (1 - t) + c2.r * t,
                       c1.g * (1 - t) + c2.g * t,
                       c1.b * (1 - t) + c2.b * t,
                       c1.a * (1 - t) + c2.a * t
        );
    }

    readonly property real t20: 0.20
    readonly property real t50: 0.50
    readonly property real t75: 0.75
    readonly property color colGreen:  "#22c55e"
    readonly property color colYellow: "#fde047"
    readonly property color colOrange: "#fb923c"
    readonly property color colRed:    "#ef4444"

    function alertColorByPercent(value01) {
        value01 = clamp01(value01);
        if (value01 < root.t20) {
            let t = value01 / Math.max(0.0001, root.t20);
            return root.mixColor(root.colGreen, root.colYellow, t * 0.20);
        }
        if (value01 < root.t50) {
            let t = (value01 - root.t20) / Math.max(0.0001, (root.t50 - root.t20));
            return root.mixColor(root.colYellow, root.colOrange, t * 0.25);
        }
        if (value01 < root.t75) {
            let t = (value01 - root.t50) / Math.max(0.0001, (root.t75 - root.t50));
            return root.mixColor(root.colOrange, root.colRed, t);
        }
        return root.colRed;
    }

    component PulsingDot: Item {
        id: dot
        property color color: root.colGreen
        property int size: 6
        property real intensity: 0.0
        width: size + 12
        height: size + 12
        readonly property int pulseMs: Math.max(560, Math.round(980 - (dot.intensity * 420)))

        Rectangle { id: haloBig; anchors.centerIn: parent; width: dot.size; height: dot.size; radius: width/2; color: dot.color; opacity: 0.10; scale: 1.0 }
        Rectangle { id: haloMid; anchors.centerIn: parent; width: dot.size; height: dot.size; radius: width/2; color: dot.color; opacity: 0.18; scale: 1.0 }
        Rectangle { id: core;    anchors.centerIn: parent; width: dot.size; height: dot.size; radius: width/2; color: dot.color; opacity: 0.96 }

        Behavior on color { ColorAnimation { duration: 240; easing.type: Easing.InOutQuad } }

        SequentialAnimation {
            running: true
            loops: Animation.Infinite
            ParallelAnimation {
                NumberAnimation { target: haloBig; property: "scale";   from: 1.0;  to: 2.65; duration: Math.round(dot.pulseMs * 1.10); easing.type: Easing.OutCubic }
                NumberAnimation { target: haloBig; property: "opacity"; from: 0.10; to: 0.00; duration: Math.round(dot.pulseMs * 1.10); easing.type: Easing.OutCubic }
                NumberAnimation { target: haloMid; property: "scale";   from: 1.0;  to: 2.15; duration: dot.pulseMs;                    easing.type: Easing.OutCubic }
                NumberAnimation { target: haloMid; property: "opacity"; from: 0.18; to: 0.00; duration: dot.pulseMs;                    easing.type: Easing.OutCubic }
                NumberAnimation { target: core;    property: "scale";   from: 1.0;  to: 1.18; duration: Math.round(dot.pulseMs * 0.42); easing.type: Easing.OutQuad }
                NumberAnimation { target: core;    property: "scale";   from: 1.18; to: 1.0;  duration: Math.round(dot.pulseMs * 0.58); easing.type: Easing.InOutQuad }
            }
        }
    }

    component ResourceWithDot: RowLayout {
        id: wrap
        spacing: 2
        Layout.alignment: Qt.AlignVCenter
        property string iconName
        property real percentage: 0
        property bool shown: true
        property real warningThreshold01: 0.75
        visible: shown
        readonly property real value01: root.clamp01(wrap.percentage)

        Resource {
            iconName: wrap.iconName
            percentage: wrap.percentage
            warningThreshold: Math.round(wrap.warningThreshold01 * 100)
        }
        PulsingDot {
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: -2
            size: 6
            visible: Config.options.bar.resources.showStatusDots
            color: root.alertColorByPercent(wrap.value01)
            intensity: wrap.value01 < root.t20 ? 0.10 :
            wrap.value01 < root.t50 ? 0.35 :
            wrap.value01 < root.t75 ? 0.70 : 1.00
        }
    }

    RowLayout {
        id: rowLayout
        spacing: 0
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4

        Item {
            Layout.alignment: Qt.AlignVCenter
            Layout.topMargin: -2
            Layout.preferredHeight: root.showCat && root.enableCatGif ? root.catHeight : 0
            Layout.preferredWidth:  root.showCat && root.enableCatGif ? root.catWidth  : 0

            Loader {
                active: root.showCat && root.enableCatGif
                visible: active
                anchors.fill: parent
                source: "ResourceGif.qml"
                onLoaded: {
                    if (!item) return
                        item.running     = Qt.binding(function() { return root.cpuCatRun })
                        item.runSource   = Qt.resolvedUrl(Quickshell.shellPath("assets/gifs/run.gif"))
                        item.sleepSource = Qt.resolvedUrl(Quickshell.shellPath("assets/gifs/sleep.gif"))
                }
            }
        }

        ResourceWithDot {
            iconName: "memory"
            percentage: ResourceUsage.memoryUsedPercentage
            warningThreshold01: Config.options.bar.resources.memoryWarningThreshold / 100.0
            shown: Config.options.bar.resources.showMemory
        }
        ResourceWithDot {
            iconName: "swap_horiz"
            percentage: ResourceUsage.swapUsedPercentage
            Layout.leftMargin: 6
            warningThreshold01: Config.options.bar.resources.swapWarningThreshold / 100.0
            shown: Config.options.bar.resources.showSwap
        }
        ResourceWithDot {
            iconName: "planner_review"
            percentage: ResourceUsage.cpuUsage
            Layout.leftMargin: 6
            warningThreshold01: Config.options.bar.resources.cpuWarningThreshold / 100.0
            shown: Config.options.bar.resources.showCpu
        }
        ResourceWithDot {
            iconName: "display_settings"
            percentage: ResourceUsage.gpuUsage
            Layout.leftMargin: 6
            shown: Config.options.bar.resources.showGpu
        }
    }

    Loader {
        active: !Config.options.bar.resources.expressivePopup
        sourceComponent: ResourcesPopup {
            hoverTarget: root
        }
    }

    Loader {
        active: Config.options.bar.resources.expressivePopup
        sourceComponent: ExpressiveResourcesPopup {
            hoverTarget: root
        }
    }
}
