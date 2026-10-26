pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions

/**
 * One shared `cava` capture for every visualizer in the shell.
 *
 * The bar pill, the desktop media widget, the desktop visualizer and the media controls
 * panel all used to spawn their own `cava`, so a single playing track meant two or three
 * audio-capture processes at once. Consumers now request the stream and share one process;
 * it stops as soon as the last of them lets go.
 */
Singleton {
    id: root

    /// Consumers currently drawing a visualizer. Kept as a count so that overlapping
    /// demand (bar + desktop widget + panel) doesn't stop the stream early.
    property int consumers: 0
    property list<real> points: []

    readonly property bool active: consumers > 0

    function acquire() {
        root.consumers += 1;
    }

    function release() {
        root.consumers = Math.max(0, root.consumers - 1);
    }

    Process {
        id: cavaProc
        running: root.active
        command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/raw_output_config.txt`]
        stdout: SplitParser {
            onRead: data => {
                root.points = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p));
            }
        }
        onRunningChanged: {
            if (!running) root.points = [];
        }
    }

    // Per-consumer demand so one widget changing its mind can't release the stream for the
    // others. Call from onChanged and Component.onCompleted; release on destruction so a
    // destroyed widget can't pin the process.
    property var demand: ({})

    function setDemand(key, want) {
        const had = root.demand[key] === true;
        if (want === had) return;
        const next = Object.assign({}, root.demand);
        next[key] = want;
        root.demand = next;
        if (want) root.acquire();
        else root.release();
    }
}
