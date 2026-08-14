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

    // Built-in AI chat page
    property var builtInPages: [
        { icon: "psychology", title: "AI", component: "aiChat" }
    ]

    property var tabButtonList: [
        ...root.builtInPages.map(p => ({icon: p.icon, name: p.title})),
        ...root.extensionPages.map(p => ({icon: p.icon, name: p.title}))
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
        if (event.modifiers === Qt.ControlModifier) {
            if (event.key === Qt.Key_PageDown || event.key === Qt.Key_Tab) {
                swipeView.incrementCurrentIndex()
                event.accepted = true;
            }
            else if (event.key === Qt.Key_PageUp || (event.key === Qt.Key_Tab && event.modifiers & Qt.ShiftModifier)) {
                swipeView.decrementCurrentIndex()
                event.accepted = true;
            }
        }
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

                // Built-in AI chat page
                AiChat {}

                // Extension pages
                Repeater {
                    model: root.extensionPages

                    Loader {
                        active: true
                        property var pageData: modelData
                        source: "file://" + pageData.fullPath + "?_t=" + Date.now()

                        onLoaded: {
                            if (item && "extensionId" in item) {
                                item.extensionId = pageData.extensionId
                            } else if (item) {
                                Object.defineProperty(item, "extensionId", {
                                    value: pageData.extensionId,
                                    writable: true,
                                    configurable: true,
                                    enumerable: true
                                })
                            }
                        }
                    }
                }
            }
        }

        Component {
            id: placeholder
            Item {
                StyledText {
                    anchors.centerIn: parent
                    text: Translation.tr("Enjoy your empty sidebar...")
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}
