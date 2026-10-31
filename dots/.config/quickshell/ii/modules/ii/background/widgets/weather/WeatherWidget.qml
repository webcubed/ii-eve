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
    configEntryName: "weather"
    hoverEnabled: true

    // Sizes come straight from the shared design grid (WidgetGrid), so the card lines up with
    // the resources/notes/timers cards instead of carrying its own 132/12 copy of the pitch.
    readonly property real cardSpacing: WidgetGrid.gutter
    readonly property real cardHeight: root.sizeMode === "1x1" ? root.spanHeight(1) : root.spanHeight(2)

    readonly property real snapWidth1: root.spanWidth(1)
    readonly property real snapWidth2: root.spanWidth(2)
    readonly property real snapWidth3: root.spanWidth(3)

    property string sizeMode: root.configEntry.sizeMode ?? "2x2"

    // Sun row: the two providers report sunrise/sunset as wall clocks ("07:18" or
    // "7:18 AM"), so normalize to minutes of the day. The chart draws the whole
    // midnight-to-midnight span, so it takes the times themselves rather than a 0-1
    // progress figure — sunrise and sunset are where the curve crosses its horizon.
    function minutesOfDay(text) {
        if (!text) return -1;
        const match = String(text).trim().match(/^(\d{1,2}):(\d{2})\s*(AM|PM)?$/i);
        if (!match) return -1;
        let hour = Number(match[1]);
        const minute = Number(match[2]);
        const suffix = (match[3] ?? "").toUpperCase();
        if (suffix === "PM" && hour < 12) hour += 12;
        if (suffix === "AM" && hour === 12) hour = 0;
        if (hour > 23 || minute > 59) return -1;
        return hour * 60 + minute;
    }
    readonly property int sunriseMinutes: root.minutesOfDay(Weather.data?.sunrise)
    readonly property int sunsetMinutes: root.minutesOfDay(Weather.data?.sunset)
    readonly property int nowMinutes: DateTime.hour24 * 60 + Number(DateTime.minuteStr)
    // "Now" on the location's clock. The weather payload carries its UTC offset, so
    // the marker stays right even when the machine sits in another timezone (and
    // the providers report sunrise/sunset on the location's clock). wttr.in has no
    // offset, so there the machine clock is the best available reading.
    readonly property real sunNowMinutes: {
        const tick = root.nowMinutes; // re-evaluates once a minute
        const offset = Weather.data?.utcOffsetSeconds;
        if (offset === undefined || offset === null) return tick;
        return ((Date.now() / 1000 + Number(offset)) / 60) % 1440;
    }

    property real widgetWidth: {
        switch (root.sizeMode) {
            case "1x1": return root.snapWidth1
            case "1x2": return root.snapWidth2
            case "2x2": return root.snapWidth2
            default:    return root.snapWidth3
        }
    }
    readonly property bool isCompact: root.sizeMode !== "1x3"

    function modeForWidth(value) {
        var mid1 = (root.snapWidth1 + root.snapWidth2) / 2
        var mid2 = (root.snapWidth2 + root.snapWidth3) / 2
        if (value < mid1) return "1x1"
        if (value < mid2) return "2x2"
        return "1x3"
    }

    implicitHeight: card.implicitHeight
    implicitWidth: card.implicitWidth

    Behavior on widgetWidth {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    Rectangle {
        id: card
        implicitWidth: root.widgetWidth
        implicitHeight: root.cardHeight
        radius: Appearance.rounding?.verylarge ?? 30
        color: Appearance.colors.colPrimaryContainer

        StyledRectangularShadow {
            target: card
            z: -2
        }

        Loader {
            anchors.fill: parent
            sourceComponent: {
                if (root.sizeMode === "2x2") return twoByTwoContent
                if (root.sizeMode === "1x1") return oneByOneContent
                if (root.sizeMode === "1x2") return oneByTwoContent
                return oneByThreeContent
            }
        }

        // 1x1 
        Component {
            id: oneByOneContent
            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 14
                }
                spacing: -4

                MaterialShapeWrappedMaterialSymbol {
                    Layout.alignment: Qt.AlignRight
                    shape: MaterialShape.Shape.Cookie12Sided
                    color: Appearance.colors.colPrimary
                    colSymbol: Appearance.colors.colOnPrimary
                    text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                    iconSize: 18
                    fill: 1
                    padding: 6
                    implicitWidth: 34
                    implicitHeight: 34
                }

                Item { Layout.fillHeight: true }

                StyledText {
                    text: Weather.data?.temp ?? "--°"
                    font.pixelSize: Appearance.font.pixelSize.hugeass
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnPrimaryContainer
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Weather.data?.city ?? "--"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnPrimaryContainer
                    opacity: 0.6
                    elide: Text.ElideRight
                }
            }
        }

        // 2x2
        Component {
            id: twoByTwoContent
            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 16
                }
                // Zero spacing: the gaps below are explicit, so the sun strip can
                // claim its full height instead of losing it to invisible spacing around
                // the filler item.
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        spacing: 0
                        StyledText {
                            text: Weather.data?.temp ?? "--°"
                            font.pixelSize: 46
                            font.weight: Font.Bold
                            color: Appearance.colors.colPrimary
                        }
                        // No condition line at this size: it spent a whole line of the
                        // card under the temperature, and that height buys more in the
                        // readings and the sun strip below. (It also never had text —
                        // see the wDesc note on the compact layouts.)
                        StyledText {
                            text: Weather.data?.city ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                            elide: Text.ElideRight
                        }
                    }

                    Item { Layout.fillWidth: true }

                    MaterialShapeWrappedMaterialSymbol {
                        Layout.topMargin: 2
                        shape: MaterialShape.Shape.Cookie12Sided
                        color: Appearance.colors.colPrimary
                        colSymbol: Appearance.colors.colOnPrimary
                        text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                        iconSize: 24
                        fill: 1
                        padding: 12
                        implicitWidth: 56
                        implicitHeight: 56
                    }
                }

                Item { Layout.fillHeight: true }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 12

                    ColumnLayout {
                        spacing: 0
                        RowLayout {
                            spacing: 6
                            MaterialSymbol { iconSize: 16; text: "humidity_mid"; color: Appearance.colors.colOnPrimaryContainer; opacity: 0.6 }
                            StyledText { text: Weather.data?.humidity ?? "--"; font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.DemiBold; color: Appearance.colors.colOnPrimaryContainer; opacity: 0.85 }
                        }
                        StyledText { Layout.topMargin: 1; text: "Humidity"; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnPrimaryContainer; opacity: 0.55 }
                    }
                    ColumnLayout {
                        spacing: 0
                        RowLayout {
                            spacing: 6
                            MaterialSymbol { iconSize: 16; text: "rainy"; color: Appearance.colors.colOnPrimaryContainer; opacity: 0.6 }
                            StyledText { text: Weather.data?.cr ?? "--"; font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.DemiBold; color: Appearance.colors.colOnPrimaryContainer; opacity: 0.85 }
                        }
                        StyledText { Layout.topMargin: 1; text: "Rain"; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnPrimaryContainer; opacity: 0.55 }
                    }
                    ColumnLayout {
                        spacing: 0
                        RowLayout {
                            spacing: 6
                            MaterialSymbol { iconSize: 16; text: "air"; color: Appearance.colors.colOnPrimaryContainer; opacity: 0.6 }
                            StyledText { text: Weather.data?.wind ?? "--"; font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.DemiBold; color: Appearance.colors.colOnPrimaryContainer; opacity: 0.85 }
                        }
                        StyledText { Layout.topMargin: 1; text: "Wind"; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnPrimaryContainer; opacity: 0.55 }
                    }
                    ColumnLayout {
                        spacing: 0
                        RowLayout {
                            spacing: 6
                            MaterialSymbol { iconSize: 16; text: "visibility"; color: Appearance.colors.colOnPrimaryContainer; opacity: 0.6 }
                            StyledText { text: Weather.data?.visib ?? "--"; font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.DemiBold; color: Appearance.colors.colOnPrimaryContainer; opacity: 0.85 }
                        }
                        StyledText { Layout.topMargin: 1; text: "Visibility"; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnPrimaryContainer; opacity: 0.55 }
                    }
                }

                // The day chart runs the full width with the rise/set times as a
                // legend beneath it. Its x axis is the whole day, so the marker sits on
                // the real timeline; the labels no longer double as the ends of the arc
                // (flanking them squeezed the arc into 98px of a 240px card).
                SunArc {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    Layout.topMargin: 8
                    sunriseMinutes: root.sunriseMinutes
                    sunsetMinutes: root.sunsetMinutes
                    nowMinutes: root.sunNowMinutes
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 2
                    MaterialSymbol {
                        iconSize: Appearance.font.pixelSize.smaller
                        text: "wb_twilight"
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.6
                    }
                    StyledText {
                        text: Weather.data?.sunrise ?? "--"
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.6
                    }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        text: Weather.data?.sunset ?? "--"
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.6
                    }
                    MaterialSymbol {
                        iconSize: Appearance.font.pixelSize.smaller
                        text: "nights_stay"
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.6
                    }
                }
            }
        }

        // 1x2
        Component {
            id: oneByTwoContent
            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 14
                }
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ColumnLayout {
                        spacing: -4
                        StyledText {
                            text: Weather.data?.temp ?? "--°"
                            font.pixelSize: Appearance.font.pixelSize.hugeass
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        StyledText {
                            text: Weather.data?.city ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                            elide: Text.ElideRight
                        }
                        StyledText {
                            // The condition lives in the service's wDesc: the old
                            // `description` key never resolved, so this line could only
                            // ever draw its "--" placeholder.
                            visible: text !== ""
                            text: Weather.data?.wDesc ?? ""
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                            elide: Text.ElideRight
                        }
                    }

                    Item { Layout.fillWidth: true }

                    MaterialShapeWrappedMaterialSymbol {
                        Layout.topMargin: -19
                        shape: MaterialShape.Shape.Cookie12Sided
                        color: Appearance.colors.colPrimary
                        colSymbol: Appearance.colors.colOnPrimary
                        text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                        iconSize: 18
                        fill: 1
                        padding: 6
                        implicitWidth: 42
                        implicitHeight: 42
                    }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 2
                    spacing: 12

                    RowLayout {
                        spacing: 2
                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.smaller
                            text: "humidity_mid"
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                        StyledText {
                            text: Weather.data?.humidity ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                    }

                    RowLayout {
                        spacing: 2
                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.smaller
                            text: "rainy"
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                        StyledText {
                            text: Weather.data?.cr ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                    }

                    RowLayout {
                        spacing: 2
                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.smaller
                            text: "air"
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                        StyledText {
                            text: Weather.data?.wind ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                    }
                }

                // The narrow card gets the same day chart, with the times as its
                // legend since there is no room to flank it.
                SunArc {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    Layout.topMargin: 4
                    sunriseMinutes: root.sunriseMinutes
                    sunsetMinutes: root.sunsetMinutes
                    nowMinutes: root.sunNowMinutes
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    MaterialSymbol {
                        iconSize: Appearance.font.pixelSize.smaller
                        text: "wb_twilight"
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.6
                    }
                    StyledText {
                        text: Weather.data?.sunrise ?? "--"
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.6
                    }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        text: Weather.data?.sunset ?? "--"
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.6
                    }
                    MaterialSymbol {
                        iconSize: Appearance.font.pixelSize.smaller
                        text: "nights_stay"
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.6
                    }
                }
            }
        }

        // 1x3
        Component {
            id: oneByThreeContent
            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 14
                }
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    StyledText {
                        Layout.alignment: Qt.AlignTop
                        text: Weather.data?.temp ?? "--°"
                        font {
                            pixelSize: 40
                            weight: Font.Bold
                        }
                        color: Appearance.colors.colPrimary
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        StyledText {
                            // Condition text under the provider's real key (see the
                            // compact layouts), and nothing at all when it is missing.
                            visible: text !== ""
                            text: Weather.data?.wDesc ?? ""
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnPrimaryContainer
                            elide: Text.ElideRight
                        }
                        StyledText {
                            text: Weather.data?.city ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                            elide: Text.ElideRight
                        }
                    }

                    Item { Layout.fillWidth: true }

                    MaterialShapeWrappedMaterialSymbol {
                        Layout.topMargin: -5
                        Layout.alignment: Qt.AlignVCenter
                        shape: MaterialShape.Shape.Cookie12Sided
                        color: Appearance.colors.colPrimary
                        colSymbol: Appearance.colors.colOnPrimary
                        text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                        iconSize: 24
                        fill: 1
                        padding: 10
                        implicitWidth: 50
                        implicitHeight: 50
                    }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 5
                    spacing: 16

                    RowLayout {
                        spacing: 2
                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.smaller
                            text: "humidity_mid"
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                        StyledText {
                            text: Weather.data?.humidity ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                    }

                    RowLayout {
                        spacing: 2
                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.smaller
                            text: "rainy"
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                        StyledText {
                            text: Weather.data?.cr ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                    }

                    RowLayout {
                        spacing: 2
                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.smaller
                            text: "air"
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                        StyledText {
                            text: Weather.data?.wind ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                    }

                    RowLayout {
                        spacing: 2
                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.smaller
                            text: "visibility"
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                        StyledText {
                            text: Weather.data?.visib ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                // The wide card has room to flank the day chart with its rise/set
                // legend; the chart itself still spans midnight to midnight.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 8

                    RowLayout {
                        Layout.alignment: Qt.AlignBottom
                        spacing: 4
                        MaterialSymbol {
                            iconSize: 14
                            text: "wb_twilight"
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                        StyledText {
                            text: Weather.data?.sunrise ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                    }

                    SunArc {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        Layout.alignment: Qt.AlignBottom
                        sunriseMinutes: root.sunriseMinutes
                        sunsetMinutes: root.sunsetMinutes
                        nowMinutes: root.sunNowMinutes
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignBottom
                        spacing: 4
                        StyledText {
                            text: Weather.data?.sunset ?? "--"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                        MaterialSymbol {
                            iconSize: 14
                            text: "nights_stay"
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                    }
                }
            }
        }

        Rectangle {
            id: resizeHandle
            width: 16
            height: 16
            radius: 4
            color: Appearance.colors.colOnPrimaryContainer
            anchors {
                right: card.right
                bottom: card.bottom
                margins: 4
            }
            opacity: (root.containsMouse || resizeArea.containsMouse || resizeArea.pressed) ? 0.5 : 0
            visible: opacity > 0 && !Config.options.background.widgetsLocked

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }

            MouseArea {
                id: resizeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor
                preventStealing: true

                property real startWidth: 0
                property real startX: 0

                onPressed: (mouse) => {
                    startWidth = root.widgetWidth
                    startX = mapToItem(null, mouse.x, mouse.y).x
                }
                onPositionChanged: (mouse) => {
                    if (!pressed) return
                    var globalX = mapToItem(null, mouse.x, mouse.y).x
                    var dx = globalX - startX
                    root.sizeMode = root.modeForWidth(startWidth + dx)
                }
                onReleased: {
                    root.configEntry.sizeMode = root.sizeMode
                }
            }
        }
    }
}
