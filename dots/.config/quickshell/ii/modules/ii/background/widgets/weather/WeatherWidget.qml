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

    // Sun arc: the two providers report sunrise/sunset as wall clocks ("07:18" or
    // "7:18 AM"), so normalize to minutes of the day and derive how far the sun is
    // between them. Progress clamps outside the window; `sunAboveHorizon` lets the
    // marker dim instead of pretending the sun is up at 3am.
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
    readonly property real sunProgress: {
        if (root.sunriseMinutes < 0 || root.sunsetMinutes < 0 || root.sunsetMinutes <= root.sunriseMinutes)
            return 0;
        const fraction = (root.nowMinutes - root.sunriseMinutes) / (root.sunsetMinutes - root.sunriseMinutes);
        return Math.max(0, Math.min(1, fraction));
    }
    readonly property bool sunAboveHorizon: root.sunriseMinutes >= 0
        && root.sunsetMinutes > root.sunriseMinutes
        && root.nowMinutes >= root.sunriseMinutes
        && root.nowMinutes <= root.sunsetMinutes

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
                        StyledText {
                            Layout.topMargin: 2
                            text: Weather.data?.description ?? "--"
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

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    spacing: 6

                    RowLayout {
                        Layout.alignment: Qt.AlignBottom
                        spacing: 4
                        MaterialSymbol { iconSize: 14; text: "wb_twilight"; color: Appearance.colors.colOnPrimaryContainer; opacity: 0.6 }
                        StyledText { text: Weather.data?.sunrise ?? "--"; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnPrimaryContainer; opacity: 0.6 }
                    }

                    SunArc {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        Layout.alignment: Qt.AlignBottom
                        progress: root.sunProgress
                        aboveHorizon: root.sunAboveHorizon
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignBottom
                        spacing: 4
                        StyledText { text: Weather.data?.sunset ?? "--"; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnPrimaryContainer; opacity: 0.6 }
                        MaterialSymbol { iconSize: 14; text: "nights_stay"; color: Appearance.colors.colOnPrimaryContainer; opacity: 0.6 }
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
                            text: Weather.data?.description ?? "--"
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

                // The narrow card still gets the sun's hill, with the times tucked
                // under its ends since there is no room to flank it.
                SunArc {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    Layout.topMargin: 4
                    progress: root.sunProgress
                    aboveHorizon: root.sunAboveHorizon
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
                            text: Weather.data?.description ?? ""
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

                // The wide card has room for the sun's hill to run the full width,
                // with sunrise and sunset sitting at the two ends of the horizon.
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
                        progress: root.sunProgress
                        aboveHorizon: root.sunAboveHorizon
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
