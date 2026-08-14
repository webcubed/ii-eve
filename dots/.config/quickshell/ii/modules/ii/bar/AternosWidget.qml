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
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (event) => {
            if (event.button === Qt.LeftButton) {
                if (Aternos.servers.length > 0) {
                    let s = Aternos.servers[0];
                    let st = (s.status || "").toLowerCase();
                    if (st === "offline" || st === "stopped") {
                        Aternos.startServer(s.address);
                    } else if (st === "online") {
                        Aternos.stopServer(s.address);
                    }
                }
            } else if (event.button === Qt.RightButton) {
                Aternos.listServers();
            } else if (event.button === Qt.MiddleButton) {
                if (Aternos.servers.length > 1) {
                    let s = Aternos.servers[1];
                    let st = (s.status || "").toLowerCase();
                    if (st === "offline" || st === "stopped") {
                        Aternos.startServer(s.address);
                    } else if (st === "online") {
                        Aternos.stopServer(s.address);
                    }
                }
            }
        }
    }

    StyledToolTip {
        extraVisibleCondition: false
        alternativeVisibleCondition: mouseArea.containsMouse
        text: {
            if (Aternos.servers.length === 0) return "No servers found\nRight-click to refresh";
            let lines = [];
            for (let i = 0; i < Math.min(Aternos.servers.length, 3); i++) {
                let s = Aternos.servers[i];
                let addr = (s.address || "Unknown").split(":")[0];
                lines.push(`${addr}: ${s.status || "?"} (${s.players ?? "?"}/${s.slots ?? "?"})`);
            }
            lines.push("");
            lines.push("Left-click: Start/Stop #1");
            if (Aternos.servers.length > 1) lines.push("Middle-click: Start/Stop #2");
            lines.push("Right-click: Refresh");
            return lines.join("\n");
        }
    }
}
