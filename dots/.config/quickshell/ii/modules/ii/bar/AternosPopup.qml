import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 8
    implicitWidth: 300

    // Tab bar for servers
    TabBar {
        id: tabBar
        Layout.fillWidth: true
        visible: Aternos.servers.length > 0

        Repeater {
            model: Aternos.servers

            TabButton {
                text: (modelData.address || "Server").split(":")[0]
                width: implicitWidth
                contentItem: StyledText {
                    text: parent.text
                    font.pixelSize: Appearance.font.pixelSize.small
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: tabBar.currentIndex === index ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                }
                background: Rectangle {
                    color: tabBar.currentIndex === index ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
                    radius: Appearance.rounding.small

                    Rectangle {
                        visible: tabBar.currentIndex === index
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 2
                        color: Appearance.colors.colOnPrimary
                    }
                }
            }
        }
    }

    // Server info
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: serverInfo.implicitHeight + 16
        color: Appearance.colors.colLayer2
        radius: Appearance.rounding.small
        visible: Aternos.servers.length > 0

        ColumnLayout {
            id: serverInfo
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            StyledText {
                text: {
                    let s = Aternos.servers[tabBar.currentIndex];
                    if (!s) return "";
                    return (s.address || "Unknown").split(":")[0];
                }
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Bold
                color: Appearance.colors.colOnLayer1
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: 12

                RowLayout {
                    spacing: 4
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: {
                            let s = Aternos.servers[tabBar.currentIndex];
                            if (!s) return "#808080";
                            let st = (s.status || "").toLowerCase();
                            if (st === "online") return "#22c55e";
                            if (st === "starting" || st === "loading") return "#fde047";
                            return "#808080";
                        }
                    }
                    StyledText {
                        text: {
                            let s = Aternos.servers[tabBar.currentIndex];
                            return s ? (s.status || "Unknown") : "";
                        }
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }

                StyledText {
                    text: {
                        let s = Aternos.servers[tabBar.currentIndex];
                        if (!s) return "";
                        return `${s.players ?? "?"}/${s.slots ?? "?"} players`;
                    }
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    text: {
                        let s = Aternos.servers[tabBar.currentIndex];
                        if (!s) return "";
                        return s.software || "";
                    }
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
            }

            StyledText {
                text: {
                    let s = Aternos.servers[tabBar.currentIndex];
                    if (!s) return "";
                    return s.version || "";
                }
                font.pixelSize: Appearance.font.pixelSize.smallie
                color: Appearance.colors.colSubtext
                Layout.fillWidth: true
            }
        }
    }

    // Control buttons
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: Aternos.servers.length > 0

        Button {
            Layout.fillWidth: true
            text: "Start"
            enabled: {
                let s = Aternos.servers[tabBar.currentIndex];
                return s && (s.status || "").toLowerCase() === "offline";
            }

            background: Rectangle {
                color: parent.enabled ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                radius: Appearance.rounding.small
            }
            contentItem: StyledText {
                text: parent.text
                font.pixelSize: Appearance.font.pixelSize.small
                color: parent.enabled ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                horizontalAlignment: Text.AlignHCenter
            }
            onClicked: {
                let s = Aternos.servers[tabBar.currentIndex];
                if (s) Aternos.startServer(s.address);
            }
        }

        Button {
            Layout.fillWidth: true
            text: "Restart"
            enabled: {
                let s = Aternos.servers[tabBar.currentIndex];
                return s && (s.status || "").toLowerCase() === "online";
            }

            background: Rectangle {
                color: parent.enabled ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer2
                radius: Appearance.rounding.small
            }
            contentItem: StyledText {
                text: parent.text
                font.pixelSize: Appearance.font.pixelSize.small
                color: parent.enabled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colSubtext
                horizontalAlignment: Text.AlignHCenter
            }
            onClicked: {
                let s = Aternos.servers[tabBar.currentIndex];
                if (s) {
                    Aternos.stopServer(s.address);
                    Aternos.startTimer = 1000;
                }
            }
        }

        Button {
            Layout.fillWidth: true
            text: "Stop"
            enabled: {
                let s = Aternos.servers[tabBar.currentIndex];
                return s && (s.status || "").toLowerCase() === "online";
            }

            background: Rectangle {
                color: parent.enabled ? Appearance.colors.colErrorContainer : Appearance.colors.colLayer2
                radius: Appearance.rounding.small
            }
            contentItem: StyledText {
                text: parent.text
                font.pixelSize: Appearance.font.pixelSize.small
                color: parent.enabled ? Appearance.colors.colOnErrorContainer : Appearance.colors.colSubtext
                horizontalAlignment: Text.AlignHCenter
            }
            onClicked: {
                let s = Aternos.servers[tabBar.currentIndex];
                if (s) Aternos.stopServer(s.address);
            }
        }
    }

    // Console command
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: Aternos.servers.length > 0

        TextField {
            id: consoleInput
            Layout.fillWidth: true
            placeholderText: "Console command..."
            color: Appearance.colors.colOnLayer1
            placeholderTextColor: Appearance.colors.colSubtext
            background: Rectangle {
                color: Appearance.colors.colLayer2
                radius: Appearance.rounding.small
                border.color: consoleInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer3
                border.width: 1
            }
            onAccepted: {
                if (text.trim().length > 0) {
                    let s = Aternos.servers[tabBar.currentIndex];
                    if (s) {
                        Aternos.sendCommand(s.address, text.trim());
                        text = "";
                    }
                }
            }
        }

        Button {
            implicitWidth: 40
            background: Rectangle {
                color: Appearance.colors.colPrimary
                radius: Appearance.rounding.small
            }
            contentItem: MaterialSymbol {
                iconSize: 18
                text: "terminal"
                color: Appearance.colors.colOnPrimary
            }
            onClicked: {
                if (consoleInput.text.trim().length > 0) {
                    let s = Aternos.servers[tabBar.currentIndex];
                    if (s) {
                        Aternos.sendCommand(s.address, consoleInput.text.trim());
                        consoleInput.text = "";
                    }
                }
            }
        }
    }

    // Loading / empty state
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: Aternos.servers.length === 0

        MaterialSymbol {
            icon: "dns"
            iconSize: 48
            color: Appearance.colors.colSubtext
            Layout.alignment: Qt.AlignHCenter
        }

        StyledText {
            text: Aternos.loading ? "Loading servers..." : "No servers found"
            font.pixelSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colSubtext
            Layout.alignment: Qt.AlignHCenter
        }

        Button {
            Layout.alignment: Qt.AlignHCenter
            text: "Refresh"
            enabled: !Aternos.loading
            background: Rectangle {
                color: Appearance.colors.colPrimaryContainer
                radius: Appearance.rounding.small
            }
            contentItem: StyledText {
                text: parent.text
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnPrimaryContainer
                horizontalAlignment: Text.AlignHCenter
            }
            onClicked: Aternos.listServers()
        }
    }

    // Error display
    StyledText {
        visible: Aternos.lastError.length > 0
        text: Aternos.lastError
        font.pixelSize: Appearance.font.pixelSize.smallie
        color: Appearance.colors.colError
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    // Refresh button row
    RowLayout {
        Layout.fillWidth: true
        visible: Aternos.servers.length > 0

        Item { Layout.fillWidth: true }

        Button {
            text: "Refresh"
            enabled: !Aternos.loading
            background: Rectangle {
                color: Appearance.colors.colLayer3
                radius: Appearance.rounding.small
            }
            contentItem: MaterialSymbol {
                icon: "refresh"
                iconSize: 18
                color: Appearance.colors.colOnLayer1
            }
            onClicked: Aternos.listServers()
        }
    }
}
