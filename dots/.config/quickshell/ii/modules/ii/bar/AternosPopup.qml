import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

StyledPopup {
    id: root
    popupRadius: Appearance.rounding.large
    stickyHover: true

    property int currentServerIndex: 0

    contentItem: ColumnLayout {
        spacing: 8
        implicitWidth: 320

        // Server tabs
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: Aternos.servers.length > 1

            Repeater {
                model: Aternos.servers

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: Appearance.rounding.small
                    color: root.currentServerIndex === index ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2

                    property bool isActive: root.currentServerIndex === index

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: {
                                let st = (modelData.status || "").toLowerCase();
                                if (st === "online") return "#22c55e";
                                if (st === "starting" || st === "loading") return "#fde047";
                                return "#808080";
                            }
                        }

                        StyledText {
                            text: (modelData.address || "Server").split(":")[0]
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            color: parent.parent.isActive ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                            elide: Text.ElideRight
                            Layout.maximumWidth: 100
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.currentServerIndex = index
                    }

                    Rectangle {
                        visible: parent.isActive
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width * 0.6
                        height: 2
                        radius: 1
                        color: Appearance.colors.colPrimary
                    }
                }
            }
        }

        // Active server info
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: contentColumn.implicitHeight + 24
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2

            ColumnLayout {
                id: contentColumn
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialSymbol {
                        text: "dns"
                        iconSize: 20
                        color: Appearance.colors.colPrimary
                    }

                    StyledText {
                        text: {
                            let s = Aternos.servers[root.currentServerIndex];
                            return s ? (s.address || "Unknown").split(":")[0] : "No server";
                        }
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnLayer1
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        implicitHeight: 22
                        implicitWidth: statusRow.implicitWidth + 12
                        radius: Appearance.rounding.full
                        color: {
                            let s = Aternos.servers[root.currentServerIndex];
                            if (!s) return Appearance.colors.colLayer3;
                            let st = (s.status || "").toLowerCase();
                            if (st === "online") return Qt.alpha("#22c55e", 0.15);
                            if (st === "starting" || st === "loading") return Qt.alpha("#fde047", 0.15);
                            return Appearance.colors.colLayer3;
                        }

                        RowLayout {
                            id: statusRow
                            anchors.centerIn: parent
                            spacing: 4

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: {
                                    let s = Aternos.servers[root.currentServerIndex];
                                    if (!s) return "#808080";
                                    let st = (s.status || "").toLowerCase();
                                    if (st === "online") return "#22c55e";
                                    if (st === "starting" || st === "loading") return "#fde047";
                                    return "#808080";
                                }
                            }

                            StyledText {
                                text: {
                                    let s = Aternos.servers[root.currentServerIndex];
                                    return s ? (s.status || "Unknown") : "Unknown";
                                }
                                font.pixelSize: Appearance.font.pixelSize.smallie
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnLayer1
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Row {
                        spacing: 4
                        MaterialSymbol {
                            text: "group"
                            iconSize: 14
                            color: Appearance.colors.colSubtext
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: {
                                let s = Aternos.servers[root.currentServerIndex];
                                if (!s) return "?/?";
                                return `${s.players ?? "?"}/${s.slots ?? "?"}`;
                            }
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        spacing: 4
                        MaterialSymbol {
                            text: "memory"
                            iconSize: 14
                            color: Appearance.colors.colSubtext
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: {
                                let s = Aternos.servers[root.currentServerIndex];
                                return s ? `${s.software || "?"} ${s.version || ""}` : "";
                            }
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Appearance.colors.colLayer3
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Button {
                        Layout.fillWidth: true
                        implicitHeight: 32
                        enabled: {
                            let s = Aternos.servers[root.currentServerIndex];
                            return s && (s.status || "").toLowerCase() === "offline";
                        }

                        background: Rectangle {
                            radius: Appearance.rounding.small
                            color: parent.enabled ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer3
                        }
                        contentItem: RowLayout {
                            spacing: 4
                            MaterialSymbol {
                                text: "play_arrow"
                                iconSize: 16
                                color: parent.parent.parent.enabled ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                            }
                            StyledText {
                                text: "Start"
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: parent.parent.parent.parent.enabled ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                            }
                        }
                        onClicked: {
                            let s = Aternos.servers[root.currentServerIndex];
                            if (s) Aternos.startServer(s.address);
                        }
                    }

                    Button {
                        Layout.fillWidth: true
                        implicitHeight: 32
                        enabled: {
                            let s = Aternos.servers[root.currentServerIndex];
                            return s && (s.status || "").toLowerCase() === "online";
                        }

                        background: Rectangle {
                            radius: Appearance.rounding.small
                            color: parent.enabled ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer3
                        }
                        contentItem: RowLayout {
                            spacing: 4
                            MaterialSymbol {
                                text: "restart_alt"
                                iconSize: 16
                                color: parent.parent.parent.enabled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colSubtext
                            }
                            StyledText {
                                text: "Restart"
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: parent.parent.parent.parent.enabled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colSubtext
                            }
                        }
                        onClicked: {
                            let s = Aternos.servers[root.currentServerIndex];
                            if (s) {
                                Aternos.stopServer(s.address);
                                Aternos.startTimer = 2000;
                            }
                        }
                    }

                    Button {
                        Layout.fillWidth: true
                        implicitHeight: 32
                        enabled: {
                            let s = Aternos.servers[root.currentServerIndex];
                            return s && (s.status || "").toLowerCase() === "online";
                        }

                        background: Rectangle {
                            radius: Appearance.rounding.small
                            color: parent.enabled ? Appearance.colors.colErrorContainer : Appearance.colors.colLayer3
                        }
                        contentItem: RowLayout {
                            spacing: 4
                            MaterialSymbol {
                                text: "stop"
                                iconSize: 16
                                color: parent.parent.parent.enabled ? Appearance.colors.colOnErrorContainer : Appearance.colors.colSubtext
                            }
                            StyledText {
                                text: "Stop"
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: parent.parent.parent.parent.enabled ? Appearance.colors.colOnErrorContainer : Appearance.colors.colSubtext
                            }
                        }
                        onClicked: {
                            let s = Aternos.servers[root.currentServerIndex];
                            if (s) Aternos.stopServer(s.address);
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    TextField {
                        id: consoleInput
                        Layout.fillWidth: true
                        implicitHeight: 32
                        placeholderText: "Console command..."
                        color: Appearance.colors.colOnLayer1
                        placeholderTextColor: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                        background: Rectangle {
                            color: Appearance.colors.colLayer1
                            radius: Appearance.rounding.small
                            border.color: consoleInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer3
                            border.width: 1
                        }
                        onAccepted: {
                            if (text.trim().length > 0) {
                                let s = Aternos.servers[root.currentServerIndex];
                                if (s) {
                                    Aternos.sendCommand(s.address, text.trim());
                                    text = "";
                                }
                            }
                        }
                    }

                    Button {
                        implicitWidth: 32
                        implicitHeight: 32
                        enabled: consoleInput.text.trim().length > 0

                        background: Rectangle {
                            radius: Appearance.rounding.small
                            color: parent.enabled ? Appearance.colors.colPrimary : Appearance.colors.colLayer3
                        }
                        contentItem: MaterialSymbol {
                            text: "send"
                            iconSize: 16
                            color: parent.parent.enabled ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                        }
                        onClicked: {
                            if (consoleInput.text.trim().length > 0) {
                                let s = Aternos.servers[root.currentServerIndex];
                                if (s) {
                                    Aternos.sendCommand(s.address, consoleInput.text.trim());
                                    consoleInput.text = "";
                                }
                            }
                        }
                    }
                }

                StyledText {
                    visible: Aternos.lastError.length > 0
                    text: Aternos.lastError
                    font.pixelSize: Appearance.font.pixelSize.smallie
                    color: Appearance.colors.colError
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }
        }

        // Empty state
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2
            visible: Aternos.servers.length === 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8

                MaterialSymbol {
                    text: "dns"
                    iconSize: 32
                    color: Appearance.colors.colSubtext
                    Layout.alignment: Qt.AlignHCenter
                }

                StyledText {
                    text: Aternos.loading ? "Loading servers..." : "No servers found"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                    Layout.alignment: Qt.AlignHCenter
                }

                Button {
                    Layout.alignment: Qt.AlignHCenter
                    implicitHeight: 28
                    text: "Refresh"
                    enabled: !Aternos.loading
                    background: Rectangle {
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colPrimaryContainer
                    }
                    contentItem: StyledText {
                        text: parent.text
                        font.pixelSize: Appearance.font.pixelSize.smallie
                        color: Appearance.colors.colOnPrimaryContainer
                        horizontalAlignment: Text.AlignHCenter
                    }
                    onClicked: Aternos.listServers()
                }
            }
        }
    }
}
