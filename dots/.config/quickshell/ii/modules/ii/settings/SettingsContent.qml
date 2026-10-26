import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Qt5Compat.GraphicalEffects
import qs
import qs.services
import qs.modules.common
import qs.modules.ii.settings.pages
import qs.modules.common.widgets
import qs.modules.common.functions as CF

Item {
    id: root
    property real contentPadding: 8
    property int currentPage: 0
    property bool showingProfile: false
    property bool isMinimal: Config.options.settings.style === "minimal"
    // Page crossfade duration, scaled by the settings app's animation speed setting.
    readonly property int pageTransitionDuration: Math.max(60, Math.round(200 / Math.max(0.5, Config.options.settings.animationSpeed ?? 1)))

    function goToTarget(target) {
        const idx = root.pages.findIndex(p => p.id === target.page);
        if (idx < 0) return;
        root.currentPage = idx;
        root.showingProfile = false;
        if (!target.label) return;

        const loader = pagesRepeater.itemAt(idx);
        if (!loader) return;
        const run = () => loader.item?.goTo(target.label, target.section, target.subsection);
        if (loader.item) {
            run();
        } else {
            const onceLoaded = () => {
                loader.loaded.disconnect(onceLoaded);
                run();
            };
            loader.loaded.connect(onceLoaded);
        }
    }

    Connections {
        target: GlobalStates
        function onSettingsTargetChanged() {
            const target = GlobalStates.settingsTarget;
            if (!target) return;
            root.goToTarget(target);
            GlobalStates.settingsTarget = null;
        }
    }

    onCurrentPageChanged: {
        if (root.pages[currentPage]?.id === "about") {
            if (SystemInfo.cpu === "") SystemInfo.refresh()
            Updates.refresh()
        }
    }
    
    property var pages: SettingsPages.pages

    Component.onCompleted: {
        Config.readWriteDelay = 0
    }

    // Staggered background warm-up: keep window startup instant (pages load lazily
    // via the active binding), then preload the remaining pages one per tick so
    // switching pages stays instant.
    Timer {
        id: pagePreloadTimer
        interval: 200
        repeat: true
        running: true
        property int next: 0
        onTriggered: {
            if (next < root.pages.length) {
                next++
            } else if (profileLoader && !profileLoader.active) {
                profileLoader.active = true
                stop()
            } else {
                stop()
            }
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: contentPadding
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: contentPadding

            Rectangle {
                id: navRailWrapper
                Layout.fillHeight: true
                Layout.margins: 0
                implicitWidth: navRail.expanded ? 195 : fab.baseSize
                color: isMinimal ? "transparent" : Appearance.colors.colLayer1
                radius: Appearance.rounding.normal

                Behavior on implicitWidth {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                NavigationRail {
                    id: navRail
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 20 }
                    spacing: 10
                    expanded: root.width > 900

                    Item {
                        id: profileRowContainer
                        visible: true
                        Layout.fillWidth: false
                        Layout.margins: isMinimal ? 0 : 5
                        Layout.topMargin: 15
                        Layout.bottomMargin: isMinimal ? -30 : 0
                        implicitHeight: profileRow.implicitHeight
                        implicitWidth: profileRow.implicitWidth

                        RowLayout {
                            id: profileRow
                            anchors.fill: parent
                            spacing: 10

                            UserAvatar {
                                width: 48
                                height: 48
                            }

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true
                                visible: !isMinimal

                                StyledText {
                                    text: Config.options.profile.displayName === "" ? SystemInfo.username : Config.options.profile.displayName
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnLayer1
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 100
                                }

                                StyledText {
                                    id: distroText
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 100

                                    text: {
                                        const d = Config.options.profile.descriptionText
                                        if (d === "::uptime::") return Translation.tr("Up • %1").arg(DateTime.uptime)
                                        return SystemInfo.distroName
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showingProfile = !root.showingProfile
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: isMinimal ? 50 : 160
                        Layout.topMargin: isMinimal ? 30 : -5
                        Layout.bottomMargin: isMinimal ? -30 : 0
                        height: 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.2; color: Appearance.colors.colOutline }
                            GradientStop { position: 0.8; color: Appearance.colors.colOutline }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                        opacity: 0.15
                    }

                    FloatingActionButton {
                        id: fab
                        visible: !isMinimal
                        Layout.bottomMargin: -25
                        property bool justCopied: false
                        iconText: justCopied ? "check" : "edit"
                        buttonText: justCopied ? Translation.tr("Path copied") : Translation.tr("Config file")
                        expanded: navRail.expanded
                        downAction: () => {
                            Qt.openUrlExternally(`${Directories.config}/illogical-impulse/config.json`);
                        }
                        altAction: () => {
                            Quickshell.clipboardText = CF.FileUtils.trimFileProtocol(`${Directories.config}/illogical-impulse/config.json`);
                            fab.justCopied = true;
                            revertTextTimer.restart()
                        }
                        Timer {
                            id: revertTextTimer
                            interval: 1500
                            onTriggered: fab.justCopied = false
                        }
                        StyledToolTip {
                            text: Translation.tr("Open the shell config file\nAlternatively right-click to copy path")
                        }
                    }

                    NavigationRailTabArray {
                        currentIndex: root.currentPage
                        expanded: navRail.expanded
                        colToggled: root.showingProfile ? "transparent" : Appearance.colors.colSecondaryContainer
                        Repeater {
                            model: root.pages
                            NavigationRailButton {
                                required property var index
                                required property var modelData
                                toggled: root.currentPage === index && !root.showingProfile
                                onPressed: {
                                    root.currentPage = index
                                    root.showingProfile = false
                                }
                                expanded: navRail.expanded
                                buttonIcon: modelData.icon
                                buttonIconRotation: modelData.iconRotation || 0
                                buttonText: modelData.name
                                showToggledHighlight: false
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut

                Item {
                    anchors.fill: parent

                    Repeater {
                        id: pagesRepeater
                        model: root.pages
                        Loader {
                            id: pageLoader
                            required property var modelData
                            required property var index
                            source: modelData.component

                            // `item !== null` inside `active` made the Loader's activation depend on
                            // its own result (binding loop). A sticky flag keeps a page that has
                            // loaded once alive, which is what the item check was reaching for.
                            property bool everLoaded: false

                            active: Config.ready && (root.currentPage === index || everLoaded || pagePreloadTimer.next > index)

                            anchors.fill: parent

                            property bool isActive: root.currentPage === index && !root.showingProfile
                            opacity: isActive ? 1 : 0
                            enabled: isActive
                            visible: isActive
                            anchors.topMargin: isActive ? 0 : 12

                            onLoaded: {
                                everLoaded = true
                                if (root.currentPage === index) {
                                    GlobalStates.currentPageInstance = item;
                                }
                            }

                            onIsActiveChanged: {
                                if (isActive && item) {
                                    GlobalStates.currentPageInstance = item;
                                } else if (!isActive && GlobalStates.currentPageInstance === item) {
                                    GlobalStates.currentPageInstance = null;
                                }
                            }

                            Behavior on opacity {
                                NumberAnimation { duration: root.pageTransitionDuration; easing.type: Easing.OutCubic }
                            }
                            Behavior on anchors.topMargin {
                                NumberAnimation { duration: root.pageTransitionDuration; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    Loader {
                        id: profileLoader
                        active: false
                        anchors.fill: parent
                        source: Qt.resolvedUrl("pages/Profile.qml")

                        property bool isActive: root.showingProfile
                        opacity: isActive ? 1 : 0
                        enabled: isActive
                        visible: isActive
                        anchors.topMargin: isActive ? 0 : 12

                        onIsActiveChanged: {
                            if (isActive && item) {
                                GlobalStates.currentPageInstance = item;
                            } else if (!isActive && GlobalStates.currentPageInstance === item) {
                                GlobalStates.currentPageInstance = null;
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation { duration: root.pageTransitionDuration; easing.type: Easing.OutCubic }
                        }
                        Behavior on anchors.topMargin {
                            NumberAnimation { duration: root.pageTransitionDuration; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }
    }
}