import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "resources"
    hoverEnabled: true

    property bool hasBattery: Battery.available

    implicitWidth: WidgetGrid.spanWidth(2)
    implicitHeight: WidgetGrid.spanHeight(2)

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Appearance.rounding?.verylarge ?? 30
        color: Appearance.colors.colPrimaryContainer

        StyledRectangularShadow {
            target: card
            z: -2
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: 22
            }
            spacing: 0

            StatRow {
                Layout.fillWidth: true
                Layout.fillHeight: true
                icon: "planner_review"
                label: "CPU"
                shape: MaterialShape.Shape.Gem
                barColor: Appearance.colors.colPrimary
                value: ResourceUsage.cpuUsage
                valueText: Math.round(ResourceUsage.cpuUsage * 100) + "%"
            }
            StatRow {
                Layout.fillWidth: true
                Layout.fillHeight: true
                icon: "memory"
                label: "RAM"
                shape: MaterialShape.Shape.Cookie4Sided
                barColor: Appearance.colors.colSecondary
                value: ResourceUsage.memoryUsedPercentage
                valueText: Math.round(ResourceUsage.memoryUsedPercentage * 100) + "%"
            }
            StatRow {
                Layout.fillWidth: true
                Layout.fillHeight: true
                icon: root.hasBattery ? "battery_full" : "storage"
                label: root.hasBattery ? "Battery" : "Disk"
                shape: MaterialShape.Shape.Cookie12Sided
                barColor: Appearance.colors.colTertiary
                value: root.hasBattery ? Battery.percentage : ResourceUsage.diskUsedPercentage
                valueText: Math.round((root.hasBattery ? Battery.percentage : ResourceUsage.diskUsedPercentage) * 100) + "%"
            }
        }
    }

    component StatRow: Item {
        id: statRow
        property string icon: ""
        property string label: ""
        property string valueText: ""
        property real value: 0
        property int shape: MaterialShape.Shape.Cookie12Sided
        property color barColor: Appearance.colors.colPrimary

        implicitHeight: statContent.implicitHeight
        implicitWidth: statContent.implicitWidth

        ColumnLayout {
            id: statContent
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
                right: parent.right
            }
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                MaterialShapeWrappedMaterialSymbol {
                    shape: statRow.shape
                    color: statRow.barColor
                    colSymbol: Appearance.colors.colOnPrimary
                    text: statRow.icon
                    iconSize: 16
                    fill: 1
                    padding: 7
                    implicitWidth: 30
                    implicitHeight: 30
                }

                StyledText {
                    text: statRow.label
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnPrimaryContainer
                    opacity: 0.7
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    text: statRow.valueText
                    font.pixelSize: Appearance.font.pixelSize.hugeass
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnPrimaryContainer
                    // The widget canvas is drawn scaled, where native rasterisation leaves the
                    // glyphs uneven; QtRendering stays smooth.
                    renderType: Text.QtRendering
                }
            }

            Rectangle { // Usage track
                Layout.fillWidth: true
                implicitHeight: 8
                radius: implicitHeight / 2
                color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.78)
                clip: true

                Rectangle { // Usage fill
                    width: Math.max(0, Math.min(1, statRow.value)) * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: statRow.barColor

                    Behavior on width {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                }
            }
        }
    }
}
