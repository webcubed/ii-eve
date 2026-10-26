import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "../cards"

import QtQuick
import QtQuick.Layouts
import qs.modules.ii.bar

StyledPopup {
    id: root
    popupRadius: Appearance.rounding.large

    required property bool compact
    property bool compactMode: Config.options.bar.tooltips.compactPopups
    property int cardMargins: 14

    readonly property var forecastData: Weather.forecastDaily
    readonly property var hourlyData: Weather.forecastHourly
    readonly property bool forecastLoading: Weather.forecastLoading
    property int maxHourlyBars: 5

    property var filteredHourlyData: {
        if (hourlyData.length === 0) return [];
        let stepHours = 3;
        if (hourlyData.length >= 2) {
            const h0 = Math.floor(parseInt(hourlyData[0].time) / 100);
            const h1 = Math.floor(parseInt(hourlyData[1].time) / 100);
            const diff = (h1 - h0 + 24) % 24;
            if (diff > 0) stepHours = diff;
        }
        const currentHr = new Date().getHours();
        const currentSlot = Math.floor(currentHr / stepHours) * stepHours;
        let futureHours = [];
        let passedMidnight = false;
        for (let i = 0; i < hourlyData.length; i++) {
            const item = hourlyData[i];
            const itemHour = Math.floor(parseInt(item.time) / 100);
            if (i > 0 && itemHour < Math.floor(parseInt(hourlyData[i - 1].time) / 100))
                passedMidnight = true;
            if (passedMidnight || itemHour >= currentSlot)
                futureHours.push(item);
        }
        return futureHours.slice(0, maxHourlyBars);
    }

    function getDayName(dateStr, index) {
        if (index === 0) return Translation.tr("Today");
        if (index === 1) return Translation.tr("Tomorrow");
        const date = new Date(dateStr);
        const days = [Translation.tr("Sun"), Translation.tr("Mon"), Translation.tr("Tue"), Translation.tr("Wed"), Translation.tr("Thu"), Translation.tr("Fri"), Translation.tr("Sat")];
        return days[date.getDay()];
    }

    function formatHour(timeStr) {
        const hour = Math.floor(parseInt(timeStr) / 100);
        return hour.toString().padStart(2, '0') + ":00";
    }

    function getHourlyTempRange() {
        const data = filteredHourlyData.length > 0 ? filteredHourlyData : hourlyData;
        if (data.length === 0) return { min: 0, max: 100 };
        const temps = data.map(h => Weather.useUSCS ? parseInt(h.tempF) : parseInt(h.tempC));
        const min = Math.min(...temps);
        const max = Math.max(...temps);
        const padding = Math.max(2, (max - min) * 0.2);
        return { min: min - padding, max: max + padding };
    }

    contentItem: ColumnLayout {
        id: contentLayout
        anchors.centerIn: parent
        spacing: 8

        // Premium hero card with gradient background
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 130
            radius: Appearance.rounding.normal

            gradient: Gradient {
                GradientStop { position: 0.0; color: Appearance.colors.colPrimaryContainer }
                GradientStop { position: 1.0; color: Appearance.colors.colSurfaceContainerLow }
            }

            Item {
                anchors.fill: parent
                anchors.margins: 16

                // City name and description
                ColumnLayout {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.topMargin: -4
                    spacing: -2

                    StyledText {
                        text: Weather.data?.city || "--"
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer0
                    }

                    StyledText {
                        text: Weather.data?.wDesc || "--"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.6
                    }
                }

                // Large temperature
                RowLayout {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -6
                    spacing: 4

                    StyledText {
                        text: Weather.data?.temp || "--"
                        font.pixelSize: 48
                        font.weight: Font.Light
                        color: Appearance.colors.colOnLayer0
                    }
                }

                // Weather icon
                MaterialSymbol {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: -2
                    fill: 0
                    text: Icons.getWeatherIcon(Weather.data?.wCode) || "cloud"
                    iconSize: 40
                    color: Appearance.colors.colPrimary
                }

                // Sunrise/sunset
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
                            text: "wb_twilight"
                            iconSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: Weather.data?.sunrise || "--"
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colOnLayer0
                            opacity: 0.8
                        }
                    }

                    RowLayout {
                        spacing: 4
                        Layout.alignment: Qt.AlignRight
                        MaterialSymbol {
                            text: "bedtime"
                            iconSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: Weather.data?.sunset || "--"
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colOnLayer0
                            opacity: 0.8
                        }
                    }
                }
            }
        }

        // Quick stats row
        GridLayout {
            visible: !root.compact
            Layout.fillWidth: true
            columns: 3
            rowSpacing: 4
            columnSpacing: 4
            uniformCellWidths: true

            Layout.leftMargin: 2
            Layout.rightMargin: 2

            MetricCard {
                title: Translation.tr("Wind")
                symbol: "air"
                value: Weather.data?.wind || "--"
            }
            MetricCard {
                title: Translation.tr("Humidity")
                symbol: "humidity_low"
                value: Weather.data?.humidity || "--"
            }
            MetricCard {
                title: Translation.tr("UV Index")
                symbol: "wb_sunny"
                value: Weather.data?.uv?.toFixed(1) || "--"
            }
        }

        HourlyForecast {
            visible: !root.compact
            showDivider: false
            spacing: 6

            icon: "schedule"
            title: Translation.tr("Hourly")
            headerExtraText: Translation.tr("Last refresh: %1").arg(Weather.data?.lastRefresh || "--")

            shapeString: "Clover4Leaf"
            shapeColor: Appearance.colors.colSecondaryContainer
            symbolColor: Appearance.colors.colOnSecondaryContainer

            Layout.minimumWidth: 360
            margins: root.cardMargins
        }

        MetricsGrid {
            visible: !root.compact
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 8
            columnSpacing: 8
            uniformCellWidths: true
        }

        InDayForecast {
            visible: !root.compact
            Layout.minimumWidth: 360
            margins: root.cardMargins
            spacing: 8
            shapeString: "Cookie6Sided"
            shapeColor: Appearance.colors.colSecondaryContainer
            symbolColor: Appearance.colors.colOnSecondaryContainer
            showDivider: false
            title: Translation.tr("Forecast")
            icon: "calendar_month"
        }
    }
}
