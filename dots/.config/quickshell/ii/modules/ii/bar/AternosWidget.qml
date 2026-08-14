import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

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
        hoverEnabled: !Config.options.bar.tooltips.clickToShow

        AternosPopup {
            hoverTarget: mouseArea
        }
    }
}
