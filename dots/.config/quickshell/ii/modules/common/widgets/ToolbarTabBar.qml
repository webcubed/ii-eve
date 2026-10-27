pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.models
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property alias currentIndex: tabBar.currentIndex
    required property var tabButtonList
    property int maxTextTabs: 99
    property bool editMode: false
    signal tabReordered(int fromIndex, int toIndex)

    function incrementCurrentIndex() {
        tabBar.incrementCurrentIndex();
    }
    function decrementCurrentIndex() {
        tabBar.decrementCurrentIndex();
    }
    function setCurrentIndex(index) {
        tabBar.setCurrentIndex(index);
    }

    /**
     * Slide the tab strip so the active tab is inside the visible slice. Without
     * this, keyboard/wheel navigation can select a tab that sits past the right
     * edge of the Flickable and the highlight disappears off screen.
     */
    function ensureCurrentVisible() {
        const item = contentItem.children[root.currentIndex];
        if (!item || flickable.width <= 0) return;
        const margin = 10;
        const maxContentX = Math.max(0, flickable.contentWidth - flickable.width);
        const left = item.x - margin;
        const right = item.x + item.width + margin;
        let target = flickable.contentX;
        if (left < flickable.contentX) target = left;
        else if (right > flickable.contentX + flickable.width) target = right - flickable.width;
        else return;
        scrollAnim.to = Math.max(0, Math.min(maxContentX, target));
        scrollAnim.restart();
    }

    NumberAnimation {
        id: scrollAnim
        target: flickable
        property: "contentX"
        duration: Appearance.animation.elementMoveFast.duration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
    }

    Connections {
        target: tabBar
        function onCurrentIndexChanged() { Qt.callLater(root.ensureCurrentVisible); }
    }

    onWidthChanged: ensureCurrentVisible()

    Layout.fillWidth: true
    // Natural width, not 0: toolbars sized from implicitWidth (region selector,
    // cheatsheet) need the tab width in the sum, else the pill collapses and
    // the unclipped activeIndicator spills over neighbors (the close Fab).
    // fillWidth still stretches the bar when the toolbar has extra room.
    implicitWidth: contentItem.implicitWidth
    implicitHeight: 40

    property int _dragFromIndex: -1

    property Component delegate: ToolbarTabButton {
        required property int index
        required property var modelData
        current: index == root.currentIndex
        showLabel: root.tabButtonList.length <= root.maxTextTabs || current
        text: modelData.name
        materialSymbol: modelData.icon

        MouseArea {
            anchors.fill: parent
            z: 10
            acceptedButtons: Qt.LeftButton
            cursorShape: root.editMode ? Qt.OpenHandCursor : Qt.PointingHandCursor

            property bool didDrag: false
            property real pressX: 0

            onPressed: (mouse) => {
                didDrag = false;
                pressX = mouse.x;
                if (root.editMode) {
                    root._dragFromIndex = parent.index;
                    parent.opacity = 0.7;
                }
            }
            onPositionChanged: (mouse) => {
                if (root.editMode && pressed && !didDrag && Math.abs(mouse.x - pressX) > 10) {
                    didDrag = true;
                }
            }
            onReleased: (mouse) => {
                parent.opacity = 1;
                const fromIdx = root._dragFromIndex;
                root._dragFromIndex = -1;
                if (!root.editMode || !didDrag || fromIdx < 0) return;
                const myX = mapToItem(contentItem, mouse.x, 0).x;
                let targetIdx = fromIdx;
                const count = repeater.count;
                for (let i = 0; i < count; i++) {
                    if (i === fromIdx) continue;
                    const child = repeater.itemAt(i);
                    if (!child) continue;
                    const center = child.x + child.width / 2;
                    if (myX < center && i < fromIdx) {
                        targetIdx = i;
                        break;
                    } else if (myX > center && i > fromIdx) {
                        targetIdx = i;
                    }
                }
                if (targetIdx !== fromIdx) {
                    root.tabReordered(fromIdx, targetIdx);
                }
            }
            onClicked: (mouse) => {
                if (root.editMode && didDrag) return;
                root.setCurrentIndex(parent.index);
            }
        }
    }

    Flickable {
        id: flickable
        z: 1
        width: root.width
        height: root.implicitHeight
        contentWidth: contentItem.implicitWidth
        contentHeight: height
        clip: true
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds

        Row {
            id: contentItem
            spacing: 4

            Repeater {
                id: repeater
                model: root.tabButtonList
                delegate: root.delegate
            }
        }
    }

    Rectangle {
        id: activeIndicator
        z: 0
        color: Appearance.colors.colSecondaryContainer
        implicitWidth: contentItem.children[root.currentIndex]?.implicitWidth ?? 0
        implicitHeight: contentItem.children[root.currentIndex]?.implicitHeight ?? 0
        readonly property int fullRadius: Config.options.appearance.sharpMode ? Appearance.rounding.full : height / 2
        radius: fullRadius
        // Animation
        property Item targetItem: contentItem.children[root.currentIndex] ?? null
        AnimatedTabIndexPair {
            id: leftBound
            idx1Duration: 50
            idx2Duration: 200
            index: activeIndicator.targetItem?.x ?? 0
        }
        AnimatedTabIndexPair {
            id: rightBound
            idx1Duration: 50
            idx2Duration: 200
            index: activeIndicator.targetItem?.x + activeIndicator.targetItem?.width ?? 0
        }
        x: Math.min(leftBound.idx1, leftBound.idx2) - flickable.contentX
        width: Math.max(rightBound.idx1, rightBound.idx2) - Math.min(leftBound.idx1, leftBound.idx2)
    }

    MouseArea {
        anchors.fill: parent
        z: 2
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor
        onWheel: event => {
            if (event.angleDelta.y < 0) {
                root.incrementCurrentIndex();
            } else {
                root.decrementCurrentIndex();
            }
        }
    }

    // TabBar doesn't allow tabs to be of different sizes. That's what I thought...
    // We use it only for the logic and draw stuff manually
    TabBar {
        id: tabBar
        z: -1
        background: null
        Repeater {
            // This is to fool the TabBar that it has tabs so it does the indices properly
            model: root.tabButtonList.length
            delegate: TabButton {
                background: null
            }
        }
    }
}
