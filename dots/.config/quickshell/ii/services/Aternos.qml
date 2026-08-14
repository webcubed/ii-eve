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

    property var aternosPath: "/home/webcubed/aternos-cli/aternos"

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

    Component.onCompleted: {
        listServers();
    }
}
