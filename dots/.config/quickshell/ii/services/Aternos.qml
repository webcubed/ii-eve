pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var servers: []
    property bool loading: false
    property string lastError: ""
    property string lastOutput: ""
    property real startTimer: 0

    property var aternosPath: "/home/webcubed/aternos-cli/aternos"

    Timer {
        id: restartTimer
        interval: root.startTimer
        running: root.startTimer > 0
        repeat: false
        onTriggered: {
            root.startTimer = 0;
            let s = root.servers[0];
            if (s) root.startServer(s.address);
        }
    }

    function listServers() {
        root.loading = true;
        root.lastError = "";
        listServersProc.running = true;
    }

    function serverInfo(serverName) {
        root.loading = true;
        root.lastError = "";
        infoProc.serverArg = serverName || "";
        infoProc.running = true;
    }

    function startServer(serverName) {
        root.loading = true;
        root.lastError = "";
        startProc.serverArg = serverName || "";
        startProc.running = true;
    }

    function stopServer(serverName) {
        root.loading = true;
        root.lastError = "";
        stopProc.serverArg = serverName || "";
        stopProc.running = true;
    }

    function sendCommand(serverAddress, command) {
        root.lastError = "";
        commandProc.serverArg = serverAddress || "";
        commandProc.commandArg = command;
        commandProc.running = true;
    }

    Process {
        id: listServersProc
        command: [root.aternosPath, "list", "--json"]
        running: false
        property string buffer: ""
        stdout: SplitParser {
            onRead: data => {
                listServersProc.buffer += data + "\n";
            }
        }
        stderr: SplitParser {
            onRead: data => {
                if (data.toLowerCase().includes("browser") || data.toLowerCase().includes("trying")) return;
                root.lastError = data;
            }
        }
        onRunningChanged: {
            if (!running) {
                try {
                    let parsed = JSON.parse(buffer);
                    root.servers = parsed;
                } catch (e) {
                    console.log("[Aternos] Failed to parse list output:", e, "\nBuffer:", buffer);
                    root.lastError = e.toString();
                }
                buffer = "";
                root.loading = false;
            }
        }
    }

    Process {
        id: infoProc
        property string serverArg: ""
        command: [root.aternosPath, "info", serverArg].filter(s => s !== "")
        running: false
        stdout: SplitParser {
            onRead: data => {}
        }
        stderr: SplitParser {
            onRead: data => {
                if (data.toLowerCase().includes("browser") || data.toLowerCase().includes("trying")) return;
                root.lastError = data;
            }
        }
        onRunningChanged: {
            if (!running) root.loading = false;
        }
    }

    Process {
        id: startProc
        property string serverArg: ""
        command: [root.aternosPath, "start", serverArg].filter(s => s !== "")
        running: false
        stdout: SplitParser {
            onRead: data => {}
        }
        stderr: SplitParser {
            onRead: data => {
                if (data.toLowerCase().includes("browser") || data.toLowerCase().includes("trying")) return;
                root.lastError = data;
            }
        }
        onRunningChanged: {
            if (!running) {
                root.loading = false;
                root.listServers();
            }
        }
    }

    Process {
        id: stopProc
        property string serverArg: ""
        command: [root.aternosPath, "stop", serverArg].filter(s => s !== "")
        running: false
        stdout: SplitParser {
            onRead: data => {}
        }
        stderr: SplitParser {
            onRead: data => {
                if (data.toLowerCase().includes("browser") || data.toLowerCase().includes("trying")) return;
                root.lastError = data;
            }
        }
        onRunningChanged: {
            if (!running) {
                root.loading = false;
                root.listServers();
            }
        }
    }

    Process {
        id: commandProc
        property string serverArg: ""
        property string commandArg: ""
        property string buffer: ""
        command: [root.aternosPath, "cmd", serverArg, commandArg].filter(s => s !== "")
        running: false
        stdout: SplitParser {
            onRead: data => {
                commandProc.buffer += data + "\n";
            }
        }
        stderr: SplitParser {
            onRead: data => {
                root.lastError = data;
            }
        }
        onRunningChanged: {
            if (!running) {
                root.lastOutput = buffer.trim();
                buffer = "";
                root.loading = false;
            }
        }
    }

    Component.onCompleted: {
        listServers();
    }
}
