import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property real padding: 4
    property string editingNoteId: ""
    property string editText: ""

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
                text: "sticky_note_2"
                color: Appearance.colors.colPrimary
            }

            StyledText {
                text: Translation.tr("Notes")
                font.pixelSize: Appearance.font.pixelSize.large
                Layout.fillWidth: true
            }

            StyledText {
                text: NotesService.list.length
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }
        }

        // New note input
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: newNoteRow.implicitHeight + 16
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2

            RowLayout {
                id: newNoteRow
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 8
                }
                spacing: 8

                MaterialSymbol {
                    iconSize: Appearance.font.pixelSize.normal
                    text: "edit"
                    color: Appearance.colors.colSubtext
                }

                TextInput {
                    id: newNoteInput
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnSurface
                    clip: true
                    verticalAlignment: Text.AlignVCenter

                    property string placeholderText: Translation.tr("Write a note...")

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: newNoteInput.placeholderText
                        color: Appearance.colors.colSubtext
                        visible: !newNoteInput.text && !newNoteInput.activeFocus
                    }

                    onAccepted: {
                        if (text.trim().length > 0) {
                            NotesService.addNote(text.trim());
                            text = "";
                        }
                    }
                }
            }
        }

        // Notes list
        Repeater {
            model: NotesService.list

            delegate: Rectangle {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.preferredHeight: noteContent.implicitHeight + 20
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer2

                ColumnLayout {
                    id: noteContent
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 10
                    }
                    spacing: 6

                    // Edit mode
                    Loader {
                        Layout.fillWidth: true
                        active: root.editingNoteId === modelData.id
                        visible: root.editingNoteId === modelData.id
                        sourceComponent: TextInput {
                            id: editInput
                            text: root.editText
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnSurface
                            wrapMode: TextEdit.Wrap
                            clip: true
                            Keys.onEscapePressed: root.cancelEdit()
                            Keys.onReturnPressed: root.saveEdit()
                            Component.onCompleted: {
                                forceActiveFocus();
                            }
                            onTextChanged: root.editText = text
                        }
                    }

                    // Display mode
                    StyledText {
                        Layout.fillWidth: true
                        visible: root.editingNoteId !== modelData.id
                        text: modelData.content || ""
                        wrapMode: Text.Wrap
                        maximumLineCount: 6
                        elide: Text.ElideRight
                    }

                    // Timestamp + actions
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: root.editingNoteId !== modelData.id

                        StyledText {
                            text: modelData.createdAt || ""
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                            Layout.fillWidth: true
                        }

                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.small
                            text: "edit"
                            color: Appearance.colors.colSubtext

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.editingNoteId = modelData.id;
                                    root.editText = modelData.content || "";
                                }
                            }
                        }

                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.small
                            text: "content_copy"
                            color: Appearance.colors.colSubtext

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.clipboardText = modelData.content || ""
                            }
                        }

                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.small
                            text: "delete"
                            color: Appearance.colors.colError

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NotesService.deleteNote(modelData.id)
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    visible: root.editingNoteId !== modelData.id
                    z: -1
                    acceptedButtons: Qt.NoButton
                    propagateComposedEvents: true
                }
            }
        }

        // Empty state
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            visible: NotesService.list.length === 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    iconSize: Appearance.font.pixelSize.huge
                    text: "sticky_note_2"
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("No notes yet")
                    color: Appearance.colors.colSubtext
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    function cancelEdit() {
        root.editingNoteId = "";
        root.editText = "";
    }

    function saveEdit() {
        if (root.editingNoteId && root.editText.trim().length > 0) {
            NotesService.updateNote(root.editingNoteId, root.editText.trim());
        }
        root.editingNoteId = "";
        root.editText = "";
    }
}
