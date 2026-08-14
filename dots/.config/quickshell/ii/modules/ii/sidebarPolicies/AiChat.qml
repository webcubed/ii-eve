import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 40

            MaterialIcon {
                icon: "psychology"
                Layout.alignment: Qt.AlignVCenter
            }

            StyledText {
                text: Translation.tr("AI Chat")
                font.pixelSize: Appearance.font.pixelSize.large
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            // Status indicator
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 10
                height: 10
                radius: 5
                color: Ai.currentModelHasApiKey ? Appearance.colors.colPositive : Appearance.colors.colNegative
            }
        }

        // Messages area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Appearance.colors.colLayer2
            radius: Appearance.rounding.normal

            ScrollView {
                id: scrollView
                anchors.fill: parent
                anchors.margins: 8

                ListView {
                    id: listView
                    model: Ai.messageIDs
                    spacing: 8
                    clip: true

                    delegate: Rectangle {
                        width: listView.width
                        height: messageContent.height + 16
                        color: Ai.messageByID[modelData]?.role === "user" 
                            ? Appearance.colors.colLayer3 
                            : Appearance.colors.colLayer1
                        radius: Appearance.rounding.small

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 4

                            // Role indicator
                            StyledText {
                                text: Ai.messageByID[modelData]?.role === "user" ? "You" : "AI"
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                                Layout.fillWidth: true
                            }

                            // Message content
                            StyledText {
                                id: messageContent
                                text: Ai.messageByID[modelData]?.content ?? ""
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }

                            // Thinking indicator
                            StyledText {
                                visible: Ai.messageByID[modelData]?.thinking ?? false
                                text: "Thinking..."
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }

        // Input area
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            spacing: 8

            TextField {
                id: inputField
                Layout.fillWidth: true
                Layout.fillHeight: true
                placeholderText: Translation.tr("Type a message...")
                color: Appearance.colors.colText
                placeholderTextColor: Appearance.colors.colSubtext
                background: Rectangle {
                    color: Appearance.colors.colLayer2
                    radius: Appearance.rounding.small
                    border.color: inputField.activeFocus ? Appearance.colors.colHighlight : Appearance.colors.colLayer3
                    border.width: 1
                }
                onAccepted: {
                    if (text.trim().length > 0) {
                        Ai.sendUserMessage(text.trim());
                        text = "";
                    }
                }
            }

            Button {
                Layout.fillHeight: true
                implicitWidth: 50

                background: Rectangle {
                    color: Appearance.colors.colHighlight
                    radius: Appearance.rounding.small
                }

                contentItem: MaterialIcon {
                    icon: "send"
                    color: Appearance.colors.colHighlightText
                }

                onClicked: {
                    if (inputField.text.trim().length > 0) {
                        Ai.sendUserMessage(inputField.text.trim());
                        inputField.text = "";
                    }
                }
            }
        }

        // Status bar
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            spacing: 8

            StyledText {
                text: Ai.currentModel
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
                Layout.fillWidth: true
            }

            StyledText {
                text: Ai.tokenCount.total >= 0 ? `${Ai.tokenCount.total} tokens` : ""
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }
        }
    }

    Component.onCompleted: {
        if (Ai.messageIDs.length === 0) {
            Ai.addMessage("Hello! I'm your AI assistant. How can I help you today?", Ai.interfaceRole);
        }
    }
}
