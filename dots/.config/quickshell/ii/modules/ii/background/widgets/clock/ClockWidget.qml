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

    configEntryName: "clock"

    // Fixed 2x2 grid slot; contentColumn centers itself inside
    implicitHeight: WidgetGrid.spanHeight(2)
    implicitWidth: WidgetGrid.spanWidth(2)

    readonly property string clockStyle: GlobalStates.screenLocked ? Config.options.background.widgets.clock.styleLocked : Config.options.background.widgets.clock.style
    readonly property bool forceCenter: (GlobalStates.screenLocked && Config.options.lock.centerClock)
    readonly property bool shouldShow: (!Config.options.background.widgets.clock.showOnlyWhenLocked || GlobalStates.screenLocked)
    // Locked, the wallpaper sits under a blurred, darkened scrim, so the wallpaper-adaptive
    // on-container tones stop describing what is behind the text: derive the supporting
    // colours from the scrim's own on-colour instead.
    readonly property bool onLockScrim: GlobalStates.screenLocked && Config.options.lock.blur.enable
    readonly property color colTextSecondary: onLockScrim
        ? ColorUtils.transparentize(Appearance.m3colors.m3onBackground, 0.25)
        : Appearance.colors.colOnLayer3
    readonly property color colTextTertiary: onLockScrim
        ? ColorUtils.transparentize(Appearance.m3colors.m3onBackground, 0.45)
        : Appearance.colors.colOnLayer3
    readonly property string customClockColorKey: Config.options.background.widgets.clock.color ?? ""
    readonly property color resolvedClockColor: {
        if (customClockColorKey === "") return root.colText;
        const propName = "col" + customClockColorKey.charAt(0).toUpperCase() + customClockColorKey.slice(1);
        return Appearance.colors[propName] ?? root.colText;
    }
    property bool wallpaperSafetyTriggered: false
    property bool isCovered: false
    needsColText: clockStyle === "digital" || clockStyle === "daily"
    x: forceCenter ? ((root.screenWidth - root.width) / 2) : targetX
    y: forceCenter ? ((root.screenHeight - root.height) / 2) : targetY
    visibleWhenLocked: true

    property var textHorizontalAlignment: {
        if (!Config.options.background.widgets.clock.digital.adaptiveAlignment || root.forceCenter || Config.options.background.widgets.clock.digital.vertical) 
            return Text.AlignHCenter;
        if (root.x < root.scaledScreenWidth / 3)
            return Text.AlignLeft;
        if (root.x > root.scaledScreenWidth * 2 / 3)
            return Text.AlignRight;
        return Text.AlignHCenter;
    }

    Column {
        id: contentColumn
        anchors.centerIn: parent
        spacing: 10

        FadeLoader {
            id: cookieClockLoader
            anchors.horizontalCenter: parent.horizontalCenter
            shown: root.clockStyle === "cookie" && (root.shouldShow)
            fade: false
            sourceComponent: Column {
                spacing: 10
                CookieClock {
                    anchors.horizontalCenter: parent.horizontalCenter
                    isCovered: root.isCovered
                }
                FadeLoader {
                    anchors.horizontalCenter: parent.horizontalCenter
                    shown: Config.options.background.widgets.clock.quote.enable && Config.options.background.widgets.clock.quote.text !== ""
                    sourceComponent: CookieQuote {}
                }
            }
        }

        FadeLoader {
            id: digitalClockLoader
            anchors.horizontalCenter: parent.horizontalCenter
            shown: root.clockStyle === "digital" && (root.shouldShow)
            fade: false
            sourceComponent: DigitalClock {
                colText: root.resolvedClockColor
                colTextSecondary: root.colTextSecondary
                colTextTertiary: root.colTextTertiary
                textHorizontalAlignment: root.textHorizontalAlignment
            }
        }

        FadeLoader {
            id: dailyClockLoader
            anchors.horizontalCenter: parent.horizontalCenter
            shown: root.clockStyle === "daily" && (root.shouldShow)
            fade: false
            sourceComponent: DailyClock {
                colText: root.resolvedClockColor
            }
        }

        FadeLoader {
            id: pixelClockLoader
            anchors.horizontalCenter: parent.horizontalCenter
            shown: root.clockStyle === "pixel" && (root.shouldShow)
            fade: false
            sourceComponent: PixelClock {
                wallpaperItem: root.wallpaperItem
                originX: root.x
                originY: root.y
            }
        }
        StatusRow {
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    component StatusRow: Item {
        id: statusText
        implicitHeight: statusTextBg.implicitHeight
        implicitWidth: statusTextBg.implicitWidth
        StyledRectangularShadow {
            target: statusTextBg
            visible: statusTextBg.visible && root.clockStyle === "cookie"
            opacity: statusTextBg.opacity
        }
        Rectangle {
            id: statusTextBg
            anchors.centerIn: parent
            clip: true
            opacity: (safetyStatusText.shown || lockStatusText.shown) ? 1 : 0
            visible: opacity > 0
            implicitHeight: statusTextRow.implicitHeight + 5 * 2
            implicitWidth: statusTextRow.implicitWidth + 5 * 2
            radius: Appearance.rounding.small
            color: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, root.clockStyle === "cookie" ? 0 : 1)

            Behavior on implicitWidth {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
            }
            Behavior on implicitHeight {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
            }
            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

            RowLayout {
                id: statusTextRow
                anchors.centerIn: parent
                spacing: 14
                Item {
                    Layout.fillWidth: root.textHorizontalAlignment !== Text.AlignLeft
                    implicitWidth: 1
                }
                ClockStatusText {
                    id: safetyStatusText
                    shown: root.wallpaperSafetyTriggered
                    statusIcon: "hide_image"
                    statusText: Translation.tr("Wallpaper safety enforced")
                }
                ClockStatusText {
                    id: lockStatusText
                    shown: GlobalStates.screenLocked && Config.options.lock.showLockedText
                    statusIcon: "lock"
                    statusText: Translation.tr("Locked")
                }
                Item {
                    Layout.fillWidth: root.textHorizontalAlignment !== Text.AlignRight
                    implicitWidth: 1
                }
            }
        }
    }

    component ClockStatusText: Row {
        id: statusTextRow
        property alias statusIcon: statusIconWidget.text
        property alias statusText: statusTextWidget.text
        property bool shown: true
        property color textColor: root.clockStyle === "cookie" ? Appearance.colors.colOnSecondaryContainer : root.resolvedClockColor
        opacity: shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        spacing: 4
        MaterialSymbol {
            id: statusIconWidget
            anchors.verticalCenter: statusTextRow.verticalCenter
            iconSize: Appearance.font.pixelSize.huge
            color: statusTextRow.textColor
            style: Text.Raised
            styleColor: Appearance.colors.colShadow
        }
        ClockText {
            id: statusTextWidget
            color: statusTextRow.textColor
            horizontalAlignment: root.textHorizontalAlignment
            anchors.verticalCenter: statusTextRow.verticalCenter
            font {
                pixelSize: Appearance.font.pixelSize.large
                weight: Font.Normal
            }
            style: Text.Raised
            styleColor: Appearance.colors.colShadow
        }
    }
}
