import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Qt5Compat.GraphicalEffects

Item {
    id: root

    // Standard signals used by the policies panel (SwipeView navigation)
    signal navigateLeft()
    signal navigateRight()
    signal navigateNext()
    signal navigatePrev()

    property bool addAoiMode: false
    property string selectedPersonId: ""
    property bool showTrails: Config.options.sidebar.findMy.showTrails

    readonly property bool authenticated: FindMy.authenticated
    readonly property bool hasToken: FindMy.mapboxTokenReady
    readonly property color accent: Appearance.colors.colPrimary

    // ------------------------------------------------------------------ map
    // Web Mercator helpers
    function projectY(lat: real, zoom: int): real {
        const s = Math.sin(lat * Math.PI / 180);
        return (0.5 - Math.log((1 + s) / (1 - s)) / (4 * Math.PI)) * Math.pow(2, zoom);
    }
    function unprojectY(tileY: real, zoom: real): real {
        const n = Math.PI * (1 - 2 * tileY / Math.pow(2, zoom));
        return 180 / Math.PI * Math.atan(0.5 * (Math.exp(n) - Math.exp(-n)));
    }

    component SlippyMap: Item {
        id: map
        required property real centerLat
        required property real centerLng
        required property int zoom
        required property string token
        required property var people
        required property var trails
        required property var aois
        required property string selectedPersonId
        required property bool addAoiMode
        required property bool showTrails
        property bool ready: map.token.length > 0 && map.people !== null
        signal aoiChosen(real lat, real lng)
        signal personPicked(string id)

        property int minZoom: 2
        property int maxZoom: 16
        property var tileItems: []
        property var _dragStart: null

        // ---- geometry
        readonly property real worldPx: 256 * Math.pow(2, map.zoom)
        readonly property real centerX: (map.centerLng + 180) / 360 * Math.pow(2, map.zoom)
        readonly property real centerY: root.projectY(map.centerLat, map.zoom)

        // ---- overlays
        Rectangle {
            anchors.fill: parent
            color: "#0e1116"
            visible: !map.ready
            StyledText {
                anchors.centerIn: parent
                text: Translation.tr("Add a Mapbox token in Settings → Find My")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }

        Item {
            id: tileLayer
            anchors.fill: parent
            clip: true
            Repeater {
                model: map.tileItems
                delegate: Image {
                    x: modelData.px
                    y: modelData.py
                    width: 256
                    height: 256
                    source: root.tileUrl(modelData.z, modelData.x, modelData.y)
                    visible: map.ready
                }
            }
        }

        Canvas {
            id: overlay
            anchors.fill: parent
            visible: map.ready

            Connections {
                target: map
                function onCenterLatChanged() { overlay.requestPaint(); }
                function onCenterLngChanged() { overlay.requestPaint(); }
                function onZoomChanged() { overlay.requestPaint(); }
                function onPeopleChanged() { overlay.requestPaint(); }
                function onTrailsChanged() { overlay.requestPaint(); }
                function onAoisChanged() { overlay.requestPaint(); }
                function onSelectedPersonIdChanged() { overlay.requestPaint(); }
                function onAddAoiModeChanged() { overlay.requestPaint(); }
                function onShowTrailsChanged() { overlay.requestPaint(); }
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (!map.ready) return;
                const z = map.zoom;
                const cx0 = map.centerX * 256;
                const cy0 = map.centerY * 256;
                const x0 = width / 2 - cx0;
                const y0 = height / 2 - cy0;
                const px = (lat, lng) => x0 + (lng + 180) / 360 * Math.pow(2, z) * 256;
                const py = (lat) => y0 + map.projectY(lat, z) * 256;
                const metersPerPixel = 156543.03392 * Math.cos(map.centerLat * Math.PI / 180) / Math.pow(2, z);

                // trails
                if (map.showTrails) {
                    for (const key in map.trails) {
                        const pts = map.trails[key];
                        if (!pts || pts.length < 2) continue;
                        ctx.beginPath();
                        for (let i = 0; i < pts.length; i++) {
                            const sx = px(pts[i].lat, pts[i].lng);
                            const sy = py(pts[i].lat);
                            if (i === 0) ctx.moveTo(sx, sy); else ctx.lineTo(sx, sy);
                        }
                        ctx.strokeStyle = "rgba(102, 187, 255, 0.65)";
                        ctx.lineWidth = 2;
                        ctx.stroke();
                    }
                }

                // areas of interest
                for (const a of map.aois) {
                    const sx = px(a.lat, a.lng);
                const sy = py(a.lat);
                const r = Math.max(8, a.radius_km * 1000 / metersPerPixel);
                    ctx.beginPath();
                    ctx.arc(sx, sy, r, 0, 2 * Math.PI);
                    ctx.fillStyle = "rgba(66, 133, 244, 0.16)";
                    ctx.fill();
                    ctx.strokeStyle = "rgba(66, 133, 244, 0.75)";
                    ctx.lineWidth = 1.5;
                    ctx.stroke();
                    ctx.fillStyle = "rgba(210, 227, 252, 0.85)";
                    ctx.font = "11px sans-serif";
                    ctx.fillText(a.name, sx + r + 4, sy - 4);
                }

                // people
                for (const p of map.people) {
                    const sx = px(p.lat, p.lng);
                    const sy = py(p.lat);
                    const sel = p.id === map.selectedPersonId;
                    ctx.beginPath();
                    ctx.arc(sx, sy, sel ? 8 : 6, 0, 2 * Math.PI);
                    ctx.fillStyle = p.battery !== null && p.battery <= 20 ? "#ff8a65" : "#a9c7ff";
                    ctx.fill();
                    ctx.strokeStyle = sel ? "#ffffff" : "rgba(10, 14, 20, 0.85)";
                    ctx.lineWidth = sel ? 2.5 : 1.5;
                    ctx.stroke();
                    ctx.fillStyle = "rgba(230, 240, 255, 0.9)";
                    ctx.font = "11px sans-serif";
                    ctx.fillText(p.name, sx + 8, sy - (sel ? 8 : 6));
                }
            }
        }

        // ---- input
        MouseArea {
            id: input
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            property real lastX: 0
            property real lastY: 0

            onPressed: (mouse) => {
                map._dragStart = { x: mouse.x, y: mouse.y };
            }

            onPositionChanged: (mouse) => {
                if (!map._dragStart) return;
                const dx = mouse.x - map._dragStart.x;
                const dy = mouse.y - map._dragStart.y;
                if (Math.abs(dx) < 2 && Math.abs(dy) < 2) return;
                panBy(dx, dy);
                map._dragStart = { x: mouse.x, y: mouse.y };
            }

            onReleased: (mouse) => {
                if (map._dragStart) {
                    const dx = mouse.x - map._dragStart.x;
                    const dy = mouse.y - map._dragStart.y;
                    if (Math.abs(dx) < 2 && Math.abs(dy) < 2) {
                        // click
                        if (map.addAoiMode) {
                            const ll = screenToLatLng(mouse.x, mouse.y);
                            map.aoiChosen(ll.lat, ll.lng);
                        } else {
                            const hit = pickPerson(mouse.x, mouse.y);
                            map.personPicked(hit || "");
                        }
                    }
                }
                map._dragStart = null;
            }

            function panBy(dxMany, dyMany) {
                const n = Math.pow(2, map.zoom);
                map.centerLng = clampLng(map.centerLng - dxMany / 256 / n * 360);
                map.centerLat = map.unprojectY(map.projectY(map.centerLat, map.zoom) - dyMany / 256, map.zoom);
            }

            function screenToLatLng(sx, sy) {
                const z = map.zoom;
                const n = Math.pow(2, z);
                const cx0 = map.centerX * 256;
                const cy0 = map.centerY * 256;
                const tx = (cx0 - width / 2 + sx) / 256;
                const ty = (cy0 - height / 2 + sy) / 256;
                return { lat: map.unprojectY(ty, z), lng: tx / n * 360 - 180 };
            }

            function pickPerson(sx, sy) {
                const z = map.zoom;
                const n = Math.pow(2, z);
                const cx = map.centerX * 256;
                const cy = map.centerY * 256;
                const x0 = width / 2 - cx;
                const y0 = height / 2 - cy;
                let best = "";
                let bestDist = 36;
                for (const p of map.people) {
                    const pxA = x0 + (p.lng + 180) / 360 * n * 256;
                    const pyP = y0 + map.projectY(p.lat, z) * 256;
                    const d = Math.hypot(pxA - sx, pyP - sy);
                    if (d < bestDist) { bestDist = d; best = p.id; }
                }
                return best;
            }

            onWheel: (wheel) => {
                const newZoom = Math.max(map.minZoom, Math.min(map.maxZoom, map.zoom + (wheel.angleDelta.y > 0 ? 1 : -1)));
                if (newZoom === map.zoom) return;
                map.zoom = newZoom;
            }
        }

        // helpers
        function clampLng(lng: real): real {
            while (lng < -180) lng += 360;
            while (lng > 180) lng -= 360;
            return lng;
        }
        function unprojectY(tileY: real, zoom: real): real {
            const n = Math.PI * (1 - 2 * tileY / Math.pow(2, zoom));
            return 180 / Math.PI * Math.atan(0.5 * (Math.exp(n) - Math.exp(-n)));
        }
        function projectY(lat: real, zoom: real): real {
            const s = Math.sin(lat * Math.PI / 180);
            return (0.5 - Math.log((1 + s) / (1 - s)) / (4 * Math.PI)) * Math.pow(2, zoom);
        }

        function refreshTiles() {
            const list = [];
            if (!map.ready || map.zoom < 2 || width <= 0 || height <= 0) return;
            const z = map.zoom;
            const n = Math.pow(2, z);
            const cx = map.centerX * 256;
            const cy = map.centerY * 256;
            const x0 = Math.floor((cx - width / 2) / 256);
            const x1 = Math.ceil((cx + width / 2) / 256);
            const y0 = Math.floor((cy - height / 2) / 256);
            const y1 = Math.ceil((cy + height / 2) / 256);
            for (let x = x0; x <= x1; x++) {
                const wx = ((x % n) + n) % n;
                for (let y = y0; y <= y1; y++) {
                    const wy = ((y % n) + n) % n;
                    list.push({ z: z, x: wx, y: wy, px: x * 256 - cx + width / 2, py: y * 256 - cy + height / 2 });
                }
            }
            map.tileItems = list;
        }
        onReadyChanged: map.refreshTiles()
        onTokenChanged: map.refreshTiles()
        onCenterLatChanged: map.refreshTiles()
        onCenterLngChanged: map.refreshTiles()
        onZoomChanged: map.refreshTiles()
        onWidthChanged: map.refreshTiles()
        onHeightChanged: map.refreshTiles()
    }

    // page-level map center state
    property real mapCenterLat: 40.712775
    property real mapCenterLng: -74.005973
    property int mapZoom: 12

    // Mapbox raster tile source (styles endpoint serves 256px PNGs)
    function tileUrl(z: int, x: int, y: int): string {
        const style = Config.options.sidebar.findMy.mapStyle || "dark-v10";
        return `https://api.mapbox.com/styles/v1/mapbox/${style}/tiles/256/${z}/${x}/${y}?access_token=${FindMy.mapboxToken}`;
    }

    function flyTo(lat, lng, zoom) {
        root.mapCenterLat = lat;
        root.mapCenterLng = lng;
        root.mapZoom = zoom;
    }

    property real _aoiPendingLat: 0
    property real _aoiPendingLng: 0

    function openAoiDialog(lat, lng) {
        root._aoiPendingLat = lat;
        root._aoiPendingLng = lng;
        aoiDialog.visible = true;
    }
    function fitPeople() {
        const ps = FindMy.people;
        if (ps.length === 0) { root.mapZoom = 12; return; }
        flyTo(ps[0].lat, ps[0].lng, 13);
    }
    function relTime(tsMs) {
        if (!tsMs) return "";
        const diffSec = Math.floor((Date.now() - tsMs) / 1000);
        if (diffSec < 60) return Translation.tr("%1s ago").arg(Math.max(0, diffSec));
        if (diffSec < 3600) return Translation.tr("%1m ago").arg(Math.floor(diffSec / 60));
        if (diffSec < 86400) return Translation.tr("%1h ago").arg(Math.floor(diffSec / 3600));
        return Translation.tr("%1d ago").arg(Math.floor(diffSec / 86400));
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // ----------------------------------------------------------- status
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: statusRow.implicitHeight + 8
            radius: Appearance.rounding.small
            color: root.authenticated ? Appearance.colors.colLayer3 : Appearance.colors.colErrorContainer
            visible: !root.authenticated || FindMy.authError

            RowLayout {
                id: statusRow
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                spacing: 4
                MaterialSymbol {
                    text: root.authenticated ? "check_circle" : "account_circle"
                    iconSize: 16
                    color: root.authenticated ? Appearance.colors.colPrimary : Appearance.colors.colOnErrorContainer
                }
                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: root.authenticated
                        ? Translation.tr("Connected · %1").arg(root.relTime(FindMy.lastUpdated))
                        : (FindMy.authenticating ? Translation.tr("Waiting for sign-in… open the browser and grant access, then share location with this account.")
                                                 : Translation.tr("Not signed in — open your browser to sign in."))
                    color: root.authenticated ? Appearance.colors.colOnLayer2 : Appearance.colors.colOnErrorContainer
                    font.pixelSize: Appearance.font.pixelSize.small
                }
                RippleButtonWithIcon {
                    materialIcon: "login"
                    mainText: Translation.tr("Login")
                    onClicked: FindMy.login()
                }
            }
        }

        // -------------------------------------------------------------- map
        Rectangle {
            id: mapshell
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1
            clip: true

            SlippyMap {
                id: view
                anchors.fill: parent
                centerLat: root.mapCenterLat
                centerLng: root.mapCenterLng
                zoom: root.mapZoom
                token: FindMy.mapboxToken
                people: FindMy.people
                trails: FindMy.trails
                aois: FindMy.aois
                selectedPersonId: root.selectedPersonId
                addAoiMode: root.addAoiMode
                showTrails: root.showTrails
                onAoiChosen: (lat, lng) => root.openAoiDialog(lat, lng)
                onPersonPicked: (id) => root.selectedPersonId = id
            }

            // token / auth blocking overlays
            Rectangle {
                anchors.fill: parent
                color: "#0e1116cc"
                visible: !FindMy.mapboxTokenReady || !root.authenticated
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: !FindMy.mapboxTokenReady ? "map" : (FindMy.authenticating ? "hourglass_top" : "no_accounts")
                        iconSize: 48
                        color: Appearance.colors.colPrimary
                    }
                    StyledText {
                        Layout.preferredWidth: 260
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: !FindMy.mapboxTokenReady
                            ? Translation.tr("Set your Mapbox access token to show the map (Settings → Find My).")
                            : (FindMy.authenticating
                                ? Translation.tr("Waiting for you to finish signing in and sharing your location…")
                                : Translation.tr("No Google session yet. Sign in and allow location sharing, then press Login here."))
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                    RippleButtonWithIcon {
                        Layout.alignment: Qt.AlignHCenter
                        materialIcon: !FindMy.mapboxTokenReady ? "settings" : "login"
                        mainText: !FindMy.mapboxTokenReady ? Translation.tr("Open Settings") : Translation.tr("Login with Browser")
                        onClicked: {
                            if (!FindMy.mapboxTokenReady) {
                                Quickshell.execDetached(["qs", "-p", Quickshell.shellPath("settings.qml")]);
                            } else {
                                FindMy.login();
                            }
                        }
                    }
                }
            }

            // add-AOI hint
            Rectangle {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 8
                visible: root.addAoiMode
                color: Appearance.colors.colPrimaryContainer
                radius: Appearance.rounding.full
                implicitHeight: hintText.implicitHeight + 8
                implicitWidth: hintText.implicitWidth + 20
                StyledText {
                    id: hintText
                    anchors.centerIn: parent
                    text: Translation.tr("Click the map to place the AOI center")
                    color: Appearance.colors.colOnPrimaryContainer
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
        }

        // ------------------------------------------------------ map toolbar
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            IconToolbarButton { text: "zoom_in"; onClicked: root.mapZoom = Math.min(16, root.mapZoom + 1) }
            IconToolbarButton { text: "zoom_out"; onClicked: root.mapZoom = Math.max(2, root.mapZoom - 1) }
            IconToolbarButton { text: "my_location"; onClicked: root.fitPeople() }
            IconToolbarButton {
                text: "add_location_alt"
                toggled: root.addAoiMode
                onClicked: root.addAoiMode = !root.addAoiMode
            }
            IconToolbarButton {
                text: "timeline"
                toggled: root.showTrails
                onClicked: root.showTrails = !root.showTrails
            }
            Item { Layout.fillWidth: true }
            IconToolbarButton { text: "refresh"; onClicked: FindMy.refreshNow() }
            IconToolbarButton { text: "logout"; onClicked: FindMy.logout() }
        }

        // -------------------------------------------------- people list
        StyledText {
            visible: FindMy.people.length > 0
            text: Translation.tr("People")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
        ListView {
            id: peopleList
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(220, 64 + FindMy.people.length * 64)
            visible: FindMy.people.length > 0 && root.authenticated
            clip: true
            spacing: 6
            model: FindMy.people
            delegate: Rectangle {
                width: ListView.view.width
                implicitHeight: 58
                radius: Appearance.rounding.small
                color: root.selectedPersonId === modelData.id ? Appearance.colors.colLayer3 : Appearance.colors.colLayer2
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8
                    Rectangle {
                        implicitWidth: 10
                        implicitHeight: 10
                        radius: 5
                        color: modelData.battery !== null && modelData.battery <= 20 ? "#ff8a65" : Appearance.colors.colPrimary
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        StyledText {
                            text: modelData.name
                            color: Appearance.colors.colOnLayer2
                            font.pixelSize: Appearance.font.pixelSize.small
                            elide: Text.ElideRight
                        }
                        StyledText {
                            text: [modelData.address, modelData.battery !== null ? (modelData.battery + "%") : ""].filter(Boolean).join(" · ")
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            elide: Text.ElideRight
                        }
                    }
                    StyledText {
                        text: root.relTime(modelData.updated_ms) || ""
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                    IconToolbarButton { text: "near_me"; onClicked: root.flyTo(modelData.lat, modelData.lng, 13) }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { root.selectedPersonId = modelData.id; root.flyTo(modelData.lat, modelData.lng, Math.max(root.mapZoom, 14)); }
                }
            }
        }

        // ------------------------------------------------------ areas of interest
        ColumnLayout {
            visible: FindMy.aois.length > 0
            Layout.fillWidth: true
            spacing: 4
            StyledText {
                text: Translation.tr("Areas of interest")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
            Repeater {
                model: FindMy.aois
                delegate: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colLayer3
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 4
                        anchors.topMargin: 2
                        anchors.bottomMargin: 2
                        spacing: 6
                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.name
                            color: Appearance.colors.colOnLayer2
                            font.pixelSize: Appearance.font.pixelSize.small
                            elide: Text.ElideRight
                        }
                        StyledText {
                            text: Translation.tr("%1 km").arg(modelData.radius_km)
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                        IconToolbarButton {
                            text: "close"
                            implicitHeight: 26
                            implicitWidth: 26
                            onClicked: FindMy.removeAoi(modelData.id)
                        }
                    }
                }
            }
        }
    }

    // --------------------------------------------------------- AOI creation
    Rectangle {
        id: aoiDialog
        anchors.fill: parent
        visible: false
        z: 99
        color: "#80000000"
        function open() { visible = true; }
        Rectangle {
            anchors.centerIn: parent
            width: 300
            height: 270
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10
                StyledText {
                    text: Translation.tr("New area of interest")
                    color: Appearance.colors.colOnLayer0
                    font.pixelSize: Appearance.font.pixelSize.normal
                }
                MaterialTextField {
                    id: aoiNameField
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Name (e.g. Home, Office)")
                }
                MaterialTextField {
                    id: aoiRadiusField
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Radius (km)")
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                }
                StyledText {
                    text: Translation.tr("Center: %1, %2").arg(root._aoiPendingLat.toFixed(5)).arg(root._aoiPendingLng.toFixed(5))
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Item { Layout.fillWidth: true }
                    RippleButtonWithIcon {
                        materialIcon: "close"
                        mainText: Translation.tr("Cancel")
                        onClicked: { aoiDialog.visible = false; root.addAoiMode = false; }
                    }
                    RippleButtonWithIcon {
                        materialIcon: "check"
                        mainText: Translation.tr("Add")
                        onClicked: {
                            const r = parseFloat(aoiRadiusField.text.replace(",", ".")) || 1;
                            FindMy.addAoi(aoiNameField.text.trim() || Translation.tr("Area"), root._aoiPendingLat, root._aoiPendingLng, r);
                            aoiDialog.visible = false;
                            root.addAoiMode = false;
                        }
                    }
                }
            }
        }
    }
}