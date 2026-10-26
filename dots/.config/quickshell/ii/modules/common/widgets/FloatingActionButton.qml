import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/**
 * Material 3 FAB.
 */
RippleButton {
    id: root
    property string iconText: "add"
    property bool expanded: false
    property real baseSize: 56
    property real iconSize: 26
    property real elementSpacing: 5
    // Opt-in keybind hint (NavigationRailButton pattern): while showShortcutHints
    // is on, the icon gives way to the shortcut text without moving the button.
    property string shortcut: ""
    property bool showShortcutHints: false
    implicitWidth: expanded ? (Math.max(contentRowLayout.implicitWidth + 10 * 2, baseSize)) : baseSize
    implicitHeight: baseSize

    readonly property bool sharpMode: Config.options.appearance.sharpMode
    buttonRadius: sharpMode ? 0 : baseSize / 14 * 4
    
    colBackground: Appearance.colors.colPrimaryContainer
    colBackgroundHover: Appearance.colors.colPrimaryContainerHover
    colRipple: Appearance.colors.colPrimaryContainerActive
    property color colOnBackground: Appearance.colors.colOnPrimaryContainer
    contentItem: Row {
        id: contentRowLayout
        property real horizontalMargins: (root.baseSize - icon.width) / 2
        anchors {
            verticalCenter: parent?.verticalCenter
            left: parent?.left
            leftMargin: contentRowLayout.horizontalMargins
        }
        spacing: 0

        Item {
            id: iconWrap
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: Math.max(icon.implicitWidth, shortcutHint.implicitWidth)
            implicitHeight: Math.max(icon.implicitHeight, shortcutHint.implicitHeight)

            MaterialSymbol {
                id: icon
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                iconSize: root.iconSize
                color: root.colOnBackground
                text: root.iconText
                opacity: root.showShortcutHints && root.shortcut.length > 0 ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
            StyledText {
                id: shortcutHint
                anchors.centerIn: parent
                color: root.colOnBackground
                text: root.shortcut
                font.pixelSize: 13
                font.weight: Font.DemiBold
                opacity: root.showShortcutHints && root.shortcut.length > 0 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
        }
        Loader {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.buttonText?.length > 0
            active: true
            sourceComponent: Revealer {
                visible: root.expanded || implicitWidth > 0
                reveal: root.expanded
                implicitWidth: reveal ? (buttonText.implicitWidth + root.elementSpacing + contentRowLayout.horizontalMargins) : 0
                implicitHeight: buttonText.implicitHeight
                StyledText {
                    id: buttonText
                    anchors {
                        left: parent.left
                        leftMargin: root.elementSpacing
                        verticalCenter: parent.verticalCenter
                    }
                    text: root.buttonText
                    color: Appearance.colors.colOnPrimaryContainer
                    font.pixelSize: 14
                    font.weight: 450
                }
            }
        }
    }
}
