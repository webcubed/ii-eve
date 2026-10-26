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
                text: "inventory"
                color: DockerService.dockerRunning ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
            }

            StyledText {
                text: "Docker"
                font.pixelSize: Appearance.font.pixelSize.large
                Layout.fillWidth: true
            }

            Rectangle {
                implicitWidth: statusChip.implicitWidth + 16
                implicitHeight: statusChip.implicitHeight + 8
                radius: Appearance.rounding.small
                color: DockerService.dockerRunning ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHighest

                StyledText {
                    id: statusChip
                    anchors.centerIn: parent
                    text: DockerService.dockerRunning ? Translation.tr("Running") : Translation.tr("Stopped")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: DockerService.dockerRunning ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                }
            }
        }

        // Docker daemon toggle
        RippleButton {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            buttonRadius: Appearance.rounding.normal
            colBackground: DockerService.dockerRunning ? Appearance.colors.colErrorContainer : Appearance.colors.colPrimaryContainer
            colBackgroundHover: DockerService.dockerRunning ? Appearance.colors.colError : Appearance.colors.colPrimary

            contentItem: RowLayout {
                anchors.centerIn: parent
                spacing: 8

                MaterialSymbol {
                    iconSize: Appearance.font.pixelSize.large
                    text: DockerService.dockerRunning ? "stop" : "play_arrow"
                    color: DockerService.dockerRunning ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnPrimaryContainer
                }

                StyledText {
                    text: DockerService.dockerRunning ? Translation.tr("Stop Docker") : Translation.tr("Start Docker")
                    color: DockerService.dockerRunning ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnPrimaryContainer
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            onClicked: DockerService.toggleDockerService()
        }

        // Stats
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: statsRow.implicitHeight + 20
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2

            RowLayout {
                id: statsRow
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 10
                }
                spacing: 16

                ColumnLayout {
                    spacing: 2
                    StyledText {
                        text: Translation.tr("Containers")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: DockerService.runningCount + " / " + DockerService.containers.length
                        font.pixelSize: Appearance.font.pixelSize.large
                    }
                }

                ColumnLayout {
                    spacing: 2
                    StyledText {
                        text: Translation.tr("Memory")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: DockerService.totalMemoryMb > 0 ? DockerService.totalMemoryMb + " MB" : "—"
                        font.pixelSize: Appearance.font.pixelSize.large
                    }
                }
            }
        }

        // Container list
        Repeater {
            model: DockerService.containers

            delegate: Rectangle {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.preferredHeight: containerRow.implicitHeight + 16
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer2

                RowLayout {
                    id: containerRow
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 10
                    }
                    spacing: 8

                    // Status indicator
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: {
                            switch (modelData.state) {
                            case "running": return Appearance.colors.colPrimary
                            case "exited": return Appearance.colors.colSubtext
                            case "paused": return Appearance.colors.colTertiary
                            default: return Appearance.colors.colSubtext
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true

                        StyledText {
                            text: modelData.name || modelData.id?.substring(0, 12) || "Unknown"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: modelData.image || modelData.state || ""
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Action buttons
                    RowLayout {
                        spacing: 4

                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.normal
                            text: modelData.state === "running" ? "stop" : "play_arrow"
                            color: Appearance.colors.colSubtext

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    let action = modelData.state === "running" ? "stop" : "start";
                                    DockerService.containerAction(action, modelData.id);
                                }
                            }
                        }

                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.normal
                            text: "restart_alt"
                            color: Appearance.colors.colSubtext
                            visible: modelData.state === "running"

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: DockerService.containerAction("restart", modelData.id)
                            }
                        }
                    }
                }
            }
        }

        // Empty state
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            visible: DockerService.containers.length === 0

            StyledText {
                anchors.centerIn: parent
                text: Translation.tr("No containers found")
                color: Appearance.colors.colSubtext
            }
        }

        Item { Layout.fillHeight: true }
    }
}
