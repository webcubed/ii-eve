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

            StyledText {
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                text: {
                    if (Aternos.loading) return "...";
                    if (Aternos.servers.length === 0) return "No servers";
                    let s = Aternos.servers[0];
                    return s.name || s.address || "Server";
                }
            }

            StyledText {
                font.pixelSize: Appearance.font.pixelSize.smallie
                color: {
                    if (Aternos.servers.length === 0) return Appearance.colors.colOnLayer1Inactive;
                    let s = Aternos.servers[0];
                    let st = (s.status || "").toLowerCase();
                    if (st === "online") return "#22c55e";
                    if (st === "starting" || st === "loading") return "#fde047";
                    return Appearance.colors.colOnLayer1Inactive;
                }
                text: {
                    if (Aternos.servers.length === 0) return "";
                    let s = Aternos.servers[0];
                    return s.status || "Unknown";
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: !Config.options.bar.tooltips.clickToShow
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (event) => {
            if (event.button === Qt.LeftButton) {
                if (Aternos.servers.length > 0) {
                    let s = Aternos.servers[0];
                    let st = (s.status || "").toLowerCase();
                    if (st === "offline" || st === "stopped") {
                        Aternos.startServer(s.name || s.id);
                    } else if (st === "online") {
                        Aternos.stopServer(s.name || s.id);
                    }
                }
            } else if (event.button === Qt.RightButton) {
                Aternos.listServers();
            }
        }
    }

    StyledToolTip {
        text: {
            if (Aternos.servers.length === 0) return "No servers found";
            let s = Aternos.servers[0];
            let lines = [s.name || "Server", s.address || "", `Status: ${s.status || "Unknown"}`];
            return lines.filter(l => l).join("\n");
        }
    }
}
