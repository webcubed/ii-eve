import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    property bool showPing: false
    visible: (ExtensionManager.ready ? ExtensionManager.getContributionPoint("sidebarLeftPages").length : 0) > 0

    // Icon color picked in settings (Interface/Bar → Left sidebar button). The
    // "onLayer0" default keeps this widget's designed color.
    readonly property color customIconColor: {
        const name = Config.options.custom.iconColor
        if (!name || name === "onLayer0") return Appearance.colors.colOnPrimaryContainer
        return Appearance.colors[`col${name.charAt(0).toUpperCase()}${name.slice(1)}`] ?? Appearance.colors.colOnPrimaryContainer
    }

    implicitWidth: loader.implicitWidth
    implicitHeight: loader.implicitHeight

    Connections {
        target: Ai
        function onResponseFinished() {
            if (GlobalStates.sidebarLeftOpen) return;
            root.showPing = true;
        }
    }
    Connections {
        target: Booru
        function onResponseFinished() {
            if (GlobalStates.sidebarLeftOpen) return;
            root.showPing = true;
        }
    }
    Connections {
        target: GlobalStates
        function onSidebarLeftOpenChanged() {
            root.showPing = false;
        }
    }

    Loader {
        id: loader
        anchors.fill: parent
        sourceComponent: fabStyle // Forced expressive
    }

    Component {
        id: fabStyle
        Fab {
            colBackground: GlobalStates.sidebarLeftOpen ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colPrimaryContainer
            onClicked: {
                GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
            }

            CustomIcon {
                anchors.centerIn: parent
                width: 19.5
                height: 19.5
                source: Config.options.custom.distroIcon || (Config.options.bar.topLeftIcon == 'distro' ? SystemInfo.distroIcon : `${Config.options.bar.topLeftIcon}-symbolic`)
                customFolder: Config.options.custom.iconsPath
                colorize: Config.options.custom.colorizeIcon
                color: root.customIconColor

                Rectangle {
                    opacity: root.showPing ? 1 : 0
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
    }
}
