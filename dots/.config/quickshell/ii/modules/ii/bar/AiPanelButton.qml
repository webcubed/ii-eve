import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

RippleButton {
    id: aiButton

    property bool showPing: false

    property real buttonPadding: 5
    implicitWidth: icon.width + buttonPadding * 2
    implicitHeight: icon.height + buttonPadding * 2
    buttonRadius: Appearance.rounding.full
    colBackgroundHover: Appearance.colors.colLayer1Hover
    colRipple: Appearance.colors.colLayer1Active
    colBackgroundToggled: Appearance.colors.colSecondaryContainer
    colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
    colRippleToggled: Appearance.colors.colSecondaryContainerActive
    toggled: GlobalStates.sidebarLeftOpen

    onPressed: {
        GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
    }

    Connections {
        target: Ai
        function onResponseFinished() {
            if (GlobalStates.sidebarLeftOpen) return;
            aiButton.showPing = true;
        }
    }

    Connections {
        target: GlobalStates
        function onSidebarLeftOpenChanged() {
            aiButton.showPing = false;
        }
    }

    MaterialSymbol {
        id: icon
        anchors.centerIn: parent
        iconSize: 20
        text: "psychology"
        color: Appearance.colors.colOnLayer0

        Rectangle {
            opacity: aiButton.showPing ? 1 : 0
            visible: opacity > 0
            anchors {
                bottom: parent.bottom
                right: parent.right
                bottomMargin: -2
                rightMargin: -2
            }
            implicitWidth: 8
            implicitHeight: 8
            radius: Appearance.rounding.full
            color: Appearance.colors.colTertiary

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }
    }
}
