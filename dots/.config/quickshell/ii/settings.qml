//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// Adjust this to make the app smaller or larger
//@ pragma Env QT_SCALE_FACTOR=1

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF
import qs.modules.settings

ApplicationWindow {
    id: root
    property string firstRunFilePath: CF.FileUtils.trimFileProtocol(`${Directories.state}/user/first_run.txt`)
    property string firstRunFileContent: "This file is just here to confirm you've been greeted :>"
    property real contentPadding: 8
    property bool showNextTime: false

    property int currentPage: 0
    property real scrollPos: 0
    property string lastSearch: ""
    property int lastSearchIndex: -1
    property int resultsCount: 0

    property bool showingProfile: false
    readonly property string activePageSource: root.showingProfile ? "modules/settings/pages/Profile.qml" : (root.pages[root.currentPage] ? root.pages[root.currentPage].component : "")

    property var pages: [
        {
            name: Translation.tr("Quick"),
            icon: "instant_mix",
            component: "modules/settings/QuickConfig.qml"
        },
        {
            name: Translation.tr("General"),
            icon: "browse",
            component: "modules/settings/GeneralConfig.qml"
        },
        {
            name: Translation.tr("Bar"),
            icon: "toast",
            iconRotation: 180,
            component: "modules/settings/BarConfig.qml"
        },
        {
            name: Translation.tr("Background"),
            icon: "texture",
            component: "modules/settings/BackgroundConfig.qml"
        },
        {
            name: Translation.tr("Interface"),
            icon: "bottom_app_bar",
            component: "modules/settings/InterfaceConfig.qml"
        },
        {
            name: Translation.tr("Services"),
            icon: "api",
            component: "modules/settings/ServicesConfig.qml"
        },
        {
            name: Translation.tr("Hyprland"),
            icon: "monitor",
            component: "modules/settings/HyprlandConfig.qml"
        },
        {
            name: Translation.tr("Extensions"),
            icon: "extension",
            component: "modules/settings/ExtensionsConfig.qml"
        },
        {
            name: Translation.tr("Find My"),
            icon: "location_on",
            component: "modules/settings/FindMyConfig.qml"
        },
        {
            name: Translation.tr("Advanced"),
            icon: "construction",
            component: "modules/settings/AdvancedConfig.qml"
        }
    ]
    

    visible: true
    onClosing: Qt.quit()
    title: "illogical-impulse Settings"
    
    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme()
        Config.readWriteDelay = 0 // Settings app always only sets one var at a time so delay isn't needed
        ExtensionManager.watchFileChanges = false // Settings app doesn't need file watching to prevent loops
    }

    function goToPage(index) {
        root.currentPage = index
        root.showingProfile = false
    }

    minimumWidth: 750
    minimumHeight: 500
    width: 1100
    height: 750
    color: Appearance.m3colors.m3background

    ColumnLayout {
        anchors {
            fill: parent
            margins: contentPadding
        }

        Keys.onPressed: (event) => {
            if (event.modifiers === Qt.ControlModifier) {
                if (event.key === Qt.Key_PageDown) {
                    root.goToPage(Math.min(root.currentPage + 1, root.pages.length - 1))
                    event.accepted = true;
                } 
                else if (event.key === Qt.Key_PageUp) {
                    root.goToPage(Math.max(root.currentPage - 1, 0))
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Tab) {
                    root.goToPage((root.currentPage + 1) % root.pages.length);
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Backtab) {
                    root.goToPage((root.currentPage - 1 + root.pages.length) % root.pages.length);
                    event.accepted = true;
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignCenter
            Layout.fillWidth: true
            Layout.fillHeight: false
            spacing: 12

            MaterialShape {
                implicitWidth: 36
                implicitHeight: 36
                shape: MaterialShape.Shape.Superellipse
                color: Appearance.colors.colPrimaryContainer

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "tune"
                    iconSize: 20
                    color: Appearance.colors.colOnPrimaryContainer
                }
            }

            ColumnLayout {
                spacing: 0
                StyledText {
                    id: titleText
                    color: Appearance.colors.colOnLayer0
                    text: Translation.tr("illogical-impulse")
                    font {
                        family: Appearance.font.family.title
                        pixelSize: Appearance.font.pixelSize.larger
                        weight: Font.Bold
                    }
                }
                StyledText {
                    color: Appearance.colors.colSubtext
                    text: Translation.tr("System & Desktop Settings")
                    font {
                        pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }

            Item { Layout.fillWidth: true }

            RowLayout {
                id: searchBox

                SequentialAnimation {
                    id: noMoreResultsAnim
                    NumberAnimation { target: searchBox; property: "Layout.leftMargin"; to: -30; duration: 50 }
                    NumberAnimation { target: searchBox; property: "Layout.leftMargin"; to: 30; duration: 50 }
                    NumberAnimation { target: searchBox; property: "Layout.leftMargin"; to: -15; duration: 40 }
                    NumberAnimation { target: searchBox; property: "Layout.leftMargin"; to: 15; duration: 40 }
                    NumberAnimation { target: searchBox; property: "Layout.leftMargin"; to: 0; duration: 30 }
                }

                MaterialShapeWrappedMaterialSymbol {
                    iconSize: Appearance.font.pixelSize.huge
                    shape: MaterialShape.Shape.Ghostish
                    text: resultText.show ? "" : "search" 
                    animateChange: true

                    StyledText {
                        id: resultText

                        readonly property bool show: root.lastSearchIndex !== -1 && root.resultsCount > 0

                        visible: false
                        animateChange: true
                        anchors.centerIn: parent
                        text: (root.lastSearchIndex % root.resultsCount + 1) + "/" + root.resultsCount

                        onShowChanged: if (!show) resultText.visible = false
                        Timer {
                            id: showTimer
                            interval: 100
                            running: resultText.show
                            repeat: false
                            onTriggered: resultText.visible = true
                        }
                    }
                }

                ToolbarTextField { // Search box
                    id: searchInput
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    font.pixelSize: Appearance.font.pixelSize.small
                    placeholderText: Translation.tr("Search all settings..")
                    implicitWidth: Appearance.sizes.searchWidth

                    Component.onCompleted: {
                        searchInput.forceActiveFocus()
                    }

                    onTextChanged: {
                        root.lastSearchIndex = -1
                        root.resultsCount = 0
                    }

                    onAccepted: {
                        const result = SearchRegistry.getResultsRanked(searchInput.text)

                        if (result == null) {
                            noMoreResultsAnim.restart();
                            return
                        }

                        let length = SearchRegistry.getResultsRanked(searchInput.text).length

                        if (length == 0) {
                            noMoreResultsAnim.restart();
                            return
                        }
                        
                        if (root.lastSearch != searchInput.text) {
                            root.lastSearchIndex = 0
                            root.lastSearch = searchInput.text
                        } else {
                            root.lastSearchIndex++
                            if (SearchRegistry.getResultsRanked(searchInput.text).length === 1) {
                                noMoreResultsAnim.restart()
                            }
                        }

                        let normalizedText = searchInput.text.toLowerCase()
                        let results = SearchRegistry.getResultsRanked(normalizedText)
                        if (results.length > 0) {
                            let index = root.lastSearchIndex % results.length
                            let res = results[index]
                            
                            root.resultsCount = results.length
                            root.goToPage(res.pageIndex)
                            SearchRegistry.currentSearch = res.matchedString
                        }
                    }
                }

                RippleButton {
                    visible: searchInput.text.length > 0
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 28
                    implicitHeight: 28
                    onClicked: {
                        searchInput.text = ""
                        root.lastSearchIndex = -1
                        root.resultsCount = 0
                        SearchRegistry.currentSearch = ""
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: 16
                        color: Appearance.colors.colSubtext
                    }
                }
            }

            RippleButton {
                buttonRadius: Appearance.rounding.full
                implicitWidth: 35
                implicitHeight: 35
                onClicked: root.close()
                Layout.rightMargin: 10
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: "close"
                    iconSize: 20
                }
            }
        }

        RowLayout { // Window content with navigation rail and content pane
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: contentPadding
            Item {
                id: navRailWrapper
                Layout.fillHeight: true
                Layout.margins: 5
                implicitWidth: navRail.expanded ? 195 : 56
                Behavior on implicitWidth {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                NavigationRail { // Window content with navigation rail and content pane
                    id: navRail
                    anchors {
                        left: parent.left
                        top: parent.top
                        bottom: parent.bottom
                    }
                    spacing: 10
                    expanded: root.width > 900
                    
                    NavigationRailExpandButton {
                        focus: root.visible
                    }

                    // Profile Header in Sidebar (like end4-pC)
                    Item {
                        visible: navRail.expanded
                        Layout.fillWidth: true
                        implicitHeight: 48

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4
                            spacing: 8

                            Rectangle {
                                width: 36
                                height: 36
                                radius: 18
                                color: Appearance.colors.colPrimaryContainer

                                Image {
                                    id: avatarImg
                                    anchors.fill: parent
                                    source: {
                                        const pic = Config.options.profile.avatarPicture
                                        if (!pic || pic === "") return "file://" + CF.FileUtils.trimFileProtocol(Directories.home) + "/.face"
                                        return "file://" + CF.FileUtils.trimFileProtocol(pic)
                                    }
                                    fillMode: Image.PreserveAspectCrop
                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle { width: 36; height: 36; radius: 18 }
                                    }
                                    onStatusChanged: {
                                        if (status === Image.Ready) visible = true
                                        else if (status === Image.Error) visible = false
                                    }
                                }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "account_circle"
                                    iconSize: 22
                                    color: Appearance.colors.colOnPrimaryContainer
                                    visible: !avatarImg.visible || avatarImg.status === Image.Error
                                }
                            }

                            ColumnLayout {
                                spacing: 0
                                Layout.fillWidth: true

                                StyledText {
                                    text: Config.options.profile.displayName !== "" ? Config.options.profile.displayName : SystemInfo.username
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnLayer0
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                StyledText {
                                    text: Config.options.profile.descriptionText === "::uptime::" ? Translation.tr("Up • %1").arg(DateTime.uptime) : SystemInfo.distroName
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colSubtext
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showingProfile = !root.showingProfile
                        }
                    }

                    NavigationRailTabArray {
                        currentIndex: root.showingProfile ? -1 : root.currentPage
                        expanded: navRail.expanded
                        Repeater {
                            model: root.pages
                            NavigationRailButton {
                                required property var index
                                required property var modelData
                                toggled: !root.showingProfile && root.currentPage === index
                                onClicked: {
                                    root.goToPage(index);
                                }
                                expanded: navRail.expanded
                                buttonIcon: modelData.icon
                                buttonIconRotation: modelData.iconRotation || 0
                                buttonText: modelData.name
                                showToggledHighlight: false
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }
            Rectangle { // Content container
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Appearance.m3colors.m3surfaceContainerLow
                radius: Appearance.rounding.windowRounding - root.contentPadding

                Loader {
                    id: pageLoader
                    anchors.fill: parent
                    opacity: 1.0
                    asynchronous: true

                    active: Config.ready
                    Component.onCompleted: {
                        source = root.activePageSource
                    }

                    Connections {
                        target: root
                        function onActivePageSourceChanged() {
                            switchAnim.complete();
                            switchAnim.start();
                        }
                        function onScrollPosChanged() {
                            if (root.scrollPos == -1) return
                            scrollTimer.start()
                        }
                    }

                    Timer {
                        id: scrollTimer
                        interval: 250
                        onTriggered: {
                            if (pageLoader.item && pageLoader.item.contentY !== undefined) {
                                pageLoader.item.contentY = root.scrollPos
                            }
                            root.scrollPos = -1
                        }
                    }

                    SequentialAnimation {
                        id: switchAnim

                        NumberAnimation {
                            target: pageLoader
                            properties: "opacity"
                            from: 1
                            to: 0
                            duration: 100
                            easing.type: Appearance.animation.elementMoveExit.type
                            easing.bezierCurve: Appearance.animationCurves.emphasizedFirstHalf
                        }
                        PropertyAction {
                            target: pageLoader
                            property: "source"
                            value: root.activePageSource
                        }
                        NumberAnimation {
                            target: pageLoader
                            properties: "opacity"
                            from: 0
                            to: 1
                            duration: 180
                            easing.type: Appearance.animation.elementMoveEnter.type
                            easing.bezierCurve: Appearance.animationCurves.emphasizedLastHalf
                        }
                    }
                }
            }
        }
    }
}