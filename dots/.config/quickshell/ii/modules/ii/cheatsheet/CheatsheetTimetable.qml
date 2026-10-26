import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import qs.modules.common.functions

Item {
    id: root
    property real spacing: 4
    property int startHour: 0
    property int endHour: 24
    property int slotHeight: 50
    property int timeColumnWidth: 55
    property int weekOffset: 0

    readonly property int totalSlots: (endHour - startHour)
    readonly property real pixelsPerMinute: slotHeight / 60
    readonly property int contentHeight: totalSlots * slotHeight
    readonly property int dayCount: 7
    readonly property real availableWidth: width - timeColumnWidth - (dayCount + 1) * spacing
    readonly property real dayColumnWidth: Math.max(60, availableWidth / dayCount)
    readonly property int currentDayIndex: {
        var d = new Date().getDay();
        return (d - Config.options.time.firstDayOfWeek + 6) % 7;
    }
    readonly property string weekLabel: {
        var now = new Date();
        var monday = new Date(now);
        var dow = now.getDay();
        var diff = dow === 0 ? -6 : 1 - dow;
        monday.setDate(now.getDate() + diff + weekOffset * 7);
        var sunday = new Date(monday);
        sunday.setDate(monday.getDate() + 6);
        return Qt.formatDate(monday, "MMM d") + " - " + Qt.formatDate(sunday, "MMM d") + ", " + Qt.formatDate(sunday, "yyyy");
    }

    implicitWidth: 700
    implicitHeight: 550

    property var days: root.buildWeek()
    property real currentTimeY: -1

    function buildWeek() {
        var result = [];
        var now = new Date();
        var dow = now.getDay();
        var diff = dow === 0 ? -6 : 1 - dow;
        var monday = new Date(now);
        monday.setDate(now.getDate() + diff + weekOffset * 7);
        monday.setHours(0, 0, 0, 0);
        var weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
        for (var i = 0; i < 7; i++) {
            var dayDate = new Date(monday);
            dayDate.setDate(monday.getDate() + i);
            var dayEvents = CalendarService.getTasksByDate(dayDate);
            var formattedEvents = [];
            for (var j = 0; j < dayEvents.length; j++) {
                var evt = dayEvents[j];
                var startTime = evt['startDate'] ? Qt.formatDateTime(evt['startDate'], "HH:mm") : "00:00";
                var endTime = evt['endDate'] ? Qt.formatDateTime(evt['endDate'], "HH:mm") : "23:59";
                formattedEvents.push({
                    "title": evt['content'],
                    "start": startTime,
                    "end": endTime,
                    "color": evt['color'],
                    "description": evt['description'] ?? ""
                });
            }
            result.push({ "name": weekdayNames[dayDate.getDay()], "events": formattedEvents });
        }
        return result;
    }

    function navigateWeek(delta) { weekOffset += delta; days = buildWeek(); }

    function updateCurrentTimeLine() {
        var now = new Date();
        var totalMin = now.getHours() * 60 + now.getMinutes();
        currentTimeY = (totalMin - startHour * 60) * pixelsPerMinute;
    }

    function isAllDayEvent(event) {
        if (!event) return false;
        var s = event.start || "";
        var e = event.end || "";
        return (s === "00:00" && e === "23:59") || (s === "00:00" && e === "00:00") || (!event.start && !event.end);
    }

    function parseTimeToMinutes(timeStr) {
        if (!timeStr) return null;
        var parts = timeStr.split(":");
        if (parts.length < 2) return null;
        var h = parseInt(parts[0]);
        var m = parseInt(parts[1]);
        if (isNaN(h) || isNaN(m)) return null;
        return h * 60 + m;
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Up) { navigateWeek(-1); event.accepted = true; }
        else if (event.key === Qt.Key_Down) { navigateWeek(1); event.accepted = true; }
        else if (event.key === Qt.Key_Home) { weekOffset = 0; days = buildWeek(); event.accepted = true; }
    }

    focusPolicy: Qt.StrongFocus

    Timer { interval: 30000; repeat: true; running: true; onTriggered: root.updateCurrentTimeLine() }
    Component.onCompleted: root.updateCurrentTimeLine()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Week nav bar
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            Layout.margins: 4
            spacing: 8

            RippleButton {
                implicitWidth: 24; implicitHeight: 24; buttonRadius: Appearance.rounding.full
                onClicked: root.navigateWeek(-1)
                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "chevron_left"; iconSize: 18; color: Appearance.colors.colOnLayer1 }
            }
            StyledText {
                Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                text: root.weekLabel; font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
            }
            RippleButton {
                implicitWidth: 24; implicitHeight: 24; buttonRadius: Appearance.rounding.full
                onClicked: root.navigateWeek(1)
                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "chevron_right"; iconSize: 18; color: Appearance.colors.colOnLayer1 }
            }
            RippleButton {
                implicitWidth: 24; implicitHeight: 24; buttonRadius: Appearance.rounding.full
                visible: root.weekOffset !== 0
                onClicked: { root.weekOffset = 0; root.days = root.buildWeek(); }
                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "today"; iconSize: 16; color: Appearance.colors.colPrimary }
            }
        }

        // Day headers (fixed)
        Row {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            Layout.leftMargin: root.timeColumnWidth + root.spacing
            spacing: root.spacing
            Repeater {
                model: root.days
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: root.dayColumnWidth
                    height: 32
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 2; height: 28; radius: Appearance.rounding.normal
                        color: index === root.currentDayIndex && root.weekOffset === 0 ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer1
                        StyledText {
                            anchors.centerIn: parent
                            text: modelData.name.substring(0, 3)
                            font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.DemiBold
                            color: index === root.currentDayIndex && root.weekOffset === 0 ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                        }
                    }
                }
            }
        }

        // Scrollable timetable body
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Flickable {
                id: flick
                anchors.fill: parent
                contentHeight: root.contentHeight
                clip: true
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds

                MouseArea {
                    anchors.fill: parent
                    onWheel: (event) => {
                        if (event.angleDelta.y > 0)
                            flick.contentY = Math.max(0, flick.contentY - 60);
                        else
                            flick.contentY = Math.min(flick.contentHeight - flick.height, flick.contentY + 60);
                        event.accepted = true;
                    }
                    propagateComposedEvents: true
                    onPressed: mouse.accepted = false
                    onReleased: mouse.accepted = false
                    onPositionChanged: mouse.accepted = false
                    onClicked: mouse.accepted = false
                }

                Column {
                    x: 0; y: 0
                    Repeater {
                        model: root.totalSlots
                        delegate: Item {
                            required property int index
                            width: flick.width
                            height: root.slotHeight
                            StyledText {
                                x: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    var h = root.startHour + index;
                                    if (h === 0 || h === 24) return "12 AM";
                                    if (h === 12) return "12 PM";
                                    if (h < 12) return h + " AM";
                                    return (h - 12) + " PM";
                                }
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }

                Repeater {
                    model: root.days
                    delegate: Item {
                        required property var modelData
                        required property int index
                        x: root.timeColumnWidth + root.spacing + index * (root.dayColumnWidth + root.spacing)
                        width: root.dayColumnWidth
                        height: root.contentHeight

                        property var timedEvents: {
                            if (!modelData.events) return [];
                            var r = [];
                            for (var i = 0; i < modelData.events.length; i++) {
                                if (!root.isAllDayEvent(modelData.events[i])) r.push(modelData.events[i]);
                            }
                            return r;
                        }

                        Repeater {
                            model: root.totalSlots
                            delegate: Rectangle {
                                required property int index
                                x: 0; y: index * root.slotHeight
                                width: parent.width; height: 1
                                color: Appearance.colors.colOutlineVariant; opacity: 0.25
                            }
                        }

                        Rectangle {
                            visible: index === root.currentDayIndex && root.weekOffset === 0
                            anchors.fill: parent
                            color: Qt.alpha(Appearance.colors.colPrimary, 0.04)
                        }

                        Repeater {
                            model: timedEvents
                            delegate: Rectangle {
                                required property var modelData
                                property int startMin: root.parseTimeToMinutes(modelData.start) || 0
                                property int endMin: root.parseTimeToMinutes(modelData.end) || (startMin + 60)
                                property int durMin: Math.max(endMin - startMin, 15)

                                x: 1; width: parent.width - 2
                                y: (startMin - root.startHour * 60) * root.pixelsPerMinute
                                height: Math.max(durMin * root.pixelsPerMinute, 16)
                                radius: Appearance.rounding.small
                                color: Qt.alpha(modelData.color || Appearance.colors.colPrimary, 0.2)
                                border.width: 1
                                border.color: Qt.alpha(modelData.color || Appearance.colors.colPrimary, 0.4)

                                StyledText {
                                    anchors.left: parent.left; anchors.leftMargin: 5
                                    anchors.right: parent.right; anchors.rightMargin: 3
                                    anchors.top: parent.top; anchors.topMargin: 2
                                    text: modelData.title || ""
                                    font.pixelSize: Appearance.font.pixelSize.smaller; font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnLayer0
                                    elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap
                                }
                                StyledText {
                                    anchors.left: parent.left; anchors.leftMargin: 5
                                    anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                                    visible: parent.height > 32
                                    text: (modelData.start || "") + " - " + (modelData.end || "")
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    x: root.timeColumnWidth - 2
                    width: flick.width - root.timeColumnWidth + 4
                    height: 2
                    y: root.currentTimeY
                    visible: root.currentTimeY >= 0 && root.currentTimeY <= root.contentHeight && root.weekOffset === 0
                    color: Appearance.colors.colError; z: 10
                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: Appearance.colors.colError
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: -3
                    }
                }
            }
        }
    }
}
