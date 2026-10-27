import qs.modules.common.widgets
import qs.modules.common
import QtQuick
import QtQuick.Layouts
import qs.services

Item {
    id: root
    property string text: ""
    property string buttonIcon: ""
    property alias value: slider.value
    property alias stepSize: slider.stepSize
    property alias tooltipContent: slider.tooltipContent
    property alias stopIndicatorValues: slider.stopIndicatorValues
    property bool usePercentTooltip: true
    property real from: slider.from
    property real to: slider.to
    property real textWidth: 120

    Layout.fillWidth: true
    implicitHeight: mainRow.implicitHeight + 16

    readonly property string currentSearch: SearchRegistry.currentSearch
    onCurrentSearchChanged: {
        if (SearchRegistry.currentSearch.toLowerCase() === root.text.toLowerCase()) {
            highlightOverlay.startAnimation()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: mouseArea.containsMouse ? Appearance.colors.colLayer1Hover : "transparent"
        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    RowLayout {
        id: mainRow
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10
        
        RowLayout {
            id: row
            spacing: 10

            OptionalMaterialSymbol {
                opacity: 1 - highlightOverlay.opacity
                id: iconWidget
                icon: root.buttonIcon
                iconSize: Appearance.font.pixelSize.larger
            }
            StyledText {
                opacity: 1 - highlightOverlay.opacity
                id: labelWidget
                Layout.preferredWidth: root.textWidth
                text: root.text
                color: Appearance.colors.colOnSecondaryContainer
            }
            HighlightOverlay {
                id: highlightOverlay
                visible: false
            }
        }
        
        StyledSlider {
            id: slider
            Layout.fillWidth: true
            configuration: StyledSlider.Configuration.XS
            usePercentTooltip: root.usePercentTooltip
            value: root.value
            from: root.from
            to: root.to
        }
    }
}