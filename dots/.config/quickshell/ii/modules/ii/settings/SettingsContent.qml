import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
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

    // ── Settings search ────────────────────────────────────────────────
    property string searchQuery: ""
    property var searchResults: []

    Timer {
        id: searchDebounce
        interval: 110
        onTriggered: {
            const query = root.searchQuery.trim();
            root.searchResults = query === "" ? [] : SettingsSearchIndex.search(query, 14);
        }
    }

    onSearchQueryChanged: searchDebounce.restart()

    // Pages index asynchronously, so a query typed right after the window opens
    // would otherwise stay limited to page names. Re-run it as entries arrive.
    Connections {
        target: SettingsSearchIndex
        function onRevisionChanged() {
            const query = root.searchQuery.trim();
            if (query !== "") root.searchResults = SettingsSearchIndex.search(query, 14);
        }
    }

    Shortcut {
        sequence: "Ctrl+F"
        onActivated: searchInput.forceActiveFocus()
    }

    function clearSearch() {
        root.searchQuery = "";
        searchInput.text = "";
        root.searchResults = [];
    }

    function goToSearchResult(result) {
        if (!result) return;
        root.clearSearch();
        searchInput.focus = false;
        root.goToTarget({
            page: result.pageId,
            label: result.rawLabel,
            section: result.kind === "page" ? "" : result.rawSection
        });
    }
    // Page crossfade duration, scaled by the settings app's animation speed setting.
    readonly property int pageTransitionDuration: Math.max(60, Math.round(200 / Math.max(0.5, Config.options.settings.animationSpeed ?? 1)))

    /**
     * Switch to a page and, when a section is named, scroll to it. Sections
     * scroll themselves through SearchRegistry + their own SearchHandler, which
     * is the only scroll-to hook the pages expose.
     */
    function goToTarget(target) {
        if (!target) return;
        const idx = root.pages.findIndex(p => p.id === target.page);
        if (idx < 0) return;
        root.currentPage = idx;
        root.showingProfile = false;

        const section = target.section || target.label;
        if (!section) return;

        const scrollToSection = () => Qt.callLater(() => { SearchRegistry.currentSearch = section; });
        const loader = pagesRepeater.itemAt(idx);
        if (!loader) return;
        if (loader.item) {
            scrollToSection();
        } else {
            const onceLoaded = () => {
                loader.loaded.disconnect(onceLoaded);
                scrollToSection();
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

        // Top bar: search across every settings page, plus a way out of the app
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            z: 100

            RowLayout {
                id: topBarRow
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                spacing: 10

                Item { Layout.fillWidth: true }

                Rectangle {
                    id: searchBox
                    Layout.preferredWidth: 320
                    Layout.maximumWidth: 420
                    Layout.preferredHeight: 40
                    radius: 20
                    color: Appearance.colors.colLayer1
                    border.width: (searchInput.activeFocus || root.searchQuery !== "") ? 1 : 0
                    border.color: Appearance.colors.colPrimary

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 14
                            rightMargin: 8
                        }
                        spacing: 8

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignVCenter
                            text: "search"
                            iconSize: 18
                            color: Appearance.colors.colSubtext
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24

                            StyledTextInput {
                                id: searchInput
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                color: Appearance.colors.colOnLayer1
                                font.pixelSize: Appearance.font.pixelSize.normal
                                onTextChanged: root.searchQuery = text
                                Keys.onEscapePressed: root.clearSearch()
                                Keys.onDownPressed: searchResultsList.incrementCurrentIndex()
                                Keys.onUpPressed: searchResultsList.decrementCurrentIndex()
                                Keys.onReturnPressed: root.goToSearchResult(root.searchResults[searchResultsList.currentIndex])
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Translation.tr("Search settings…")
                                visible: searchInput.text === ""
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colSubtext
                            }
                        }

                        RippleButton {
                            Layout.alignment: Qt.AlignVCenter
                            visible: searchInput.text !== ""
                            implicitWidth: 26
                            implicitHeight: 26
                            buttonRadius: 13
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer2Hover
                            onClicked: root.clearSearch()
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: "close"
                                iconSize: 16
                                color: Appearance.colors.colOnLayer1
                            }
                        }
                    }
                }

                RippleButton {
                    id: closeButton
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 40
                    implicitHeight: 40
                    buttonRadius: 20
                    colBackground: Appearance.colors.colLayer1
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    onClicked: Window.window?.close()
                    StyledToolTip {
                        text: Translation.tr("Close settings")
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "close"
                        iconSize: 20
                        color: Appearance.colors.colOnLayer1
                    }
                }
            }

            // Results float over the page, anchored under the search field
            Item {
                id: searchResultsPanel
                visible: root.searchQuery.trim() !== ""
                // The field lives inside the top bar's RowLayout, and anchoring to a
                // non-sibling is ignored, which dumped the panel in the top-left
                // corner. Mirror the row instead: the field's right edge sits one
                // close-button plus one gap inwards from the bar's right edge.
                anchors {
                    right: parent.right
                    rightMargin: closeButton.width + topBarRow.spacing
                    top: parent.bottom
                    topMargin: 8
                }
                width: Math.max(320, Math.min(460, root.width - 40))
                height: Math.min(searchResultsList.contentHeight + 16, 380)
                z: 200

                // Same elevation treatment as the other dropdowns: an opaque m3
                // surface with a soft shadow, so the list never blends into the
                // page it covers.
                StyledRectangularShadow {
                    target: searchResultsBackground
                }

                Rectangle {
                    id: searchResultsBackground
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: Appearance.m3colors.m3surfaceContainerHigh
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                }

                StyledListView {
                    id: searchResultsList
                    anchors {
                        fill: parent
                        margins: 8
                    }
                    animateAppearance: false
                    animatePopulate: false
                    model: root.searchResults

                    delegate: RippleButton {
                        id: resultRow
                        required property var modelData
                        required property int index

                        width: ListView.view.width
                        implicitHeight: 48
                        buttonRadius: Appearance.rounding.small
                        colBackground: ListView.isCurrentItem ? Appearance.colors.colLayer2Hover : "transparent"
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        onClicked: root.goToSearchResult(resultRow.modelData)

                        contentItem: RowLayout {
                            spacing: 10
                            MaterialSymbol {
                                Layout.leftMargin: 8
                                Layout.alignment: Qt.AlignVCenter
                                text: resultRow.modelData.icon ?? "settings"
                                iconSize: 18
                                color: Appearance.colors.colPrimary
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: -2
                                StyledText {
                                    Layout.fillWidth: true
                                    text: resultRow.modelData.label
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnLayer1
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    visible: resultRow.modelData.kind !== "page"
                                    text: resultRow.modelData.kind === "section"
                                        ? resultRow.modelData.pageName
                                        : `${resultRow.modelData.pageName} › ${resultRow.modelData.section}`
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: root.searchResults.length === 0
                    text: Translation.tr("No matches")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
            }
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