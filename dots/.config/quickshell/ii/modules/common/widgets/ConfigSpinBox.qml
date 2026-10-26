import qs.modules.common.widgets
import qs.modules.common
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property string text: ""
    property string icon
    property alias value: spinBoxWidget.value
    property alias stepSize: spinBoxWidget.stepSize
    property alias from: spinBoxWidget.from
    property alias to: spinBoxWidget.to
    signal valueModified()
    
    Layout.fillWidth: true
    implicitHeight: rowLayout.implicitHeight + 16

    HighlightOverlay {
        id: highlightOverlay
        anchors.fill: parent
        anchors.topMargin: -2
        anchors.bottomMargin: -2
        anchors.leftMargin: -4
        anchors.rightMargin: -4
    }

    SearchHandler {
        searchString: root.text
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
        id: rowLayout
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        RowLayout {
            spacing: 10
            OptionalMaterialSymbol {
                icon: root.icon
                opacity: root.enabled ? 1 : 0.4
                iconSize: Appearance.font.pixelSize.larger
            }
            StyledText {
                id: labelWidget
                Layout.fillWidth: true
                text: root.text
                color: Appearance.colors.colOnSecondaryContainer
                opacity: root.enabled ? 1 : 0.4
            }
        }

        StyledSpinBox {
            id: spinBoxWidget
            Layout.fillWidth: false
            value: root.value
            onValueModified: root.valueModified()
        }
    }
}
