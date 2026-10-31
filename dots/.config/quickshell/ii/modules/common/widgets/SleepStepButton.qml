import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick

// The 18px +/- affordance next to a value in the sleep hint. Its own file rather than
// an inline `component`: inline components do not resolve when the root of a file is a
// StyledPopup (the reload reports "StepButton is not a type").
Rectangle {
    id: root

    property string icon
    // The card sits on a primary container and the popup on the surface, so the caller
    // supplies whatever reads on its background.
    property color fgColor: Appearance.colors.colOnSurface
    signal activated()

    implicitWidth: 18
    implicitHeight: 18
    radius: Appearance.rounding.full
    color: area.containsMouse
        ? ColorUtils.transparentize(root.fgColor, 0.85)
        : "transparent"

    Behavior on color {
        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
    }

    MaterialSymbol {
        anchors.centerIn: parent
        text: root.icon
        iconSize: 13
        color: root.fgColor
        opacity: 0.85
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
