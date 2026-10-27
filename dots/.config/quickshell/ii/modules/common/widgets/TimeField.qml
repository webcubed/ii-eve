import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * A "HH:mm" editor laid out like a settings row: icon, label, then a small
 * validated time box. Emits `edited` only once the typed text is a real time,
 * so callers can write it straight into the config.
 */
Item {
    id: root
    property string text: ""
    property string value: "19:00"
    property string icon: "schedule"
    signal edited(string value)

    implicitHeight: 44
    implicitWidth: row.implicitWidth

    readonly property var timePattern: /^([01]?[0-9]|2[0-3]):[0-5][0-9]$/

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 10

        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            visible: root.icon !== ""
            text: root.icon
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnLayer1
        }

        StyledText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: root.text
            font.pixelSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnLayer1
            elide: Text.ElideRight
        }

        Rectangle {
            id: fieldBackground
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 84
            implicitHeight: 34
            radius: Appearance.rounding.small
            color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.92)
            border.width: timeInput.activeFocus ? 1 : 0
            border.color: Appearance.colors.colPrimary

            StyledTextInput {
                id: timeInput
                anchors.centerIn: parent
                width: parent.width - 16
                horizontalAlignment: Text.AlignHCenter
                text: root.value
                font.pixelSize: Appearance.font.pixelSize.normal
                onEditingFinished: {
                    if (root.timePattern.test(timeInput.text)) root.edited(timeInput.text)
                    else timeInput.text = root.value
                }
            }
        }
    }
}
