pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: clockColumn
    spacing: 4

    readonly property bool colorful: Config.options.background.widgets.clock.digital.colorful
    readonly property bool showColon: Config.options.background.widgets.clock.digital.showColon

    property bool isVertical: Config.options.background.widgets.clock.digital.vertical

    // Qt's font.weight is ignored for these variable fonts; thickness must be
    // driven through the wght axis or the clock renders paper-thin
    readonly property var timeAxes: ({
            "wght": Config.options.background.widgets.clock.digital.font.weight,
            "wdth": Config.options.background.widgets.clock.digital.font.width,
            "ROND": Config.options.background.widgets.clock.digital.font.roundness
        })
    readonly property var dateAxes: ({
            "wght": 500,
            "wdth": Config.options.background.widgets.clock.digital.font.width,
            "ROND": Config.options.background.widgets.clock.digital.font.roundness
        })
    readonly property bool hasSeconds: DateTime.time.split(":").length > 2
    property color colText: Appearance.colors.colOnSecondaryContainer
    property color colTextSecondary: Appearance.colors.colOnLayer3
    property color colTextTertiary: Appearance.colors.colOnLayer3
    property var textHorizontalAlignment: Text.AlignHCenter

    // Digits in this rounded variable font are proportional (it has pnum, no tnum), so
    // "11:11" is narrower than "23:58". That changed the width of the time row every
    // second, which re-centred the whole column — and resized the card, whose width
    // follows the clock's — so the date underneath appeared to slide sideways. Every
    // numeric segment now claims the width of the widest digit instead of hugging its
    // glyphs, so only the characters change.
    ClockText {
        id: digitRuler
        visible: false
        animateChange: false
        font {
            family: Config.options.background.widgets.clock.digital.font.family
            weight: Config.options.background.widgets.clock.digital.font.weight
            variableAxes: clockColumn.timeAxes
        }
    }

    // Seeded from the font size (widest digit is ~0.67 of it in this family) so the very
    // first layout pass already reserves boxes; measureDigits() refines them from the
    // font itself at completion.
    property real timeDigitWidth: Config.options.background.widgets.clock.digital.font.size * 0.67
    property real secondsDigitWidth: Config.options.background.widgets.clock.digital.font.size * 0.27
    // The clock font is editable from the settings window while the widget is up
    readonly property var fontSignature: [
        Config.options.background.widgets.clock.digital.font.family,
        Config.options.background.widgets.clock.digital.font.size,
        Config.options.background.widgets.clock.digital.font.weight,
        Config.options.background.widgets.clock.digital.font.width,
        Config.options.background.widgets.clock.digital.font.roundness
    ]
    onFontSignatureChanged: remeasureTimer.start()

    Timer {
        id: remeasureTimer
        interval: 0
        repeat: false
        onTriggered: clockColumn.measureDigits()
    }

    function widestDigit() {
        let widest = 0;
        for (let digit = 0; digit <= 9; digit++) {
            digitRuler.text = String(digit);
            widest = Math.max(widest, digitRuler.contentWidth);
        }
        return widest;
    }

    function measureDigits() {
        const size = Config.options.background.widgets.clock.digital.font.size;
        digitRuler.font.pixelSize = size;
        clockColumn.timeDigitWidth = widestDigit();
        digitRuler.font.pixelSize = Math.round(size * 0.4);
        clockColumn.secondsDigitWidth = widestDigit();
    }

    Component.onCompleted: measureDigits()

    // Time
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: false
        ClockText {
            id: timeTextTop
            text: DateTime.time.split(":")[0].padStart(2, "0")
            Layout.preferredWidth: Math.round(clockColumn.timeDigitWidth * 2)
            color: clockColumn.colText
            horizontalAlignment: Text.AlignHCenter
            font {
                pixelSize: Config.options.background.widgets.clock.digital.font.size
                weight: Config.options.background.widgets.clock.digital.font.weight
                family: Config.options.background.widgets.clock.digital.font.family
                variableAxes: clockColumn.timeAxes
            }
        }
        Loader {
            active: !clockColumn.isVertical && showColon
            visible: active
            sourceComponent: ClockText {
                text: ":"
                color: colorful ? clockColumn.colTextSecondary : clockColumn.colText
                horizontalAlignment: clockColumn.textHorizontalAlignment
                font {
                    pixelSize: timeTextTop.font.pixelSize
                    weight: timeTextTop.font.weight
                    family: timeTextTop.font.family
                    variableAxes: timeTextTop.font.variableAxes
                }
            }
        }
        Loader {
            active: !clockColumn.isVertical
            visible: active
            Layout.preferredWidth: Math.round(clockColumn.timeDigitWidth * 2)
            sourceComponent: ClockText {
                text: DateTime.time.split(":")[1].split(" ")[0].padStart(2, "0")
                color: colorful ? clockColumn.colTextTertiary : clockColumn.colText
                horizontalAlignment: clockColumn.textHorizontalAlignment
                font {
                    pixelSize: timeTextTop.font.pixelSize
                    weight: timeTextTop.font.weight
                    family: timeTextTop.font.family
                    variableAxes: timeTextTop.font.variableAxes
                }
            }
        }
        Loader {
            active: !clockColumn.isVertical && clockColumn.hasSeconds
            visible: active
            // Superscript-style seconds with clear spacing, so they read as
            // seconds instead of a decimal glued to the minutes
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: Math.round(timeTextTop.font.pixelSize * 0.1)
            Layout.leftMargin: Math.round(timeTextTop.font.pixelSize * 0.1)
            Layout.preferredWidth: Math.round(clockColumn.secondsDigitWidth * 2)
            sourceComponent: ClockText {
                text: DateTime.time.split(":")[2].split(" ")[0].padStart(2, "0")
                color: colorful ? clockColumn.colTextTertiary : clockColumn.colText
                opacity: 0.8
                animateChange: false
                horizontalAlignment: clockColumn.textHorizontalAlignment
                font {
                    pixelSize: Math.round(timeTextTop.font.pixelSize * 0.4)
                    weight: timeTextTop.font.weight
                    family: timeTextTop.font.family
                    variableAxes: timeTextTop.font.variableAxes
                }
            }
        }
    }
    

    Loader {
        Layout.topMargin: -40
        Layout.fillWidth: true
        Layout.preferredWidth: Math.round(clockColumn.timeDigitWidth * 2)
        active: clockColumn.isVertical
        visible: active
        sourceComponent: ClockText {
            id: timeTextBottom
            text: DateTime.time.split(":")[1].split(" ")[0].padStart(2, "0")
            color: colorful ? clockColumn.colTextTertiary : clockColumn.colText
            horizontalAlignment: clockColumn.textHorizontalAlignment
            font {
                pixelSize: timeTextTop.font.pixelSize
                weight: timeTextTop.font.weight
                family: timeTextTop.font.family
                variableAxes: timeTextTop.font.variableAxes
            }
        }
    }

    Loader {
        Layout.topMargin: -34
        Layout.fillWidth: true
        Layout.preferredWidth: Math.round(clockColumn.secondsDigitWidth * 2)
        active: clockColumn.isVertical && clockColumn.hasSeconds
        visible: active
        sourceComponent: ClockText {
            text: DateTime.time.split(":")[2].split(" ")[0].padStart(2, "0")
            color: colorful ? clockColumn.colTextTertiary : clockColumn.colText
            opacity: 0.6
            animateChange: false
            horizontalAlignment: clockColumn.textHorizontalAlignment
            font {
                pixelSize: Math.round(timeTextTop.font.pixelSize * 0.4)
                weight: timeTextTop.font.weight
                family: timeTextTop.font.family
                variableAxes: timeTextTop.font.variableAxes
            }
        }
    }

    // Date
    ClockText {
        visible: Config.options.background.widgets.clock.digital.showDate
        Layout.topMargin: -20
        Layout.fillWidth: true
        font.family: timeTextTop.font.family
        font.weight: 500
        font.variableAxes: clockColumn.dateAxes
        // The widget is horizontal and wide, so it can spell the weekday out
        text: DateTime.longWeekdayDate
        color: colorful ? clockColumn.colTextSecondary : clockColumn.colText
        horizontalAlignment: clockColumn.textHorizontalAlignment
    }

    // Quote
    ClockText {
        visible: Config.options.background.widgets.clock.quote.enable && Config.options.background.widgets.clock.quote.text.length > 0
        font.pixelSize: Appearance.font.pixelSize.normal
        text: Config.options.background.widgets.clock.quote.text
        animateChange: false
        color: clockColumn.colTextSecondary
        horizontalAlignment: clockColumn.textHorizontalAlignment
    }
}
