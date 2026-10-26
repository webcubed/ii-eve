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
                text: "mail"
                color: EmailService.authenticated ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
            }

            StyledText {
                text: "Gmail"
                font.pixelSize: Appearance.font.pixelSize.large
                Layout.fillWidth: true
            }

            Rectangle {
                implicitWidth: statusChip.implicitWidth + 16
                implicitHeight: statusChip.implicitHeight + 8
                radius: Appearance.rounding.small
                color: EmailService.authenticated ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHighest

                StyledText {
                    id: statusChip
                    anchors.centerIn: parent
                    text: EmailService.authenticated ? EmailService.userEmail : Translation.tr("Not connected")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: EmailService.authenticated ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }

        // Auth / Sync button
        RippleButton {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            buttonRadius: Appearance.rounding.normal
            colBackground: EmailService.authenticated ? Appearance.colors.colTertiaryContainer : Appearance.colors.colPrimaryContainer
            colBackgroundHover: EmailService.authenticated ? Appearance.colors.colTertiary : Appearance.colors.colPrimary

            contentItem: RowLayout {
                anchors.centerIn: parent
                spacing: 8

                MaterialSymbol {
                    iconSize: Appearance.font.pixelSize.large
                    text: EmailService.authenticated ? "sync" : "login"
                    color: EmailService.authenticated ? Appearance.colors.colOnTertiaryContainer : Appearance.colors.colOnPrimaryContainer
                }

                StyledText {
                    text: EmailService.authenticated ? Translation.tr("Sync Inbox") : Translation.tr("Sign in with Google")
                    color: EmailService.authenticated ? Appearance.colors.colOnTertiaryContainer : Appearance.colors.colOnPrimaryContainer
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            onClicked: {
                if (EmailService.authenticated)
                    EmailService.syncAll();
                else
                    EmailService.startOAuth();
                }
        }

        // Unread badge
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: unreadRow.implicitHeight + 20
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2
            visible: EmailService.authenticated && EmailService.inboxUnreadCount > 0

            RowLayout {
                id: unreadRow
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 10
                }
                spacing: 8

                MaterialSymbol {
                    iconSize: Appearance.font.pixelSize.large
                    text: "mark_email_unread"
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    text: Translation.tr("%1 unread messages").arg(EmailService.inboxUnreadCount)
                    Layout.fillWidth: true
                }
            }
        }

        // Inbox messages
        Repeater {
            model: EmailService.authenticated ? EmailService.inboxMessages : []

            delegate: Rectangle {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.preferredHeight: emailRow.implicitHeight + 16
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer2

                RowLayout {
                    id: emailRow
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 10
                    }
                    spacing: 10

                    // Unread indicator
                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: Appearance.colors.colPrimary
                        visible: !modelData.isRead
                    }

                    ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true

                        StyledText {
                            text: modelData.from || "Unknown"
                            font.pixelSize: modelData.isRead ? Appearance.font.pixelSize.small : Appearance.font.pixelSize.normal
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            color: !modelData.isRead ? Appearance.colors.colOnSurface : Appearance.colors.colSubtext
                        }

                        StyledText {
                            text: modelData.subject || Translation.tr("(no subject)")
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            color: !modelData.isRead ? Appearance.colors.colOnSurface : Appearance.colors.colSubtext
                        }

                        StyledText {
                            text: modelData.snippet || ""
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            Layout.fillWidth: true
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.link)
                            Qt.openUrlExternally(modelData.link);
                        if (!modelData.isRead)
                            EmailService.markAsRead(modelData.id);
                    }
                }
            }
        }

        // Empty state
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            visible: !EmailService.authenticated || EmailService.inboxMessages.length === 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    iconSize: Appearance.font.pixelSize.huge
                    text: EmailService.authenticated ? "inbox" : "mail"
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: EmailService.authenticated ? Translation.tr("No messages") : Translation.tr("Sign in to view your inbox")
                    color: Appearance.colors.colSubtext
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
