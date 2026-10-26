import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root
    property string title: ""
    property string tooltip: ""
    property string icon: ""
    property Component headerExtra: null
    property bool collapsible: false
    property bool expanded: true
    default property alias contentData: sectionContent.data

    signal toggled()

    Layout.fillWidth: true
    Layout.topMargin: 4
    spacing: 2
    visible: expanded || !collapsible

    SearchHandler {
        searchString: root.title
    }

    MouseArea {
        Layout.fillWidth: true
        Layout.preferredHeight: (root.title && root.title.length > 0 ? implicitHeight : 0) + 4
        visible: root.collapsible
        hoverEnabled: root.collapsible
        cursorShape: root.collapsible ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.collapsible
        onClicked: {
            root.expanded = !root.expanded;
            root.toggled();
        }
    }

    RowLayout {
        ContentSubsectionLabel {
            opacity: 1 - highlightOverlay.opacity
            visible: root.title && root.title.length > 0
            text: root.title
        }
        MaterialSymbol {
            opacity: 1 - highlightOverlay.opacity
            visible: root.collapsible
            text: root.expanded ? "expand_more" : "chevron_right"
            iconSize: Appearance.font.pixelSize.large
        }
        MaterialSymbol {
            opacity: 1 - highlightOverlay.opacity
            visible: root.tooltip && root.tooltip.length > 0
            text: "info"
            iconSize: Appearance.font.pixelSize.large
            
            color: Appearance.colors.colSubtext
            MouseArea {
                id: infoMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.WhatsThisCursor
                StyledToolTip {
                    extraVisibleCondition: false
                    alternativeVisibleCondition: infoMouseArea.containsMouse
                    text: root.tooltip
                }
            }
        }
        HighlightOverlay {
            id: highlightOverlay
            visible: false
        }
        Item { Layout.fillWidth: true }
    }
    ColumnLayout {
        id: sectionContent
        Layout.fillWidth: true
        visible: !root.collapsible || root.expanded
        spacing: 2
    }
}
