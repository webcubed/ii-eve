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
                text: "hub"
                color: TailscaleService.active ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
            }

            StyledText {
                text: "Tailscale"
                font.pixelSize: Appearance.font.pixelSize.large
                Layout.fillWidth: true
            }

            Rectangle {
                implicitWidth: statusChip.implicitWidth + 16
                implicitHeight: statusChip.implicitHeight + 8
                radius: Appearance.rounding.small
                color: TailscaleService.active ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHighest

                StyledText {
                    id: statusChip
                    anchors.centerIn: parent
                    text: TailscaleService.active ? Translation.tr("Connected") : Translation.tr("Disconnected")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: TailscaleService.active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                }
            }
        }

        // Connect/Disconnect button
        RippleButton {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            buttonRadius: Appearance.rounding.normal
            colBackground: TailscaleService.active ? Appearance.colors.colErrorContainer : Appearance.colors.colPrimaryContainer
            colBackgroundHover: TailscaleService.active ? Appearance.colors.colError : Appearance.colors.colPrimary

            contentItem: RowLayout {
                anchors.centerIn: parent
                spacing: 8

                MaterialSymbol {
                    iconSize: Appearance.font.pixelSize.large
                    text: TailscaleService.active ? "link_off" : "link"
                    color: TailscaleService.active ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnPrimaryContainer
                }

                StyledText {
                    text: TailscaleService.active ? Translation.tr("Disconnect") : Translation.tr("Connect")
                    color: TailscaleService.active ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnPrimaryContainer
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            onClicked: {
                if (TailscaleService.active)
                    TailscaleService.disconnect();
                else
                    TailscaleService.connect();
            }
        }

        // Info section
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: infoColumn.implicitHeight + 20
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2

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
                        text: Translation.tr("Node")
                        color: Appearance.colors.colSubtext
                        Layout.fillWidth: true
                    }
                    StyledText {
                        text: TailscaleService.nodeName || "—"
                        horizontalAlignment: Text.AlignRight
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: Translation.tr("Tailnet")
                        color: Appearance.colors.colSubtext
                        Layout.fillWidth: true
                    }
                    StyledText {
                        text: TailscaleService.tailnetName || "—"
                        horizontalAlignment: Text.AlignRight
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: Translation.tr("IPv4")
                        color: Appearance.colors.colSubtext
                        Layout.fillWidth: true
                    }
                    StyledText {
                        text: TailscaleService.tailscaleIp4 || "—"
                        horizontalAlignment: Text.AlignRight
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: Translation.tr("IPv6")
                        color: Appearance.colors.colSubtext
                        Layout.fillWidth: true
                    }
                    StyledText {
                        text: TailscaleService.tailscaleIp6 || "—"
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }

        // Options
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: optionsColumn.implicitHeight + 20
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2

            ColumnLayout {
                id: optionsColumn
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
                        text: Translation.tr("Shield (block incoming)")
                        Layout.fillWidth: true
                    }
                    StyledSwitch {
                        checked: TailscaleService.shieldsUp
                        onToggled: TailscaleService.setShieldsUp(checked)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: Translation.tr("SSH")
                        Layout.fillWidth: true
                    }
                    StyledSwitch {
                        checked: TailscaleService.sshEnabled
                        onToggled: TailscaleService.setSSH(checked)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        text: Translation.tr("Accept DNS")
                        Layout.fillWidth: true
                    }
                    StyledSwitch {
                        checked: TailscaleService.acceptDns
                        onToggled: TailscaleService.setAcceptDns(checked)
                    }
                }
            }
        }

        // Exit node
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: exitColumn.implicitHeight + 20
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2
            visible: TailscaleService.exitNodes.length > 0

            ColumnLayout {
                id: exitColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 10
                }
                spacing: 6

                StyledText {
                    text: Translation.tr("Exit Nodes")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }

                Repeater {
                    model: TailscaleService.exitNodes

                    delegate: Item {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: exitRow.implicitHeight + 12

                        RowLayout {
                            id: exitRow
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                margins: 6
                            }
                            spacing: 8

                            MaterialSymbol {
                                iconSize: Appearance.font.pixelSize.small
                                text: modelData.isActive ? "radio_button_checked" : "radio_button_unchecked"
                                color: modelData.isActive ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                            }

                            StyledText {
                                text: modelData.hostname || modelData.ip || "Unknown"
                                Layout.fillWidth: true
                            }

                            StyledText {
                                text: modelData.location || ""
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: TailscaleService.setExitNode(modelData.exitNodeId)
                        }
                    }
                }

                // Clear exit node option
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: clearRow.implicitHeight + 12

                    RowLayout {
                        id: clearRow
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 6
                        }
                        spacing: 8

                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.small
                            text: TailscaleService.currentExitNode === "" ? "radio_button_checked" : "radio_button_unchecked"
                            color: TailscaleService.currentExitNode === "" ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                        }

                        StyledText {
                            text: Translation.tr("Direct (no exit node)")
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: TailscaleService.setExitNode("")
                    }
                }
            }
        }

        // Peers
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: peersColumn.implicitHeight + 20
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2
            visible: TailscaleService.peers.length > 0

            ColumnLayout {
                id: peersColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 10
                }
                spacing: 6

                StyledText {
                    text: Translation.tr("Peers (%1)").arg(TailscaleService.peers.length)
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }

                Repeater {
                    model: TailscaleService.peers

                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8

                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.small
                            text: "computer"
                            color: Appearance.colors.colSubtext
                        }

                        StyledText {
                            text: modelData.hostname || "Unknown"
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: modelData.ip || ""
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
