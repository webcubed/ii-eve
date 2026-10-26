import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import "./cards"

StyledPopup {
    id: root
    popupRadius: Appearance.rounding.large

    function formatTime(seconds) {
        var h = Math.floor(seconds / 3600);
        var m = Math.floor((seconds % 3600) / 60);
        if (h > 0) return `${h}h ${m}m`;
        return `${m}m`;
    }

    function getStateText() {
        if (Battery.chargeState === 4) return Translation.tr("Fully charged");
        if (Battery.chargeState === 1) return Translation.tr("Charging");
        return Translation.tr("Discharging");
    }

    function getChargeColor() {
        if (Battery.chargePercent > 60) return Appearance.colors.colPrimary;
        if (Battery.chargePercent > 20) return Appearance.colors.colTertiary;
        return Appearance.colors.colError;
    }

    animate: false
    contentItem: ColumnLayout {
        anchors.centerIn: parent
        spacing: 8

        // Hero card with gradient background
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            radius: Appearance.rounding.normal

            gradient: Gradient {
                GradientStop { position: 0.0; color: Appearance.colors.colPrimaryContainer }
                GradientStop { position: 1.0; color: Appearance.colors.colSurfaceContainerLow }
            }

            Item {
                anchors.fill: parent
                anchors.margins: 16

                // Battery icon and percentage
                ColumnLayout {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    spacing: -2

                    StyledText {
                        text: root.getStateText()
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer0
                    }

                    StyledText {
                        text: {
                            if (Battery.chargeState === 1)
                                return Translation.tr("Rate:") + " " + Battery.energyRate.toFixed(1) + "W";
                            else if (Battery.chargeState !== 4 && Battery.timeToEmpty > 0)
                                return Translation.tr("Remaining:") + " " + root.formatTime(Battery.timeToEmpty);
                            return "";
                        }
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.7
                    }
                }

                // Large percentage
                RowLayout {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -4
                    spacing: 4

                    StyledText {
                        text: Battery.chargePercent
                        font.pixelSize: 48
                        font.weight: Font.Light
                        color: Appearance.colors.colOnLayer0
                    }

                    StyledText {
                        text: "%"
                        font.pixelSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.6
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 8
                    }
                }

                // Battery icon
                MaterialSymbol {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: -2
                    fill: 0
                    text: Battery.isCharging ? "battery_charging_full" : "battery_android_full"
                    iconSize: 40
                    color: root.getChargeColor()
                }

                // Health info
                ColumnLayout {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: 4
                    anchors.bottomMargin: -2
                    spacing: -2

                    RowLayout {
                        spacing: 4
                        Layout.alignment: Qt.AlignRight
                        MaterialSymbol {
                            text: "favorite"
                            iconSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: Translation.tr("Health:") + " " + Battery.health.toFixed(0) + "%"
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colOnLayer0
                            opacity: 0.8
                        }
                    }

                    RowLayout {
                        visible: Battery.energyRate > 0
                        spacing: 4
                        Layout.alignment: Qt.AlignRight
                        MaterialSymbol {
                            text: "bolt"
                            iconSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: Battery.energyRate.toFixed(1) + "W"
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colOnLayer0
                            opacity: 0.8
                        }
                    }
                }
            }
        }

        // Detail cards
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 4
            columnSpacing: 4
            uniformCellWidths: true

            Layout.leftMargin: 2
            Layout.rightMargin: 2

            MetricCard {
                title: Translation.tr("Time to " + (Battery.isCharging ? "full" : "empty"))
                symbol: "schedule"
                value: {
                    const secs = Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty;
                    return root.formatTime(secs);
                }
            }

            MetricCard {
                title: Translation.tr("Health")
                symbol: "favorite"
                value: Battery.health.toFixed(1) + "%"
            }

            MetricCard {
                visible: Battery.energyRate > 0
                title: Translation.tr("Power")
                symbol: "bolt"
                value: Battery.energyRate.toFixed(1) + "W"
            }

            MetricCard {
                title: Translation.tr("Status")
                symbol: Battery.isCharging ? "charging" : "battery_std"
                value: root.getStateText()
            }
        }
    }
}
