import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// Three-way switch for the sleep hint: "Auto" follows the school calendar (alarm on a
// school morning, prediction on a weekend or break), the other two pin it either way.
// The caller owns the value and the write, so the same control works in the bar popup
// and on the desktop card, which have different foreground colours.
RowLayout {
    id: root

    property color fgColor: Appearance.colors.colOnSurface
    property string value: "auto"
    signal selected(string mode)

    spacing: 4

    readonly property var modes: [
        { id: "auto", label: "Auto" },
        { id: "alarm", label: "Alarm" },
        { id: "predict", label: "Predict" }
    ]

    StyledText {
        text: Translation.tr("Mode")
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: root.fgColor
        opacity: 0.6
    }

    Repeater {
        model: root.modes
        delegate: Rectangle {
            id: chip
            required property var modelData
            readonly property bool selected: root.value === modelData.id

            implicitHeight: 20
            implicitWidth: chipLabel.implicitWidth + 16
            radius: Appearance.rounding.full
            color: chip.selected
                ? Appearance.colors.colPrimary
                : ColorUtils.transparentize(root.fgColor, 0.88)

            StyledText {
                id: chipLabel
                anchors.centerIn: parent
                text: Translation.tr(chip.modelData.label)
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: chip.selected ? Appearance.colors.colOnPrimary : root.fgColor
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selected(chip.modelData.id)
            }
        }
    }

    Item { Layout.fillWidth: true }
}
