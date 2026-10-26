import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.vimium

RowLayout {
    id: root
    Layout.fillWidth: true

    property string text: ""
    property string icon: ""
    property bool textOnlyWhenActive: false
    property color colBackground: Appearance.colors.colSecondaryContainer
    property color colBackgroundHover: Appearance.colors.colSecondaryContainerHover
    property color colBackgroundActive: Appearance.colors.colSecondaryContainerActive

    spacing: 10
    property var registry: null
    property list<var> options: [
        {
            "displayName": "Option 1",
            "icon": "check",
            "shape": "Arch",
            "symbol": "google-gemini-symbolic",
            "color": "red",
            "value": 1
        },
        {
            "displayName": "Option 2",
            "icon": "close",
            "shape": "Circle",
            "symbol": "mistral-symbolic",
            "color": "blue",
            "value": 2
        },
    ]
    property var currentValue: null

    signal selected(var newValue)

    RowLayout {
        spacing: 10
        visible: root.text !== ""
        OptionalMaterialSymbol {
            icon: root.icon
            opacity: root.enabled ? 1 : 0.4
        }
        StyledText {
            id: labelWidget
            Layout.fillWidth: true
            text: root.text
            color: Appearance.colors.colOnSecondaryContainer
            opacity: root.enabled ? 1 : 0.4
        }
    }

    Flow {
        id: buttonsFlow
        Layout.fillWidth: !root.text
        Layout.alignment: Qt.AlignRight
        spacing: 2

    Repeater {
        model: root.options
        delegate: SelectionGroupButton {
            id: paletteButton
            required property var modelData
            required property int index
            onYChanged: {
                if (index === 0) {
                    paletteButton.leftmost = true
                } else {
                    var prev = buttonsFlow.children[index - 1]
                    var thisIsOnNewLine = prev && prev.y !== paletteButton.y
                    paletteButton.leftmost = thisIsOnNewLine
                    prev.rightmost = thisIsOnNewLine
                }
            }
            enableImplicitWidthAnimation: !root.textOnlyWhenActive
            leftmost: index === 0
            rightmost: index === root.options.length - 1
            buttonIcon: modelData.icon || ""
            buttonShape: modelData.shape || ""
            buttonSymbol: modelData.symbol || ""
            buttonColor: modelData.color || ""
            buttonText: (!root.textOnlyWhenActive || paletteButton.toggled || paletteButton.hovered) ? (modelData.displayName ?? modelData) : ""
            enabled: modelData.enabled !== undefined ? modelData.enabled : true
            opacity: enabled ? 1.0 : 0.5
            toggled: root.currentValue == (modelData.value ?? modelData)
            releaseAction: modelData.releaseAction || ""

            colBackground: root.colBackground
            colBackgroundHover: root.colBackgroundHover
            colBackgroundActive: root.colBackgroundActive

            onClicked: {
                root.selected(modelData.value ?? modelData);
            }

            VimiumTarget {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: -5
                anchors.topMargin: -5
                registry: root.registry
                participates: paletteButton.enabled
                onActivated: root.selected(paletteButton.modelData.value ?? paletteButton.modelData)
            }
        }
    }
    }
}
