import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property real padding: 4

    ColumnLayout {
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: 8

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                iconSize: Appearance.font.pixelSize.larger
                text: "shield"
                color: VpnService.active ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
            }

            StyledText {
                text: Translation.tr("VPN")
                font.pixelSize: Appearance.font.pixelSize.large
                Layout.fillWidth: true
            }

            Rectangle {
                implicitWidth: statusChip.implicitWidth + 16
                implicitHeight: statusChip.implicitHeight + 8
                radius: Appearance.rounding.small
                color: VpnService.active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHighest

                StyledText {
                    id: statusChip
                    anchors.centerIn: parent
                    text: VpnService.active ? Translation.tr("Connected") : Translation.tr("Disconnected")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: VpnService.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                }
            }
        }

        // Connect/Disconnect
        RippleButton {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            buttonRadius: Appearance.rounding.normal
            colBackground: VpnService.active ? Appearance.colors.colErrorContainer : Appearance.colors.colPrimaryContainer
            colBackgroundHover: VpnService.active ? Appearance.colors.colError : Appearance.colors.colPrimary

            contentItem: RowLayout {
                anchors.centerIn: parent
                spacing: 8

                MaterialSymbol {
                    iconSize: Appearance.font.pixelSize.large
                    text: VpnService.active ? "link_off" : "link"
                    color: VpnService.active ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnPrimaryContainer
                }

                StyledText {
                    text: VpnService.active ? Translation.tr("Disconnect") : Translation.tr("Connect")
                    color: VpnService.active ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnPrimaryContainer
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            onClicked: {
                if (VpnService.active)
                    VpnService.disconnectVpn();
                else
                    VpnService.connectDefault();
            }
        }

        // Active info
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: infoColumn.implicitHeight + 20
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2
            visible: VpnService.active

            ColumnLayout {
                id: infoColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 10
                }
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: Translation.tr("Provider")
                        color: Appearance.colors.colSubtext
                        Layout.fillWidth: true
                    }
                    StyledText {
                        text: VpnService.activeProvider || "—"
                        horizontalAlignment: Text.AlignRight
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: Translation.tr("Profile")
                        color: Appearance.colors.colSubtext
                        Layout.fillWidth: true
                    }
                    StyledText {
                        text: VpnService.activeProfile || "—"
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }

        // Provider selection
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: providerColumn.implicitHeight + 20
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2

            ColumnLayout {
                id: providerColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 10
                }
                spacing: 6

                StyledText {
                    text: Translation.tr("Provider")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }

                Repeater {
                    model: [
                        { key: "networkmanager", name: "NetworkManager", available: true },
                        { key: "nordvpn", name: "NordVPN", available: VpnService.nordvpnAvailable },
                        { key: "protonvpn", name: "ProtonVPN", available: VpnService.protonvpnAvailable }
                    ]

                    delegate: Item {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: providerRow.implicitHeight + 12

                        RowLayout {
                            id: providerRow
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 6
                            }
                            spacing: 8

                            MaterialSymbol {
                                iconSize: Appearance.font.pixelSize.small
                                text: VpnService.activeProvider === modelData.key ? "radio_button_checked" : "radio_button_unchecked"
                                color: VpnService.activeProvider === modelData.key ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                            }

                            StyledText {
                                text: modelData.name
                                opacity: modelData.available ? 1.0 : 0.4
                                Layout.fillWidth: true
                            }

                            StyledText {
                                text: modelData.available ? "" : Translation.tr("Not installed")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: modelData.available ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: modelData.available
                            onClicked: {
                                Config.options.vpn.recentProvider = modelData.key;
                                if (!VpnService.active) {
                                    Config.options.vpn.defaultProvider = modelData.key;
                                }
                            }
                        }
                    }
                }
            }
        }

        // Profiles (NM VPN)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: profilesColumn.implicitHeight + 20
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2
            visible: VpnService.profiles.length > 0

            ColumnLayout {
                id: profilesColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 10
                }
                spacing: 6

                StyledText {
                    text: Translation.tr("Profiles")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }

                Repeater {
                    model: VpnService.profiles

                    delegate: Item {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: profileRow.implicitHeight + 12

                        RowLayout {
                            id: profileRow
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 6
                            }
                            spacing: 8

                            MaterialSymbol {
                                iconSize: Appearance.font.pixelSize.small
                                text: VpnService.activeProfile === modelData.name ? "radio_button_checked" : "radio_button_unchecked"
                                color: VpnService.activeProfile === modelData.name ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                            }

                            StyledText {
                                text: modelData.name || "Unknown"
                                Layout.fillWidth: true
                            }

                            StyledText {
                                text: modelData.type || ""
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: VpnService.connectProfile(modelData.name)
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
