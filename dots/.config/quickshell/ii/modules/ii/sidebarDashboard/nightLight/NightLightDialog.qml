import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

WindowDialog {
    id: root
    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)
    backgroundHeight: 700

    readonly property int activeFeatureCount: (Hyprsunset.temperatureActive ? 1 : 0)
        + (HyprlandAntiFlashbangShader.enabled ? 1 : 0)
        + (Config.options.light.antiFlashbang.enable ? 1 : 0)

    component SectionCard: Rectangle {
        property string sectionIcon: ""
        property string sectionTitle: ""
        property string sectionSubtitle: ""
        property bool sectionActive: false
        default property alias innerData: cardInner.data

        Layout.fillWidth: true
        color: ColorUtils.transparentize(Appearance.colors.colLayer2, 0.35)
        radius: Appearance.rounding.normal
        border.width: 1
        border.color: ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.4)
        implicitHeight: cardColumn.implicitHeight + 24

        ColumnLayout {
            id: cardColumn
            anchors {
                fill: parent
                topMargin: 12
                bottomMargin: 12
                leftMargin: 14
                rightMargin: 14
            }
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: 26
                    height: 26
                    radius: Appearance.rounding.small
                    color: sectionActive ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHighest

                    Behavior on color {
                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: sectionIcon
                        iconSize: 16
                        color: sectionActive ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurfaceVariant
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: -2

                    StyledText {
                        Layout.fillWidth: true
                        text: sectionTitle
                        color: Appearance.colors.colOnSurface
                        font {
                            family: Appearance.font.family.title
                            pixelSize: Appearance.font.pixelSize.normal
                            variableAxes: Appearance.font.variableAxes.title
                        }
                        elide: Text.ElideRight
                    }
                    StyledText {
                        visible: sectionSubtitle !== ""
                        Layout.fillWidth: true
                        text: sectionSubtitle
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        elide: Text.ElideRight
                    }
                }
            }

            Column {
                id: cardInner
                Layout.fillWidth: true
                spacing: 2
            }
        }
    }

    // Header
    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        MaterialShapeWrappedMaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: root.activeFeatureCount > 0 ? "visibility" : "visibility_off"
            iconSize: 18
            padding: 7
            shape: MaterialShape.Shape.Cookie7Sided
            color: root.activeFeatureCount > 0 ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHighest
            colSymbol: root.activeFeatureCount > 0 ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurfaceVariant
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Eye protection")
                color: Appearance.colors.colOnSurface
                elide: Text.ElideRight
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.title
                    variableAxes: Appearance.font.variableAxes.title
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.activeFeatureCount === 0
                    ? Translation.tr("Nothing active")
                    : Translation.tr("%1 active").arg(root.activeFeatureCount)
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                elide: Text.ElideRight
                animateChange: true
            }
        }
    }

    WindowDialogSeparator {}

    // Scrollable body with cards
    Item {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.topMargin: -8
        Layout.bottomMargin: -8

        StyledFlickable {
            id: bodyFlick
            anchors.fill: parent
            clip: true
            contentHeight: bodyColumn.implicitHeight

            ColumnLayout {
                id: bodyColumn
                width: bodyFlick.width
                spacing: 10

                // Night Light
                SectionCard {
                    sectionIcon: "nightlight"
                    sectionTitle: Translation.tr("Night Light")
                    sectionSubtitle: Hyprsunset.temperatureActive
                        ? Translation.tr("%1K").arg(Math.round(Config.options.light.night.colorTemperature))
                        : Translation.tr("Warms the screen at night")
                    sectionActive: Hyprsunset.temperatureActive

                    ConfigSwitch {
                        anchors {
                            left: parent.left
                            right: parent.right
                        }
                        iconSize: Appearance.font.pixelSize.larger
                        buttonIcon: "check"
                        text: Translation.tr("Enable now")
                        checked: Hyprsunset.temperatureActive
                        onCheckedChanged: Hyprsunset.toggleTemperature(checked)
                    }

                    ConfigSwitch {
                        anchors {
                            left: parent.left
                            right: parent.right
                        }
                        iconSize: Appearance.font.pixelSize.larger
                        buttonIcon: "night_sight_auto"
                        text: Translation.tr("Automatic")
                        checked: Config.options.light.night.automatic
                        onCheckedChanged: Config.options.light.night.automatic = checked
                    }

                    // Schedule: always shown, so the on/off times are discoverable without
                    // first having to turn Automatic on. Dimmed while it is off, since the
                    // times only take effect in automatic mode.
                    Item {
                        anchors {
                            left: parent.left
                            right: parent.right
                        }
                        implicitHeight: scheduleRow.implicitHeight + 6
                        opacity: Config.options.light.night.automatic ? 1 : 0.55

                        Behavior on opacity {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }

                        RowLayout {
                            id: scheduleRow
                            anchors {
                                left: parent.left
                                right: parent.right
                                top: parent.top
                                leftMargin: 4
                                rightMargin: 4
                            }
                            spacing: 8

                            TimeField {
                                Layout.fillWidth: true
                                icon: ""
                                text: Translation.tr("Turns on")
                                value: Config.options.light.night.from
                                onEdited: (value) => Config.options.light.night.from = value
                            }

                            TimeField {
                                Layout.fillWidth: true
                                icon: ""
                                text: Translation.tr("Turns off")
                                value: Config.options.light.night.to
                                onEdited: (value) => Config.options.light.night.to = value
                            }
                        }
                    }

                    WindowDialogSlider {
                        anchors {
                            left: parent.left
                            right: parent.right
                            leftMargin: 4
                            rightMargin: 4
                        }
                        text: Translation.tr("Intensity")
                        from: 6500
                        to: 1200
                        stopIndicatorValues: [5000, to]
                        value: Config.options.light.night.colorTemperature
                        onMoved: Config.options.light.night.colorTemperature = value
                        tooltipContent: `${Math.round(value)}K`
                    }
                }

                // Anti-flashbang
                SectionCard {
                    sectionIcon: "flash_off"
                    sectionTitle: Translation.tr("Anti-flashbang")
                    sectionSubtitle: Translation.tr("Experimental")
                    sectionActive: HyprlandAntiFlashbangShader.enabled || Config.options.light.antiFlashbang.enable

                    ConfigSwitch {
                        anchors {
                            left: parent.left
                            right: parent.right
                        }
                        iconSize: Appearance.font.pixelSize.larger
                        buttonIcon: "filter"
                        text: Translation.tr("Content adjustment")
                        checked: HyprlandAntiFlashbangShader.enabled
                        onCheckedChanged: {
                            if (checked) HyprlandAntiFlashbangShader.enable();
                            else HyprlandAntiFlashbangShader.disable();
                        }
                        StyledToolTip {
                            text: Translation.tr("<b>Dims screen content</b> as needed.<br><br>Pros: Immediately responsive<br>Cons: Expensive and can hurt color accuracy<br><br><i>Uses a Hyprland screen shader</i>")
                        }
                    }

                    ConfigSwitch {
                        anchors {
                            left: parent.left
                            right: parent.right
                        }
                        iconSize: Appearance.font.pixelSize.larger
                        buttonIcon: "light_mode"
                        text: Translation.tr("Brightness adjustment")
                        checked: Config.options.light.antiFlashbang.enable
                        onCheckedChanged: Config.options.light.antiFlashbang.enable = checked
                        StyledToolTip {
                            text: Translation.tr("Adapts the <b>display (physical screen) brightness</b><br><br>Pros: Less expensive, retains colors<br>Cons: Not immediately responsive<br><br><i>Adjusts display brightness after each Hyprland IPC event</i>")
                        }
                    }
                }

                // Brightness
                SectionCard {
                    sectionIcon: "brightness_6"
                    sectionTitle: Translation.tr("Brightness")
                    sectionSubtitle: `${Math.round((root.brightnessMonitor?.brightness ?? 0) * 100)}%`
                    sectionActive: (root.brightnessMonitor?.brightness ?? 1) < 0.99

                    WindowDialogSlider {
                        anchors {
                            left: parent.left
                            right: parent.right
                            leftMargin: 4
                            rightMargin: 4
                        }
                        value: root.brightnessMonitor?.brightness ?? 0
                        onMoved: root.brightnessMonitor.setBrightness(value)
                        tooltipContent: `${Math.round(value * 100)}%`
                    }
                }

                // Gamma
                SectionCard {
                    sectionIcon: "gradient"
                    sectionTitle: Translation.tr("Gamma")
                    sectionSubtitle: `${Math.round(Hyprsunset.gamma)}%`
                    sectionActive: Hyprsunset.gamma < 100

                    WindowDialogSlider {
                        anchors {
                            left: parent.left
                            right: parent.right
                            leftMargin: 4
                            rightMargin: 4
                        }
                        from: Hyprsunset.gammaLowerLimit / 100
                        to: Hyprsunset.gammaUpperLimit / 100
                        value: Hyprsunset.gamma / 100
                        onMoved: Hyprsunset.setGamma(value * 100)
                        tooltipContent: `${Math.round(value * 100)}%`
                    }
                }
            }
        }
    }

    WindowDialogSeparator {}

    WindowDialogButtonRow {
        Layout.fillWidth: true

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: Translation.tr("Done")
            onClicked: root.dismiss()
        }
    }
}
