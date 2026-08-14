import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    property bool vertical: false
    property bool isMaterial: true // Forced expressive
    visible: tray.hasAnyItems

    implicitWidth: vertical ? 40 : pill.implicitWidth
    implicitHeight: vertical ? pill.implicitHeight : Appearance.sizes.barHeight

    Rectangle {
        id: pill
        anchors.centerIn: parent
        color: Appearance.colors.colLayer1
        radius: Appearance.rounding.full
        implicitWidth: vertical ? 34 : (tray.implicitWidth > 0 ? tray.implicitWidth + 12 : 0)
        implicitHeight: vertical ? (tray.implicitHeight > 0 ? tray.implicitHeight + 12 : 0) : 30
        visible: tray.implicitWidth > 0

        SysTray {
            id: tray
            anchors.centerIn: parent
            vertical: root.vertical
        }
    }
}
