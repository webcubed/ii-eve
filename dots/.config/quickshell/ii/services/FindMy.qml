pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

/**
 * FindMy - backend bridge for the Google Find My / Find Hub people widget.
 *
 * Starts the python daemon (scripts/findmy/findmy.py serve) on demand, keeps
 * it alive, polls its state.json, and exposes people / trails / areas of
 * interest / events to the widget. The Mapbox token (secret) is read from
 * KeyringStorage; session cookies are handled entirely by the daemon.
 */
Singleton {
    id: root

    readonly property string stateDirPath: FileUtils.trimFileProtocol(Directories.state) + "/findmy"
    readonly property string stateFilePath: root.stateDirPath + "/state.json"
    readonly property string wrapperPath: Quickshell.shellPath("scripts/findmy/findmy-venv.sh")
    readonly property string scriptPath: Quickshell.shellPath("scripts/findmy/findmy.py")

    // ---- config mirror (drives daemon start/reconfig)
    readonly property bool enabled: Config.options.sidebar.findMy.enable
    readonly property int pollIntervalSec: Math.max(10, Config.options.sidebar.findMy.pollIntervalSeconds)
    readonly property int trailMaxPoints: Math.max(50, Config.options.sidebar.findMy.trailMaxPoints)
    readonly property bool aoiNotify: Config.options.sidebar.findMy.aoiNotify
    readonly property string mapStyle: Config.options.sidebar.findMy.mapStyle

    // ---- live state (from state.json)
    property bool connected: false
    property bool authenticated: false
    property bool authenticating: false
    property string authError: ""
    property var people: []
    property var trails: {}
    property var aois: []
    property var events: []
    property int lastUpdated: 0
    property string lastActionMsg: ""
    property bool lastActionOk: true

    // ---- secret (Mapbox token)
    property bool mapboxTokenReady: false
    property string mapboxToken: ""

    // ---- notification bookkeeping
    property int _lastEventTs: 0
    property bool _firstStateSeen: false

    // ------------------------------------------------------------------ token
    function refreshToken() {
        const t = KeyringStorage.keyringData?.findMy?.mapboxToken || "";
        root.mapboxToken = t;
        root.mapboxTokenReady = t.length > 0;
    }

    function setMapboxToken(token: string): bool {
        if (typeof token !== "string" || token.length === 0) return false;
        KeyringStorage.setNestedField(["findMy", "mapboxToken"], token);
        root.refreshToken();
        return true;
    }

    function clearMapboxToken() {
        KeyringStorage.setNestedField(["findMy", "mapboxToken"], "");
        root.refreshToken();
    }

    // --------------------------------------------------------------- daemon
    function ensureRunning() {
        const stateDir = root.stateDirPath;
        const wrapper = root.wrapperPath;
        Quickshell.execDetached(["bash", "-c",
            `mkdir -p '${stateDir}'; ` +
            `if [ -f '${stateDir}/daemon.pid' ] && kill -0 $(cat '${stateDir}/daemon.pid' 2>/dev/null) 2>/dev/null; then ` +
            `echo already-running; ` +
            `else ` +
            `nohup setsid '${wrapper}' serve --interval ${root.pollIntervalSec} --trail-max ${root.trailMaxPoints} ` +
            `</dev/null >/dev/null 2>&1 & echo started; fi`]);
    }

    function login() {
        Quickshell.execDetached(["bash", "-c", `'${root.wrapperPath}' login`]);
    }

    function logout() {
        Quickshell.execDetached(["bash", "-c", `'${root.wrapperPath}' logout`]);
        root.authenticated = false;
        root.people = [];
        root.trails = {};
        root.events = [];
    }

    function refreshNow() {
        Quickshell.execDetached(["bash", "-c", `'${root.wrapperPath}' refresh`]);
    }

    function reconfig() {
        Quickshell.execDetached(["bash", "-c",
            `'${root.wrapperPath}' reconfig --interval ${root.pollIntervalSec} --trail-max ${root.trailMaxPoints}`]);
    }

    function addAoi(name: string, lat: real, lng: real, radiusKm: real) {
        Quickshell.execDetached(["bash", "-c",
            `'${root.wrapperPath}' aoi add '${StringUtils.shellSingleQuoteEscape(name)}' ${lat} ${lng} ${radiusKm}`]);
    }

    function removeAoi(nameOrId: string) {
        Quickshell.execDetached(["bash", "-c",
            `'${root.wrapperPath}' aoi rm '${StringUtils.shellSingleQuoteEscape(nameOrId)}'`]);
    }

    function clearTrails() {
        Quickshell.execDetached(["bash", "-c", `'${root.wrapperPath}' trail`]);
    }

    // ------------------------------------------------------------------ poll
    function poll() {
        if (root._pollRunning) return;
        root._pollRunning = true;
        stateProcess.command = ["bash", "-c", `cat '${root.stateFilePath}' 2>/dev/null`];
        stateProcess.running = true;
    }

    property bool _pollRunning: false

    Process {
        id: stateProcess
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            id: stateCollector
            onStreamFinished: {
                const raw = stateCollector.text.trim();
                root._pollRunning = false;
                if (raw.length === 0) {
                    root.connected = false;
                    return;
                }
                let data;
                try { data = JSON.parse(raw); } catch (e) { return; }
                root.connected = true;
                root.authenticated = !!data.authenticated;
                root.authenticating = !!data.authenticating;
                root.authError = data.authError || "";
                root.people = data.people || [];
                root.trails = data.trails || {};
                root.aois = data.aois || [];
                root.events = data.events || [];
                root.lastUpdated = data.lastUpdated || 0;
                root.lastActionMsg = data.lastActionMsg || "";
                root.lastActionOk = data.lastActionOk !== false;
                root._checkNewEvents();
            }
        }
    }

    // ---------------------------------------------------------- notifications
    function _checkNewEvents() {
        const list = root.events;
        if (root._firstLoadSeen && list.length > 0) {
            for (let i = 0; i < list.length; i++) {
                const ev = list[i];
                if (ev.ts <= root._lastEventTs) continue;
                root._lastEventTs = ev.ts;
                if (!root.aoiNotify) continue;
                const verb = ev.type === "enter" ? Translation.tr("entered") : Translation.tr("left");
                Quickshell.execDetached([
                    "notify-send",
                    Translation.tr("Find My"),
                    `${ev.person} ${verb} ${ev.aoi}`,
                    "-a", "Shell",
                ]);
            }
        } else if (list.length > 0) {
            root._lastEventTs = list[list.length - 1].ts;
            root._firstLoadSeen = true;
        }
    }

    // ------------------------------------------------------------ lifecycle
    Component.onCompleted: {
        root.refreshToken();
        root.ensureRunning();
    }

    Connections {
        target: KeyringStorage
        function onDataChanged() { root.refreshToken(); }
    }

    onPollIntervalSecChanged: root.reconfig()
    onTrailMaxPointsChanged: root.reconfig()

    Timer {
        running: true
        repeat: true
        interval: 1200
        triggeredOnStart: true
        onTriggered: root.poll()
    }

    Timer {
        running: true
        repeat: true
        interval: 15000
        triggeredOnStart: false
        onTriggered: root.ensureRunning() // self-heal if the daemon died
    }
}