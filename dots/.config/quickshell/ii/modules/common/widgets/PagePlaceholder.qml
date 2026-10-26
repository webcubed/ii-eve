import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.widgets.animations

Item {
    id: root

    property bool shown: true
    property alias icon: shapeWidget.text
    property alias iconSize: shapeWidget.iconSize
    property alias iconPadding: shapeWidget.padding
    property alias title: widgetNameText.text
    property alias description: widgetDescriptionText.text
    property alias shape: shapeWidget.shape
    property alias descriptionHorizontalAlignment: widgetDescriptionText.horizontalAlignment
    property alias rotateIconWithShape: shapeWidget.rotateIconWithShape

    property alias iconWidget: shapeWidget
    property alias titleWidget: widgetNameText
    property alias descriptionWidget: widgetDescriptionText

    property alias triggerAnimationOn: openingAnimation.trigger
    property alias rotateToRight: openingAnimation.rotateToRight
    property bool animateIconOnShow: false
    property real titlePixelSize: Appearance.font.pixelSize.larger
    property real descriptionPixelSize: Appearance.font.pixelSize.small
    property int entranceTrigger: -1
    
    onEntranceTriggerChanged: {
        if (entranceTrigger >= 0 && shown && animateIconOnShow) {
            triggerEntrance();
        }
    }
    
    function triggerEntrance() {
        openingAnimation.trigger = true;
    }
    PlaceholderOpeningAnimation {
        id: openingAnimation
        targetPlaceholder: root
    }

    opacity: shown ? 1 : 0
    visible: opacity > 0
    anchors {
        fill: parent
        topMargin: -30 * (1 - opacity)
        bottomMargin: 30 * (1 - opacity)
    }

    Behavior on opacity {
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 5

        MaterialShapeWrappedMaterialSymbol {
            id: shapeWidget
            Layout.alignment: Qt.AlignHCenter
            padding: 12
            iconSize: 56
            rotation: -70 * (1 - shown ? 1 : 0)

            Behavior on rotation {
                animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
            }
        }

        StyledText {
            id: widgetNameText
            visible: title !== ""
            Layout.alignment: Qt.AlignHCenter
            font {
                family: Appearance.font.family.title
                pixelSize: root.titlePixelSize
                variableAxes: Appearance.font.variableAxes.title
            }
            color: Appearance.m3colors.m3outline
            horizontalAlignment: Text.AlignHCenter
        }
        StyledText {
            id: widgetDescriptionText
            visible: description !== ""
            Layout.fillWidth: true
            font.pixelSize: root.descriptionPixelSize
            color: Appearance.m3colors.m3outline
            horizontalAlignment: Text.AlignLeft
            wrapMode: Text.Wrap
        }
    }
}
