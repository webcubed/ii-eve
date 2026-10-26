pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: root

    property bool vertical: false
    property bool expanded: mediaActive || notificationActive || recordingActive
    property bool mediaActive: MprisController.activePlayer?.playbackState === MprisPlaybackState.Playing
    property bool notificationActive: Notifications.totalUnread > 0
    property bool recordingActive: HyprlandData?.isScreenRecording || false

    readonly property bool islandEnabled: Config.options?.bar?.dynamicIsland?.enabled ?? false

    implicitWidth: expanded ? expandedRow.implicitWidth + 24 : collapsedRow.implicitWidth + 24
    implicitHeight: vertical ? (expanded ? expandedCol.implicitHeight + 16 : collapsedCol.implicitHeight + 16) : Appearance.sizes.barHeight

    visible: root.islandEnabled

    // Expand/collapse animation
    Behavior on implicitWidth {
        enabled: Config.options?.bar?.dynamicIsland?.animate ?? true
        NumberAnimation { duration: 250; easing.type: Easing.InOutCubic }
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Appearance.rounding.full
        color: Appearance.colors.colSurfaceContainerHigh
        opacity: 0.9

        // Subtle gradient for depth
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.lighter(Appearance.colors.colSurfaceContainerHigh, 1.05) }
            GradientStop { position: 1.0; color: Qt.darker(Appearance.colors.colSurfaceContainerHigh, 1.02) }
        }
    }

    // Collapsed state - shows indicators
    RowLayout {
        id: collapsedRow
        visible: !root.expanded && !root.vertical
        anchors.centerIn: parent
        spacing: 8

        // Media indicator
        MaterialSymbol {
            visible: root.mediaActive
            fill: 1
            text: "music_note"
            iconSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colPrimary
        }

        // Notification indicator
        Rectangle {
            visible: root.notificationActive
            width: 8
            height: 8
            radius: 4
            color: Appearance.colors.colPrimary
        }

        // Recording indicator
        Rectangle {
            visible: root.recordingActive
            width: 8
            height: 8
            radius: 4
            color: Appearance.colors.colError
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.3; duration: 500 }
                NumberAnimation { to: 1.0; duration: 500 }
            }
        }
    }

    // Expanded state - shows content
    RowLayout {
        id: expandedRow
        visible: root.expanded && !root.vertical
        anchors.centerIn: parent
        spacing: 12

        // Media info
        RowLayout {
            visible: root.mediaActive
            spacing: 8

            MaterialSymbol {
                fill: 1
                text: "music_note"
                iconSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colPrimary
            }

            ColumnLayout {
                spacing: -2

                StyledText {
                    text: MprisController.activePlayer?.trackTitle || ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnSurface
                    elide: Text.ElideRight
                    Layout.maximumWidth: 150
                }

                StyledText {
                    text: MprisController.activePlayer?.trackArtist || ""
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnSurfaceVariant
                    elide: Text.ElideRight
                    Layout.maximumWidth: 150
                }
            }
        }

        // Divider between media and notifications
        Rectangle {
            visible: root.mediaActive && root.notificationActive
            width: 1
            height: 20
            color: Appearance.colors.outlineVariant
        }

        // Notification count
        RowLayout {
            visible: root.notificationActive
            spacing: 6

            MaterialSymbol {
                fill: 1
                text: "notifications"
                iconSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colPrimary
            }

            StyledText {
                text: Notifications.totalUnread
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnSurface
            }
        }

        // Recording indicator
        RowLayout {
            visible: root.recordingActive
            spacing: 6

            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: Appearance.colors.colError
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 500 }
                    NumberAnimation { to: 1.0; duration: 500 }
                }
            }

            StyledText {
                text: Translation.tr("Recording")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSurface
            }
        }
    }

    // Vertical mode
    ColumnLayout {
        id: expandedCol
        visible: root.expanded && root.vertical
        anchors.centerIn: parent
        spacing: 8

        MaterialSymbol {
            visible: root.mediaActive
            fill: 1
            text: "music_note"
            iconSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colPrimary
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            visible: root.notificationActive
            width: 8
            height: 8
            radius: 4
            color: Appearance.colors.colPrimary
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            visible: root.recordingActive
            width: 8
            height: 8
            radius: 4
            color: Appearance.colors.colError
            Layout.alignment: Qt.AlignHCenter
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.3; duration: 500 }
                NumberAnimation { to: 1.0; duration: 500 }
            }
        }
    }

    ColumnLayout {
        id: collapsedCol
        visible: !root.expanded && root.vertical
        anchors.centerIn: parent
        spacing: 6

        MaterialSymbol {
            visible: root.mediaActive
            fill: 1
            text: "music_note"
            iconSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colPrimary
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            visible: root.notificationActive
            width: 6
            height: 6
            radius: 3
            color: Appearance.colors.colPrimary
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            visible: root.recordingActive
            width: 6
            height: 6
            radius: 3
            color: Appearance.colors.colError
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
