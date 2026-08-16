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
        return !Config.options.policies.disabledExtensionTabs.includes(key);
    })

    property var tabButtonList: [
        ...(root.aiChatEnabled ? [{"key": "ai", "icon": "neurology", "name": Translation.tr("Intelligence")}] : []),
        ...(root.translatorEnabled ? [{"key": "translator", "icon": "translate", "name": Translation.tr("Translator")}] : []),
        ...((root.animeEnabled && !root.animeCloset) ? [{"key": "anime", "icon": "bookmark_heart", "name": Translation.tr("Anime")}] : []),
        ...root.enabledExtensionPages.map(p => ({"key": p.extensionId + ":" + (p.identifier || p.title), "icon": p.icon, "name": p.title}))
    ]
    property int tabCount: swipeView.count

    function focusActiveItem() {
        swipeView.currentItem.forceActiveFocus()
    }

    function createExtensionPage(page) {
        let loader = Qt.createQmlObject('import QtQuick; Loader { active: true }', swipeView)
        loader.source = "file://" + page.fullPath + "?_t=" + Date.now()
        let setExtId = () => {
            if (loader.item) {
                if ("extensionId" in loader.item) {
                    loader.item.extensionId = page.extensionId
                } else {
                    Object.defineProperty(loader.item, "extensionId", {
                        value: page.extensionId,
                        writable: true,
                        configurable: true,
                        enumerable: true
                    })
                }
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

    Component.onCompleted: Qt.callLater(connectNavigationSignals)

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
            Layout.alignment: Qt.AlignHCenter
            enableShadow: false
            colBackground: Appearance.colors.colLayer3
            ToolbarTabBar {
                id: tabBar
                Layout.alignment: Qt.AlignHCenter
                tabButtonList: root.tabButtonList
                maxTextTabs: root._maxTextTabs
                currentIndex: Math.min(Persistent.states.sidebar.policies.tab, Math.max(0, root.tabButtonList.length - 1))
                onCurrentIndexChanged: Persistent.states.sidebar.policies.tab = currentIndex
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
                onCurrentIndexChanged: Persistent.states.sidebar.policies.tab = currentIndex

                clip: true
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: swipeView.width
                        height: swipeView.height
                        radius: Appearance.rounding.small
                    }
                }

                contentChildren: [
                    ...(root.aiChatEnabled ? [aiChat.createObject()] : []),
                    ...(root.translatorEnabled ? [translator.createObject()] : []),
                    ...((root.tabButtonList.length === 0 || (!root.aiChatEnabled && !root.translatorEnabled && root.animeCloset)) ? [placeholder.createObject()] : []),
                    ...(root.animeEnabled ? [anime.createObject()] : []),
                    ...root.enabledExtensionPages.map(p => root.createExtensionPage(p)).filter(item => item)
                ]
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