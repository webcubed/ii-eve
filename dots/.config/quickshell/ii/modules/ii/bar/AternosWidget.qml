import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Item {
    id: root
    implicitWidth: rowLayout.implicitWidth + 16
    implicitHeight: Appearance.sizes.barHeight

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 6

        MaterialSymbol {
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnLayer1
            text: "dns"
        }

        ColumnLayout {
            spacing: 0
            Layout.alignment: Qt.AlignVCenter

            Repeater {
                model: Aternos.servers.length > 0 ? Aternos.servers.slice(0, 3) : []

                RowLayout {
                    spacing: 4

                    Rectangle {
                        implicitWidth: 6
                        implicitHeight: 6
                        radius: 3
                        color: {
                            let st = (modelData.status || "").toLowerCase();
                            if (st === "online") return "#22c55e";
                            if (st === "starting" || st === "loading") return "#fde047";
                            return Appearance.colors.colOnLayer1Inactive;
                        }
                    }

                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.smallie
                        color: Appearance.colors.colOnLayer1
                        text: (modelData.address || "Server").split(":")[0]
                        elide: Text.ElideRight
                        Layout.maximumWidth: 120
                    }
                }
            }

            StyledText {
                visible: Aternos.servers.length === 0
                font.pixelSize: Appearance.font.pixelSize.smallie
                color: Appearance.colors.colOnLayer1Inactive
                text: Aternos.loading ? "Loading..." : "No servers"
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (event) => {
            if (event.button === Qt.LeftButton) {
                aternosPopup.visible = !aternosPopup.visible;
            } else if (event.button === Qt.RightButton) {
                Aternos.listServers();
            }
        }
    }

    Loader {
        id: aternosPopup
        active: visible
        visible: false

        sourceComponent: PanelWindow {
            id: popupWindow
            visible: true
            color: "transparent"

            WlrLayershell.namespace: "quickshell:popup"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0

            anchors.top: true
            implicitWidth: 320
            implicitHeight: popupContent.implicitHeight + 20

            mask: Region {
                item: popupBg
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.BackButton
                hoverEnabled: true

                onClicked: (event) => {
                    if (event.button === Qt.LeftButton) {
                        let localPos = mapToItem(popupBg, event.x, event.y);
                        if (!popupBg.containsQtPoint(localPos)) {
                            aternosPopup.visible = false;
                        }
                    }
                }

                Rectangle {
                    id: popupBg
                    anchors.fill: parent
                    anchors.margins: 10
                    color: Appearance.m3colors.m3surfaceContainer
                    radius: Appearance.rounding.normal
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border

                    function containsQtPoint(pos) {
                        return pos.x >= 0 && pos.x <= width && pos.y >= 0 && pos.y <= height;
                    }

                    AternosPopup {
                        id: popupContent
                        anchors.fill: parent
                        anchors.margins: 10
                    }
                }
            }

            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    aternosPopup.visible = false;
                }
            }

            Component.onCompleted: {
                GlobalFocusGrab.addDismissable(popupWindow);
            }
            Component.onDestruction: {
                GlobalFocusGrab.removeDismissable(popupWindow);
            }
        }
    }
}
