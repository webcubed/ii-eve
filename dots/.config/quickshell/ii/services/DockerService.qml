pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property bool dockerAvailable: false
    property bool dockerRunning: false
    property bool isLoading: false
    property var containers: []
    property int runningCount: 0
    property real totalMemoryMb: 0

    property string _lastSerializedContainers: ""
    property var _memStats: ({})

    readonly property bool _enabled: Config?.options?.resources?.enableDocker ?? false

    Component.onCompleted: {
        if (!root._enabled) return
        _silentRefresh()
        eventsProc.running = true
    }

    on_EnabledChanged: {
        if (root._enabled) {
            _silentRefresh()
            eventsProc.running = true
        } else {
            eventsProc.running = false
            serviceStatusProc.running = false
            fetchProc.running = false
            memStatsProc.running = false
            availabilityProc.running = false
            root.isLoading = false
            _applyEmptyContainers()
            root.dockerAvailable = false
            root.dockerRunning = false
        }
    }

    function refresh() {
        if (!root._enabled) return
        root.isLoading = true
        _startAvailabilityCheck()
        _startServiceCheck()
    }

    function refreshForPopup() {
        if (!root._enabled) return
        _silentRefresh()
        _startMemStats()
    }

    function _silentRefresh() {
        if (!root._enabled) return
        _startAvailabilityCheck()
        _startServiceCheck()
    }

    function _startAvailabilityCheck() {
        availabilityProc.running = false
        availabilityProc.running = true
    }

    Process {
        id: availabilityProc
        command: ["docker", "info"]
        running: false
        stdout: StdioCollector {}
        onExited: code => {
            root.dockerAvailable = (code === 0)
            if (root.dockerAvailable) {
                _startFetch()
            } else {
                _applyEmptyContainers()
                root.isLoading = false
            }
        }
    }

    function _startServiceCheck() {
        serviceStatusProc.running = false
        serviceStatusProc.running = true
    }

    Process {
        id: serviceStatusProc
        command: ["/bin/sh", "-c", "/usr/bin/systemctl is-active docker 2>/dev/null"]
        running: false
        stdout: StdioCollector {}
        onExited: code => {
            root.dockerRunning = (code === 0)
        }
    }

    property Timer debounce: Timer {
        interval: 500
        repeat: false
        onTriggered: root._silentRefresh()
    }

    Process {
        id: eventsProc
        command: ["docker", "events", "--format", "json", "--filter", "type=container"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                try {
                    const ev = JSON.parse(data)
                    const act = ev.Status || ev.status || ""
                    if (["start", "stop", "die", "died", "kill", "restart", "pause", "unpause", "create", "destroy", "remove", "cleanup"].includes(act)) {
                        root.debounce.restart()
                    }
                } catch (_) {}
            }
        }
        onRunningChanged: {
            if (!running) restartEventsTimer.restart()
        }
    }

    Timer {
        id: restartEventsTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (root._enabled && root.dockerAvailable)
                eventsProc.running = true
        }
    }

    Timer {
        interval: 60000
        running: root._enabled && root.dockerAvailable
        repeat: true
        onTriggered: root._silentRefresh()
    }

    function _startFetch() {
        fetchProc.running = false
        fetchProc.running = true
    }

    function _applyEmptyContainers() {
        if (root._lastSerializedContainers !== "[]") {
            root._lastSerializedContainers = "[]"
            root.containers = []
        }
        root.runningCount = 0
    }

    Process {
        id: fetchProc
        command: ["sh", "-c", "docker container inspect $(docker container ls -aq) 2>/dev/null || echo '[]'"]
        running: false
        stdout: StdioCollector { id: fetchOut }
        onExited: code => {
            root.isLoading = false
            try {
                const raw = JSON.parse(fetchOut.text || "[]")
                const parsed = raw.map(c => {
                    const state = c.State?.Status || ""
                    const ports = []
                    const pb = c.NetworkSettings?.Ports || {}
                    for (const [cp, hbs] of Object.entries(pb)) {
                        if (hbs)
                            hbs.forEach(b => {
                                if (b.HostPort)
                                    ports.push({
                                        containerPort: cp,
                                        hostPort: b.HostPort,
                                        hostIp: b.HostIp || "0.0.0.0"
                                    })
                            })
                    }
                    const labels = c.Config?.Labels || {}
                    return {
                        id: c.Id || "",
                        shortId: (c.Id || "").slice(0, 12),
                        name: (c.Name || "").replace(/^\//, ""),
                        image: c.Config?.Image || "",
                        state: state,
                        isRunning: c.State?.Running || false,
                        isPaused: c.State?.Paused || false,
                        startedAt: c.State?.StartedAt || "",
                        ports: ports,
                        composeProject: labels["com.docker.compose.project"] || "",
                        composeService: labels["com.docker.compose.service"] || "",
                        composeWorkingDir: labels["com.docker.compose.project.working_dir"] || "",
                        composeConfigFiles: labels["com.docker.compose.project.config_files"] || "compose.yaml"
                    }
                }).filter(c => c !== null).sort((a, b) => {
                    const p = { running: 0, paused: 1 }
                    return (p[a.state] ?? 2) - (p[b.state] ?? 2) || a.name.localeCompare(b.name)
                })

                const serialized = JSON.stringify(parsed)
                if (root._lastSerializedContainers !== serialized) {
                    root._lastSerializedContainers = serialized
                    root.containers = parsed
                }
                root.runningCount = parsed.filter(c => c.isRunning).length
            } catch (e) {
                console.error("DockerService: parse error", e)
                _applyEmptyContainers()
            }
        }
    }

    function _startMemStats() {
        if (!root.dockerAvailable || root.runningCount === 0) return
        memStatsProc.running = false
        memStatsProc.running = true
    }

    Process {
        id: memStatsProc
        command: ["sh", "-c", "docker stats --no-stream --format '{{.ID}} {{.MemUsage}}' 2>/dev/null || true"]
        running: false
        stdout: StdioCollector { id: memStatsOut }
        onExited: {
            try {
                const lines = (memStatsOut.text || "").trim().split("\n")
                const map = {}
                let total = 0
                lines.forEach(line => {
                    const parts = line.trim().split(/\s+/)
                    if (parts.length < 2) return
                    const shortId = parts[0]
                    const memStr = parts[1] || "0B"
                    let mb = 0
                    const m = memStr.match(/^([\d.]+)([kKmMgGtT]i?B?)$/i)
                    if (m) {
                        const v = parseFloat(m[1])
                        const u = m[2].toLowerCase()
                        if (u.startsWith('k')) mb = v / 1024
                        else if (u.startsWith('m')) mb = v
                        else if (u.startsWith('g')) mb = v * 1024
                        else if (u.startsWith('t')) mb = v * 1024 * 1024
                        else mb = v / (1024 * 1024)
                    }
                    map[shortId] = mb
                    total += mb
                })
                const updated = root.containers.map(c => {
                    const mb = map[c.shortId] ?? map[c.id?.slice(0, 12)] ?? 0
                    return Object.assign({}, c, { memMb: mb })
                })
                root._memStats = map
                root.totalMemoryMb = total
                root.containers = updated
            } catch (e) {
                console.warn("DockerService: mem stats parse error", e)
            }
        }
    }

    function containerAction(id, action) {
        const cmds = {
            start: ["docker", "start", id],
            stop: ["docker", "stop", id],
            restart: ["docker", "restart", id],
            pause: ["docker", "pause", id],
            unpause: ["docker", "unpause", id]
        }
        if (cmds[action]) {
            Quickshell.execDetached(cmds[action])
            Qt.callLater(() => root.debounce.restart())
        }
    }

    function openLogs(containerId) {
        const script = [
            "if command -v kitty >/dev/null 2>&1; then kitty --hold -- docker logs -f " + containerId,
            "elif command -v alacritty >/dev/null 2>&1; then alacritty --hold -e docker logs -f " + containerId,
            "elif command -v foot >/dev/null 2>&1; then foot -e sh -c 'docker logs -f " + containerId + "; read -p \"Press Enter...\"'",
            "fi"
        ].join("\n")
        Quickshell.execDetached(["sh", "-c", script])
    }

    function openShell(containerId) {
        const script = [
            "if command -v kitty >/dev/null 2>&1; then kitty -- docker exec -it " + containerId + " sh",
            "elif command -v alacritty >/dev/null 2>&1; then alacritty -e docker exec -it " + containerId + " sh",
            "elif command -v foot >/dev/null 2>&1; then foot -e docker exec -it " + containerId + " sh",
            "fi"
        ].join("\n")
        Quickshell.execDetached(["sh", "-c", script])
    }

    function openInBrowser(port) {
        if (!port) return
        Qt.openUrlExternally("http://localhost:" + port)
    }

    function toggleDockerService(enable) {
        root.isLoading = true
        serviceToggleProc.command = ["/bin/sh", "-c", enable
            ? "pkexec /usr/bin/systemctl start docker.service docker.socket"
            : "pkexec /usr/bin/systemctl stop docker.service docker.socket"]
        serviceToggleProc.running = false
        serviceToggleProc.running = true
    }

    Process {
        id: serviceToggleProc
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: code => {
            toggleCheckTimer.restart()
        }
    }

    Timer {
        id: toggleCheckTimer
        interval: 2000
        repeat: false
        onTriggered: root.refresh()
    }
}
