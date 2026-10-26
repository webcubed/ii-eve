import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Qt.labs.synchronizer

Item {
    id: root
    required property var scopeRoot
    property int sidebarPadding: 10
    anchors.fill: parent
    property bool aiChatEnabled: Config.options.policies.ai !== 0
    property bool translatorEnabled: Config.options.policies.translator !== 0
    property bool animeEnabled: Config.options.policies.weeb !== 0
    property bool animeCloset: Config.options.policies.weeb === 2
    property bool mediaEnabled: Config.options.policies.player !== 0
    property bool wallpapersEnabled: Config.options.policies.wallpapers !== 0
    property bool tailscaleEnabled: Config.ready && (Config.options.policies?.tailscale ?? 0) !== 0
    property bool dockerEnabled: Config.ready && (Config.options.policies?.docker ?? 0) !== 0
    property bool vpnEnabled: Config.ready && (Config.options.policies?.vpn ?? 0) !== 0
    property bool emailEnabled: Config.ready && (Config.options.policies?.email ?? 0) !== 0
    property bool notesEnabled: Config.ready && (Config.options.policies?.notes ?? 0) !== 0
    property bool phoneEnabled: Config.options.policies.phone !== 0

    property bool _sidebarExtended: scopeRoot.extend
    property int _maxTextTabs: _sidebarExtended ? 4 : 3

    property var extensionPages: ExtensionManager.ready
        ? ExtensionManager.getContributionPoint("sidebarLeftPages") : []

    Connections {
        target: ExtensionManager
        function onRefreshExtensions() { root.extensionPages = ExtensionManager.getContributionPoint("sidebarLeftPages") }
        function onExtensionInstalled() { root.extensionPages = ExtensionManager.getContributionPoint("sidebarLeftPages") }
        function onExtensionRemoved() { root.extensionPages = ExtensionManager.getContributionPoint("sidebarLeftPages") }
        function onExtensionToggled() { root.extensionPages = ExtensionManager.getContributionPoint("sidebarLeftPages") }
    }

    property var enabledExtensionPages: root.extensionPages.filter(p => {
        let key = p.extensionId + ":" + (p.identifier || p.title);
        return !Config.options.policies.disabledExtensionTabs?.includes(key);
    })

    property var _allPages: [
        ...(root.aiChatEnabled ? [{"key": "ai", "icon": "neurology", "name": Translation.tr("Intelligence"), "comp": aiChat, "hidden": false}] : []),
        ...(root.mediaEnabled ? [{"key": "media", "icon": "music_note", "name": Translation.tr("Media"), "comp": media, "hidden": false}] : []),
        ...(root.wallpapersEnabled ? [{"key": "wallpapers", "icon": "wallpaper", "name": Translation.tr("Wallpapers"), "comp": wallpaperBrowser, "hidden": false}] : []),
        ...(root.animeEnabled ? [{"key": "anime", "icon": "bookmark_heart", "name": Translation.tr("Anime"), "comp": anime, "hidden": root.animeCloset}] : []),
        ...(root.tailscaleEnabled ? [{"key": "tailscale", "icon": "hub", "name": Translation.tr("Tailscale"), "comp": tailscalePage, "hidden": false}] : []),
        ...(root.dockerEnabled ? [{"key": "docker", "icon": "inventory", "name": Translation.tr("Docker"), "comp": dockerPage, "hidden": false}] : []),
        ...(root.vpnEnabled ? [{"key": "vpn", "icon": "shield", "name": Translation.tr("VPN"), "comp": vpnPage, "hidden": false}] : []),
        ...(root.emailEnabled ? [{"key": "email", "icon": "mail", "name": Translation.tr("Email"), "comp": emailPage, "hidden": false}] : []),
        ...(root.notesEnabled ? [{"key": "notes", "icon": "sticky_note_2", "name": Translation.tr("Notes"), "comp": notesPage, "hidden": false}] : []),
        ...(root.phoneEnabled ? [{"key": "phone", "icon": "smartphone", "name": Translation.tr("Phone"), "comp": phonePlaceholder, "hidden": false}] : []),
        ...root.enabledExtensionPages.map(p => ({"key": p.extensionId + ":" + (p.identifier || p.title), "icon": p.icon, "name": p.title, "ext": p, "hidden": false}))
    ]

    // Rebuild the SwipeView children ONLY when the page set actually changes.
    // Creating pages inside a reactive `contentChildren` binding causes a binding
    // loop: every re-evaluation destroys + recreates ALL pages (see AGENTS.md).
    property bool _rebuildQueued: false
    onExtensionPagesChanged: root.queueRebuild()

    function queueRebuild() {
        if (root._rebuildQueued) return;
        root._rebuildQueued = true;
        Qt.callLater(() => {
            root._rebuildQueued = false;
            root.rebuildPages();
        });
    }

    property var _orderedPages: _sortTabsByOrder(_allPages)
    property var tabButtonList: _orderedPages.filter(p => !p.hidden)

    function _sortTabsByOrder(tabs) {
        const order = Config.ready ? (Config.options.sidebar?.tabOrder ?? []) : [];
        if (order.length === 0) return tabs;
        const result = [];
        // First add tabs in the stored order (if they still exist)
        for (let i = 0; i < order.length; i++) {
            const found = tabs.find(t => t.key === order[i]);
            if (found) result.push(found);
        }
        // Then add any new tabs not in the order list
        for (let i = 0; i < tabs.length; i++) {
            if (!result.some(t => t.key === tabs[i].key)) result.push(tabs[i]);
        }
        return result;
    }

    // Tab index and page index are the same — both iterate
    // the same filtered list (_orderedPages minus hidden items).
    function _pageIndexForTab(tabIndex) { return tabIndex; }
    function _tabIndexForPage(pageIndex) { return pageIndex; }

    function _saveTabOrder() {
        const order = tabButtonList.map(t => t.key);
        Config.options.sidebar.tabOrder = order;
    }
    property int tabCount: swipeView.count

    function focusActiveItem() {
        swipeView.currentItem.forceActiveFocus()
    }

    function createExtensionPageInto(item, page) {
        if (!item || !page) return;
        if ("extensionId" in item) {
            item.extensionId = page.extensionId;
        } else {
            Object.defineProperty(item, "extensionId", {
                value: page.extensionId,
                writable: true,
                configurable: true,
                enumerable: true
            });
        }
    }

    property var _currentPageItems: []

    function rebuildPages() {
        for (let i = root._currentPageItems.length - 1; i >= 0; i--) {
            root._currentPageItems[i].destroy();
        }
        root._currentPageItems = [];
        swipeView.contentChildren = [];
        // Use tabButtonList directly — same source as the tab bar
        const pages = root.tabButtonList;
        const items = [];
        for (let i = 0; i < pages.length; i++) {
            const page = pages[i];
            if (page.comp) {
                items.push(page.comp.createObject());
            } else if (page.ext) {
                const loader = Qt.createQmlObject('import QtQuick; Loader { active: true }', swipeView);
                loader.source = "file://" + page.ext.fullPath + "?_t=" + Date.now();
                const extPage = page.ext;
                const setExtId = () => {
                    if (loader.item) root.createExtensionPageInto(loader.item, extPage);
                };
                if (loader.status === Loader.Ready) setExtId();
                else loader.loaded.connect(setExtId);
                items.push(loader);
            }
        }
        root._currentPageItems = items;
        swipeView.contentChildren = items;
    }

    function createExtensionPage(page) {
        let loader = Qt.createQmlObject('import QtQuick; Loader { active: true }', swipeView)
        loader.source = "file://" + page.fullPath + "?_t=" + Date.now()
        let setExtId = () => {
            if (loader.item) {
                root.createExtensionPageInto(loader.item, page);
            }
        }
        if (loader.status === Loader.Ready) {
            setExtId()
        } else {
            loader.loaded.connect(setExtId)
        }
        return loader
    }

    Keys.onPressed: (event) => {
        if (event.modifiers & Qt.ControlModifier) {
            if (event.key === Qt.Key_PageDown || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
                swipeView.incrementCurrentIndex()
                event.accepted = true;
            }
            else if (event.key === Qt.Key_PageUp || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                swipeView.decrementCurrentIndex()
                event.accepted = true;
            }
        }
        // Ctrl+Shift+Left/Right to reorder tabs
        if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                _moveCurrentTab(event.key === Qt.Key_Right ? 1 : -1);
                event.accepted = true;
            }
        }
    }

    function _moveCurrentTab(direction) {
        const idx = root._tabIndexForPage(Persistent.states.sidebar.policies.tab);
        const order = tabButtonList.map(t => t.key);
        if (idx < 0 || idx >= order.length) return;
        const newIdx = idx + direction;
        if (newIdx < 0 || newIdx >= order.length) return;
        // Swap
        const temp = order[idx];
        order[idx] = order[newIdx];
        order[newIdx] = temp;
        // Save to config; the active page stays put, only the tab moves
        Config.options.sidebar.tabOrder = order;
    }

    Shortcut { sequence: "Ctrl+Tab"; onActivated: swipeView.incrementCurrentIndex() }
    Shortcut { sequence: "Ctrl+Shift+Tab"; onActivated: swipeView.decrementCurrentIndex() }
    Shortcut { sequence: "Ctrl+PageDown"; onActivated: swipeView.incrementCurrentIndex() }
    Shortcut { sequence: "Ctrl+PageUp"; onActivated: swipeView.decrementCurrentIndex() }

    property var _connectedItems: []

    function connectNavigationSignals() {
        for (let i = 0; i < swipeView.count; i++) {
            let item = swipeView.itemAt(i);
            // Direct items (AiChat, Anime) have signals on item itself;
            // extension pages are wrapped in Loaders, signals on item.item
            let target = item && item.navigateLeft ? item :
                         (item && item.item && item.item.navigateLeft ? item.item : null);
            if (target && !_connectedItems.includes(target)) {
                _connectedItems.push(target);
                target.navigateLeft.connect(() => swipeView.decrementCurrentIndex());
                target.navigateRight.connect(() => swipeView.incrementCurrentIndex());
                target.navigateNext.connect(() => swipeView.incrementCurrentIndex());
                target.navigatePrev.connect(() => swipeView.decrementCurrentIndex());
            }
        }
    }

    Component.onCompleted: {
        Qt.callLater(root.rebuildPages);
        Qt.callLater(root.connectNavigationSignals);
        Qt.callLater(() => {
            const item = swipeView.currentItem;
            if (item && typeof item.triggerContentEntrance === "function")
                item.triggerContentEntrance();
        });
    }

    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: root.connectNavigationSignals()
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: sidebarPadding
        }
        spacing: sidebarPadding

        Toolbar {
            visible: tabButtonList.length > 1
            Layout.fillWidth: true
            enableShadow: false
            colBackground: Appearance.colors.colLayer3
            ToolbarTabBar {
                id: tabBar
                Layout.alignment: Qt.AlignHCenter
                tabButtonList: root.tabButtonList
                maxTextTabs: root._maxTextTabs
                currentIndex: Math.min(root._tabIndexForPage(Persistent.states.sidebar.policies.tab), Math.max(0, root.tabButtonList.length - 1))
                onCurrentIndexChanged: Persistent.states.sidebar.policies.tab = root._pageIndexForTab(currentIndex)
                onTabReordered: (fromIdx, toIdx) => {
                    const keys = root.tabButtonList.map(t => t.key);
                    const item = keys.splice(fromIdx, 1)[0];
                    keys.splice(toIdx, 0, item);
                    Config.options.sidebar.tabOrder = keys;
                }
            }

            MaterialSymbol {
                id: editModeToggle
                Layout.alignment: Qt.AlignVCenter
                iconSize: 18
                text: tabBar.editMode ? "check" : "drag_indicator"
                color: tabBar.editMode ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                opacity: editModeMouse.containsMouse ? 1 : 0.6

                MouseArea {
                    id: editModeMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tabBar.editMode = !tabBar.editMode
                }

                StyledToolTip {
                    extraVisibleCondition: false
                    alternativeVisibleCondition: editModeMouse.containsMouse
                    text: tabBar.editMode ? Translation.tr("Done reordering") : Translation.tr("Reorder tabs")
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitWidth: swipeView.implicitWidth
            implicitHeight: swipeView.implicitHeight
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1

            SwipeView { // Content pages
                id: swipeView
                anchors.fill: parent
                spacing: 10
                currentIndex: Math.min(Persistent.states.sidebar.policies.tab, Math.max(0, swipeView.count - 1))
                onCurrentIndexChanged: {
                    Persistent.states.sidebar.policies.tab = currentIndex;
                    const item = swipeView.currentItem;
                    if (item && typeof item.triggerContentEntrance === "function")
                        item.triggerContentEntrance();
                }

                clip: true
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: swipeView.width
                        height: swipeView.height
                        radius: Appearance.rounding.small
                    }
                }

                // contentChildren is set imperatively via rebuildPages()
            }
        }

        Component {
            id: aiChat
            AiChat {}
        }
        Component {
            id: translator
            Translator {}
        }
        Component {
            id: anime
            Anime {}
        }
        Component {
            id: tailscalePage
            TailscalePage {}
        }
        Component {
            id: dockerPage
            DockerPage {}
        }
        Component {
            id: vpnPage
            VpnPage {}
        }
        Component {
            id: emailPage
            EmailPage {}
        }
        Component {
            id: notesPage
            NotesPage {}
        }
        Component {
            id: media
            SidebarPlayerControl {}
        }
        Component {
            id: wallpaperBrowser
            WallpaperBrowserUI {}
        }
        Component {
            id: phonePlaceholder
            Item {
                property string extensionId: ""
                anchors.fill: parent
                StyledText {
                    anchors.centerIn: parent
                    text: Translation.tr("Phone")
                    color: Appearance.colors.colSubtext
                }
            }
        }
        Component {
            id: placeholder
            Item {
                StyledText {
                    anchors.centerIn: parent
                    text: root.animeCloset ? Translation.tr("Nothing") : Translation.tr("Enjoy your empty sidebar...")
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}