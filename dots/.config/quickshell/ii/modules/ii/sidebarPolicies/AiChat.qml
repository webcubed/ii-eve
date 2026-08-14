import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 8

    // Header
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 40

        MaterialSymbol {
            iconSize: 20
            text: "psychology"
            color: Appearance.colors.colOnLayer1
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            text: Translation.tr("AI Chat")
            font.pixelSize: Appearance.font.pixelSize.large
            color: Appearance.colors.colOnLayer1
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // Messages area
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Appearance.colors.colLayer2
        radius: Appearance.rounding.normal

        ListView {
            id: listView
            anchors.fill: parent
            anchors.margins: 8
            model: Ai.messageIDs
            spacing: 8
            clip: true

            delegate: Rectangle {
                width: listView.width
                height: col.implicitHeight + 16
                color: Ai.messageByID[modelData]?.role === "user"
                    ? Appearance.colors.colLayer3
                    : Appearance.colors.colLayer1
                radius: Appearance.rounding.small

                ColumnLayout {
                    id: col
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    StyledText {
                        text: Ai.messageByID[modelData]?.role === "user" ? "You" : "AI"
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                        Layout.fillWidth: true
                    }

                    StyledText {
                        text: Ai.messageByID[modelData]?.content ?? ""
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                        color: Appearance.colors.colOnLayer1
                    }

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

    // Input area
    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        spacing: 8

        TextField {
            id: inputField
            Layout.fillWidth: true
            Layout.fillHeight: true
            placeholderText: Translation.tr("Type a message...")
            color: Appearance.colors.colOnLayer1
            placeholderTextColor: Appearance.colors.colSubtext
            background: Rectangle {
                color: Appearance.colors.colLayer2
                radius: Appearance.rounding.small
                border.color: inputField.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer3
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
            implicitWidth: 40

            background: Rectangle {
                color: Appearance.colors.colPrimary
                radius: Appearance.rounding.small
            }

            contentItem: MaterialSymbol {
                iconSize: 20
                text: "send"
                color: Appearance.colors.colOnPrimary
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
        Layout.preferredHeight: 20
        spacing: 8

        StyledText {
            text: Ai.currentModel ?? ""
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

    Component.onCompleted: {
        if (Ai.messageIDs.length === 0) {
            Ai.addMessage("Hello! I'm your AI assistant. How can I help you today?", Ai.interfaceRole);
        }
    }
}
