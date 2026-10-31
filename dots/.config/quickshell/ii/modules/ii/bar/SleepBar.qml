import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

// Bar hint for the next sleep. On a school night that is the bedtime that keeps the
// 06:15 alarm at the end of a sleep cycle; on a weekend or break it is the wake a full
// night from now would end at, with the sunrise icon saying which one is showing. The
// time is the whole message, so it gets the width; the hover popup carries the
// countdown, the night's length and the other boundaries.
Item {
    id: root

    property bool vertical: Config.options.bar.vertical
    readonly property bool material: Config.options.bar.cornerStyle === 3
    readonly property var next: SleepSchedule.next
    // The last stretch before a boundary is the only time this widget has news, so
    // that is when the moon and the time take the accent colour.
    readonly property bool imminent: !SleepSchedule.freeNight && next.minutesAway <= 20

    implicitWidth: vertical ? 32 : (grid.implicitWidth + 8)
    implicitHeight: vertical ? (grid.implicitHeight + 6) : Appearance.sizes.barHeight

    Behavior on implicitWidth {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    GridLayout {
        id: grid
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
        columnSpacing: 4
        rowSpacing: 0

        MaterialSymbol {
            fill: root.imminent ? 1 : 0
            text: SleepSchedule.freeNight ? "wb_twilight" : "bedtime"
            iconSize: Appearance.font.pixelSize.large
            color: root.imminent ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
            opacity: root.imminent ? 1 : 0.85
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
        }

        StyledText {
            text: root.next.label
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.imminent || root.material ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: !Config.options.bar.tooltips.clickToShow
        acceptedButtons: Qt.LeftButton
        // Nothing to toggle: the left button is swallowed so a click on the hint does
        // not fall through to the bar's brightness/volume strip.
        onClicked: {}
    }

    SleepPopup {
        hoverTarget: hoverArea
    }
}
