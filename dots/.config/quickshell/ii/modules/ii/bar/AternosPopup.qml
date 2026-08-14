import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

LazyLoader {
    id: root
    property Item hoverTarget
    property bool stickyHover: false
    property int currentServerIndex: 0

    property bool _popupHovered: false
    property bool _stickyActive: false
    property bool _targetHovered: !!(hoverTarget?.containsMouse)

    active: stickyHover ? _stickyActive : (hoverTarget && hoverTarget.containsMouse)

    property QtObject _timers: QtObject {
        property Timer grace: Timer {
            interval: 100
            onTriggered: {
                root._popupHovered = false;
                root._stickyActive = false;
            }
        }
    }

    function _evaluateStickyState() {
        if (!stickyHover) return;
        if (_targetHovered || _popupHovered) {
            _stickyActive = true;
            _timers.grace.stop();
        } else if (_stickyActive && !_timers.grace.running) {
            _timers.grace.start();
        }
    }

    on_TargetHoveredChanged: _evaluateStickyState()
    onActiveChanged: {
        if (!active) {
            _popupHovered = false;
            _timers.grace.stop();
        }
    }

    component: PanelWindow {
        id: popupWindow
        color: "transparent"

        readonly property real screenWidth: popupWindow.screen?.width ?? 0
        readonly property real screenHeight: popupWindow.screen?.height ?? 0

        anchors.left: !Config.options.bar.vertical || (Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.right: Config.options.bar.vertical && Config.options.bar.bottom
        anchors.top: Config.options.bar.vertical || (!Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.bottom: !Config.options.bar.vertical && Config.options.bar.bottom

        implicitWidth: popupBg.implicitWidth + 20
        implicitHeight: popupBg.implicitHeight + 20

        mask: Region { item: popupBg }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0

        margins {
            left: {
                if (!Config.options.bar.vertical) {
                    if (!root.hoverTarget || !root.QsWindow) return 0;
                    var targetPos = root.QsWindow.mapFromItem(root.hoverTarget, 0, 0);
                    var centeredX = targetPos.x + (root.hoverTarget.width - popupWindow.implicitWidth) / 2;
                    return Math.max(0, Math.min(screenWidth - popupWindow.implicitWidth, centeredX));
                }
                return Appearance.sizes.verticalBarWidth;
            }
            top: {
                if (!Config.options.bar.vertical) return Appearance.sizes.barHeight;
                if (!root.hoverTarget || !root.QsWindow) return 0;
                var targetPos = root.QsWindow.mapFromItem(root.hoverTarget, 0, 0);
                var centeredY = targetPos.y + (root.hoverTarget.height - popupWindow.implicitHeight) / 2;
                return Math.max(0, Math.min(screenHeight - popupWindow.implicitHeight, centeredY));
            }
            right: Appearance.sizes.verticalBarWidth
            bottom: Appearance.sizes.barHeight
        }

        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay

        StyledRectangularShadow { target: popupBg }

        Rectangle {
            id: popupBg
            property real innerWidth: 320
            implicitWidth: innerWidth + 20
            implicitHeight: popupColumn.implicitHeight + 20
            color: Appearance.m3colors.m3surfaceContainer
            radius: Appearance.rounding.large
            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            ColumnLayout {
                id: popupColumn
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // Server tabs
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: Aternos.servers.length > 1

                    Repeater {
                        model: Aternos.servers

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: Appearance.rounding.small
                            color: root.currentServerIndex === index ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Rectangle {
                                    width: 6; height: 6; radius: 3
                                    color: {
                                        let st = (modelData.status || "").toLowerCase();
                                        if (st === "online") return "#22c55e";
                                        if (st === "starting" || st === "loading") return "#fde047";
                                        return "#808080";
                                    }
                                }

                                StyledText {
                                    text: (modelData.address || "Server").split(":")[0]
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.DemiBold
                                    color: root.currentServerIndex === index ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 100
                                }
                            }

                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.currentServerIndex = index }

                            Rectangle {
                                visible: root.currentServerIndex === index
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width * 0.6; height: 2; radius: 1
                                color: Appearance.colors.colPrimary
                            }
                        }
                    }
                }

                // Server card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: cardColumn.implicitHeight + 24
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer2

                    ColumnLayout {
                        id: cardColumn
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true; spacing: 8

                            MaterialSymbol { text: "dns"; iconSize: 20; color: Appearance.colors.colPrimary }

                            StyledText {
                                text: { let s = Aternos.servers[root.currentServerIndex]; return s ? (s.address || "?").split(":")[0] : "No server"; }
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Bold
                                color: Appearance.colors.colOnLayer1
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            MaterialSymbol {
                                iconSize: 18
                                color: Appearance.colors.colSubtext
                                text: "refresh"
                                opacity: mouseRefresh.containsMouse ? 1 : 0.6
                                MouseArea {
                                    id: mouseRefresh
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Aternos.listServers()
                                }
                            }

                            Rectangle {
                                implicitHeight: 22; implicitWidth: sr.implicitWidth + 12; radius: Appearance.rounding.full
                                color: {
                                    let s = Aternos.servers[root.currentServerIndex];
                                    if (!s) return Appearance.colors.colLayer3;
                                    let st = (s.status || "").toLowerCase();
                                    if (st === "online") return Qt.alpha("#22c55e", 0.15);
                                    if (st === "starting" || st === "loading") return Qt.alpha("#fde047", 0.15);
                                    return Appearance.colors.colLayer3;
                                }
                                RowLayout { id: sr; anchors.centerIn: parent; spacing: 4
                                    Rectangle { width: 6; height: 6; radius: 3
                                        color: { let s = Aternos.servers[root.currentServerIndex]; if (!s) return "#808080"; let st = (s.status||"").toLowerCase(); if (st==="online") return "#22c55e"; if (st==="starting"||st==="loading") return "#fde047"; return "#808080"; }
                                    }
                                    StyledText {
                                        text: { let s = Aternos.servers[root.currentServerIndex]; return s ? (s.status||"Unknown") : "?"; }
                                        font.pixelSize: Appearance.font.pixelSize.smallie; font.weight: Font.Medium; color: Appearance.colors.colOnLayer1
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true; spacing: 12
                            Row { spacing: 4
                                MaterialSymbol { text: "group"; iconSize: 14; color: Appearance.colors.colSubtext; anchors.verticalCenter: parent.verticalCenter }
                                StyledText { text: { let s = Aternos.servers[root.currentServerIndex]; if (!s) return "?/?"; return (s.players ?? "?") + "/" + (s.slots ?? "?"); } font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext; anchors.verticalCenter: parent.verticalCenter }
                                StyledToolTip {
                                    text: {
                                        let s = Aternos.servers[root.currentServerIndex];
                                        if (!s || (s.status || "").toLowerCase() !== "online") return "";
                                        let p = s.playerNames;
                                        if (p && p.length > 0) return Translation.tr("Online players:\n") + p.join("\n");
                                        return Translation.tr("No players online");
                                    }
                                    extraVisibleCondition: false
                                    alternativeVisibleCondition: playersRow.containsMouse
                                }
                                HoverHandler { id: playersRow }
                            }
                            Row { spacing: 4
                                MaterialSymbol { text: "memory"; iconSize: 14; color: Appearance.colors.colSubtext; anchors.verticalCenter: parent.verticalCenter }
                                StyledText { text: { let s = Aternos.servers[root.currentServerIndex]; return s ? `${s.software||"?"} ${s.version||""}` : ""; } font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Item { Layout.fillWidth: true }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: Appearance.colors.colLayer3 }

                        RowLayout {
                            Layout.fillWidth: true; spacing: 6

                            Repeater {
                                model: [
                                    { label: "Start", icon: "play_arrow", status: "offline", color: "Primary" },
                                    { label: "Restart", icon: "restart_alt", status: "online", color: "Secondary" },
                                    { label: "Stop", icon: "stop", status: "online", color: "Error" }
                                ]

                                Button {
                                    Layout.fillWidth: true
                                    implicitHeight: 32
                                    enabled: {
                                        let s = Aternos.servers[root.currentServerIndex];
                                        return s && (s.status || "").toLowerCase() === modelData.status;
                                    }
                                    background: Rectangle {
                                        radius: Appearance.rounding.small
                                        color: parent.enabled ? Appearance.colors["col" + modelData.color + "Container"] : Appearance.colors.colLayer3
                                        HoverHandler { cursorShape: parent.parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
                                    }
                                    contentItem: RowLayout {
                                        spacing: 4
                                        MaterialSymbol {
                                            text: modelData.icon; iconSize: 16
                                            color: parent.parent.parent.enabled ? Appearance.colors["colOn" + modelData.color + "Container"] : Appearance.colors.colSubtext
                                        }
                                        StyledText {
                                            text: modelData.label; font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.Medium
                                            color: parent.parent.parent.parent.enabled ? Appearance.colors["colOn" + modelData.color + "Container"] : Appearance.colors.colSubtext
                                        }
                                    }
                                    onClicked: {
                                        let s = Aternos.servers[root.currentServerIndex];
                                        if (!s) return;
                                        if (modelData.status === "offline") Aternos.startServer(s.address);
                                        else if (modelData.label === "Restart") { Aternos.stopServer(s.address); Aternos.startTimer = 2000; }
                                        else Aternos.stopServer(s.address);
                                    }
                                }
                            }
                        }

                        RowLayout { Layout.fillWidth: true; spacing: 6
                            TextField {
                                id: consoleInput; Layout.fillWidth: true; implicitHeight: 32
                                placeholderText: "Console command..."
                                color: Appearance.colors.colOnLayer1; placeholderTextColor: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.small
                                background: Rectangle {
                                    color: Appearance.colors.colLayer1; radius: Appearance.rounding.small
                                    border.color: consoleInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer3; border.width: 1
                                }
                                onAccepted: {
                                    if (text.trim().length > 0) { let s = Aternos.servers[root.currentServerIndex]; if (s) { Aternos.sendCommand(s.address, text.trim()); text = ""; } }
                                }
                            }
                            Button {
                                id: sendBtn
                                implicitWidth: 32; implicitHeight: 32; enabled: consoleInput.text.trim().length > 0
                                background: Rectangle { radius: Appearance.rounding.small; color: sendBtn.enabled ? Appearance.colors.colPrimary : Appearance.colors.colLayer3; HoverHandler { cursorShape: sendBtn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor } }
                                contentItem: MaterialSymbol { text: "send"; iconSize: 16; color: sendBtn.enabled ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext }
                                onClicked: { if (consoleInput.text.trim().length > 0) { let s = Aternos.servers[root.currentServerIndex]; if (s) { Aternos.sendCommand(s.address, consoleInput.text.trim()); consoleInput.text = ""; } } }
                            }
                        }

                        StyledText { visible: Aternos.lastError.length > 0; text: Aternos.lastError; font.pixelSize: Appearance.font.pixelSize.smallie; color: Appearance.colors.colError; wrapMode: Text.Wrap; Layout.fillWidth: true }
                        StyledText { visible: Aternos.lastOutput.length > 0; text: Aternos.lastOutput; font.pixelSize: Appearance.font.pixelSize.smallie; color: Appearance.colors.colSubtext; wrapMode: Text.Wrap; Layout.fillWidth: true }
                    }
                }

                // Empty state
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 120
                    radius: Appearance.rounding.normal; color: Appearance.colors.colLayer2
                    visible: Aternos.servers.length === 0
                    ColumnLayout { anchors.centerIn: parent; spacing: 8
                        MaterialSymbol { text: "dns"; iconSize: 32; color: Appearance.colors.colSubtext; Layout.alignment: Qt.AlignHCenter }
                        StyledText { text: Aternos.loading ? "Loading servers..." : "No servers found"; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext; Layout.alignment: Qt.AlignHCenter }
                        Button {
                            Layout.alignment: Qt.AlignHCenter; implicitHeight: 28; text: "Refresh"; enabled: !Aternos.loading
                            background: Rectangle { radius: Appearance.rounding.small; color: Appearance.colors.colPrimaryContainer }
                            contentItem: StyledText { text: parent.text; font.pixelSize: Appearance.font.pixelSize.smallie; color: Appearance.colors.colOnPrimaryContainer; horizontalAlignment: Text.AlignHCenter }
                            onClicked: Aternos.listServers()
                        }
                    }
                }
            }

            HoverHandler { onHoveredChanged: { root._popupHovered = hovered; root._evaluateStickyState(); } }
        }
    }
}
