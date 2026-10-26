import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property int currentIndex: 0
    property bool expanded: false
    property color colToggled: Appearance.colors.colSecondaryContainer
    default property alias tabData: tabBarColumn.data
    property bool _isInitialized: false
    Component.onCompleted: _isInitialized = true

    readonly property var _tabButtons: {
        const out = []
        const all = tabBarColumn.children
        for (let i = 0; i < all.length; i++) {
            const c = all[i]
            if (c && c.baseSize !== undefined && c.visualWidth !== undefined) out.push(c)
        }
        return out
    }
    readonly property var _currentButton: _tabButtons[root.currentIndex] ?? _tabButtons[0] ?? null

    implicitHeight: tabBarColumn.implicitHeight
    implicitWidth: tabBarColumn.implicitWidth
    Layout.topMargin: 25

    Rectangle {
        visible: root.currentIndex >= 0
        property real itemHeight: root._tabButtons[0]?.baseSize ?? 56
        property real baseHighlightHeight: root._tabButtons[0]?.baseHighlightHeight ?? 32
        anchors {
            top: tabBarColumn.top
            left: tabBarColumn.left
            topMargin: itemHeight * root.currentIndex + (root.expanded ? 0 : ((itemHeight - baseHighlightHeight) / 2))
        }
        radius: Appearance.rounding.full
        color: root.colToggled
        implicitHeight: root.expanded ? itemHeight : baseHighlightHeight
        implicitWidth: root._currentButton?.visualWidth ?? (root.expanded ? 130 : itemHeight)

        Behavior on implicitWidth {
            enabled: root._isInitialized

            animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
        }

        Behavior on anchors.topMargin {
            enabled: root._isInitialized

            NumberAnimation {
                duration: Appearance.animationCurves.expressiveFastSpatialDuration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }
    }

    ColumnLayout {
        id: tabBarColumn
        anchors.fill: parent
        spacing: 0
    }
}
