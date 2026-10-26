import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root
    property string title
    property string icon: ""
    property string tooltip: ""
    property string hint: ""
    property string hintIcon: "info"
    property var shape: MaterialShape.Shape.Clover4Leaf
    property bool collapsible: true
    property string sectionId: ""
    property list<string> stringMap: []
    default property alias contentData: sectionContent.data

    /// Identity used in `settings.collapsedSections`. Titles are unique within a
    /// settings page, so they work as keys when no explicit sectionId is given.
    readonly property string collapseKey: root.sectionId !== "" ? root.sectionId : root.title
    readonly property bool collapsed: root.collapsible
        && (Config.options.settings.collapsedSections ?? []).includes(root.collapseKey)

    Layout.fillWidth: true
    implicitHeight: mainLayout.implicitHeight + 32
    implicitWidth: mainLayout.implicitWidth + 32

    color: Appearance.colors.colLayer1
    radius: Appearance.rounding.large
    border.color: Appearance.colors.colLayer0Border
    border.width: 1

    function _writeCollapsedList(list) {
        Config.options.settings.collapsedSections = list
    }

    function toggleCollapsed() {
        if (!root.collapsible || root.collapseKey === "") return
        const list = (Config.options.settings.collapsedSections ?? []).slice()
        const idx = list.indexOf(root.collapseKey)
        if (idx === -1) list.push(root.collapseKey)
        else list.splice(idx, 1)
        root._writeCollapsedList(list)
    }

    /// Double-clicking a header folds/unfolds every section on the page at once.
    function setSiblingsCollapsed(collapsed) {
        const parentItem = root.parent
        if (!parentItem || !parentItem.children) return
        const keys = []
        for (let i = 0; i < parentItem.children.length; i++) {
            const sibling = parentItem.children[i]
            if (sibling.collapsible && sibling.collapseKey !== undefined && sibling.collapseKey !== "")
                keys.push(sibling.collapseKey)
        }
        if (keys.length === 0) return
        // Keep the collapse state of sections that live on other pages.
        const rest = (Config.options.settings.collapsedSections ?? []).filter(k => !keys.includes(k))
        root._writeCollapsedList(collapsed ? rest.concat(keys) : rest)
    }

    Component.onCompleted: {
        if (page?.register == false) return
        // console.log("KEYWORDS", root.stringMap)
        if (!page?.index) return
        SearchRegistry.registerSection({
            pageIndex: page?.index,
            title: root.title,
            searchStrings: root.stringMap.slice(),
            yPos: root.y
        })
    }

    function addKeyword(word) {
        if (!word) return
        // console.log("ADD KEYWORD", word)
        stringMap.push(word)
    }

    SearchHandler {
        searchString: root.title
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Item {
            id: headerArea
            Layout.fillWidth: true
            implicitHeight: headerRow.implicitHeight

            // Declared before the row so the row's own children (hint tooltip) win hover.
            MouseArea {
                anchors.fill: parent
                enabled: root.collapsible
                cursorShape: root.collapsible ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.toggleCollapsed()
                onDoubleClicked: root.setSiblingsCollapsed(!root.collapsed)
            }

            RowLayout {
                id: headerRow
                anchors.fill: parent
                spacing: 8
                OptionalMaterialSymbol {
                    opacity: 1 - highlightOverlay.opacity
                    icon: root.icon
                    iconSize: Appearance.font.pixelSize.hugeass
                }
                StyledText {
                    opacity: 1 - highlightOverlay.opacity
                    text: root.title
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }
                MaterialSymbol {
                    opacity: 1 - highlightOverlay.opacity
                    visible: (root.tooltip && root.tooltip.length > 0) || root.hint.length > 0
                    text: root.hintIcon
                    iconSize: Appearance.font.pixelSize.larger

                    color: Appearance.colors.colSubtext
                    MouseArea {
                        id: infoMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        // Hover only — clicks fall through to the collapse handler.
                        acceptedButtons: Qt.NoButton
                        cursorShape: Qt.WhatsThisCursor
                        StyledToolTip {
                            extraVisibleCondition: false
                            alternativeVisibleCondition: infoMouseArea.containsMouse
                            text: root.tooltip || root.hint
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                MaterialSymbol {
                    visible: root.collapsible
                    text: "expand_more"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colSubtext
                    rotation: root.collapsed ? -90 : 0

                    Behavior on rotation {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                HighlightOverlay {
                    id: highlightOverlay
                    visible: false
                }
            }
        }

        Item {
            id: sectionWrapper
            Layout.fillWidth: true
            clip: true
            implicitHeight: root.collapsed ? 0 : sectionContent.implicitHeight
            visible: implicitHeight > 0

            Behavior on implicitHeight {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            ColumnLayout {
                id: sectionContent
                width: parent.width
                spacing: 8
            }
        }
    }
}
