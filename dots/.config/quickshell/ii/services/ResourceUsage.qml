pragma Singleton
pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Simple polled resource usage service with RAM, Swap, and CPU usage.
 */
Singleton {
    id: root
	property real memoryTotal: 1
	property real memoryFree: 0
	property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryUsed / memoryTotal
    property real swapTotal: 1
	property real swapFree: 0
	property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property real diskTotal: 1
    property real diskUsed: 0
    property real diskUsedPercentage: diskTotal > 0 ? (diskUsed / diskTotal) : 0
    property real cpuUsage: 0
    property var previousCpuStats
    property string cpuModel: "Unknown CPU"
    property string cpuFreq: "-- MHz"
    property string cpuTemp: "--°C"
    property real gpuUsage: 0
    property string gpuTemp: "--°C"
    property string gpuModel: "Unknown GPU"

    property real netRxBytesPerSec: 0
    property real netTxBytesPerSec: 0
    property var previousNetStats: null
    property list<real> netRxHistory: []
    property list<real> netTxHistory: []

    property string maxAvailableMemoryString: kbToGbString(ResourceUsage.memoryTotal)
    property string maxAvailableSwapString: kbToGbString(ResourceUsage.swapTotal)
    property string maxAvailableCpuString: "--"

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    property list<real> cpuUsageHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }
    function formatNetSpeed(bytesPerSec) {
        if (bytesPerSec >= 1024 * 1024)
            return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s"
            if (bytesPerSec >= 1024)
                return (bytesPerSec / 1024).toFixed(0) + " KB/s"
                return bytesPerSec.toFixed(0) + " B/s"
    }
    function updateMemoryUsageHistory() {
        memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage]
        if (memoryUsageHistory.length > historyLength) {
            memoryUsageHistory.shift()
        }
    }
    function updateSwapUsageHistory() {
        swapUsageHistory = [...swapUsageHistory, swapUsedPercentage]
        if (swapUsageHistory.length > historyLength) {
            swapUsageHistory.shift()
        }
    }
    function updateCpuUsageHistory() {
        cpuUsageHistory = [...cpuUsageHistory, cpuUsage]
        if (cpuUsageHistory.length > historyLength) {
            cpuUsageHistory.shift()
        }
    }
    function updateNetHistory() {
        netRxHistory = [...netRxHistory, netRxBytesPerSec]
        if (netRxHistory.length > historyLength) netRxHistory.shift()
        netTxHistory = [...netTxHistory, netTxBytesPerSec]
        if (netTxHistory.length > historyLength) netTxHistory.shift()
    }
    function updateHistories() {
        updateMemoryUsageHistory()
        updateSwapUsageHistory()
        updateCpuUsageHistory()
    }

    // Poll only while a consumer can actually be seen: the bar (unloaded when
    // hidden/locked, live widgets culled in fullscreen), the background
    // resources widget (occluded → unload, fullscreen → hidden), or the
    // dashboard resources section.
    readonly property bool pollingVisible: {
        const bar = GlobalStates.barOpen && !GlobalStates.screenLocked && !GlobalStates.fullscreenActive;
        const bg = Config.ready && (Config.options.background.widgets.resources?.enable ?? false)
            && GlobalStates.widgetsVisible && !GlobalStates.fullscreenActive;
        return bar || bg || GlobalStates.dashboardPanelOpen;
    }

	Timer {
		interval: Config.options?.resources?.updateInterval ?? 3000
        running: root.pollingVisible
        repeat: true
		onTriggered: {
            // Reload files
            fileMeminfo.reload()
            fileStat.reload()

            // Parse memory and swap usage
            const textMeminfo = fileMeminfo.text()
            memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
            memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
            swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1)
            swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)

            // Parse CPU usage
            const textStat = fileStat.text()
            const cpuLine = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
            if (cpuLine) {
                const stats = cpuLine.slice(1).map(Number)
                const total = stats.reduce((a, b) => a + b, 0)
                const idle = stats[3]

                if (previousCpuStats) {
                    const totalDiff = total - previousCpuStats.total
                    const idleDiff = idle - previousCpuStats.idle
                    cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
                }

                previousCpuStats = { total, idle }
            }

            // Parse CPU info
            fileCpuInfo.reload()
            const textCpu = fileCpuInfo.text()
            if (root.cpuModel === "Unknown CPU" && textCpu.length > 0) {
                const modelMatch = textCpu.match(/model name\s+:\s+(.*)/)
                if (!modelMatch) return
                // i hope these are enough to shorten the string
                root.cpuModel = modelMatch[1]
                    .replace(/\(.*?\)/g, "")              // (R), (TM) vs
                    .replace(/with.*$/i, "")              // with Radeon...
                    .replace(/@\s*[\d.]+\s*GHz/i, "")     // @ 2.60GHz
                    .replace(/\b\d+-Core\b/gi, "")        // 6-Core
                    .replace(/\b\d+\s*Cores?\b/gi, "")    // 6 Cores
                    .replace(/\b\d+th\s+Gen\b/gi, "")     // Xth Gen
                    .replace(/\bCPU\b/gi, "")
                    .replace(/\bProcessor\b/gi, "")
                    .replace(/\s+/g, " ")
                    .trim() 
            }
            const freqMatch = textCpu.match(/cpu MHz\s+:\s+([\d.]+)/)
            if (freqMatch) root.cpuFreq = parseInt(freqMatch[1]) + " MHz"

            root.updateHistories()

            fileNetDev.reload()
            const textNetDev = fileNetDev.text()
            let totalRx = 0, totalTx = 0
            const lines = textNetDev.split("\n")
            for (const line of lines) {
                const m = line.trim().match(/^(\w+):\s+(\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)/)
                if (m && m[1] !== "lo") {
                    totalRx += parseInt(m[2])
                    totalTx += parseInt(m[3])
                }
            }
            const intervalSec = (Config.options?.resources?.updateInterval ?? 3000) / 1000
            if (root.previousNetStats) {
                root.netRxBytesPerSec = Math.max(0, (totalRx - root.previousNetStats.rx) / intervalSec)
                root.netTxBytesPerSec = Math.max(0, (totalTx - root.previousNetStats.tx) / intervalSec)
            }
            root.previousNetStats = { rx: totalRx, tx: totalTx }
            root.updateNetHistory()
        }
	}

	FileView { id: fileMeminfo; path: "/proc/meminfo" }
    FileView { id: fileStat; path: "/proc/stat" }
    FileView { id: fileCpuInfo; path: "/proc/cpuinfo" }
    FileView { id: fileNetDev; path: "/proc/net/dev" }

    Process {
        id: findCpuMaxFreqProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        command: ["bash", "-c", "lscpu | grep 'CPU max MHz' | awk '{print $4}'"]
        running: true
        stdout: StdioCollector {
            id: outputCollector
            onStreamFinished: {
                root.maxAvailableCpuString = (parseFloat(outputCollector.text) / 1000).toFixed(0) + " GHz"
            }
        }
    }
    
    Process {
        id: diskProc
        command: ["bash", "-c", "df -k / | awk 'NR==2{print $2, $3}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    var parts = text.trim().split(/\s+/);
                    if (parts.length === 2) {
                        root.diskTotal = parseInt(parts[0]); // KB
                        root.diskUsed = parseInt(parts[1]);  // KB
                    }
                }
            }
        }
    }

    Timer {
        interval: 60000
        running: root.pollingVisible
        repeat: true
        onTriggered: diskProc.running = true
    }

    // CPU temp + GPU probe merged into ONE fork (was two Processes on two timers).
    Process {
        id: hwProbeProc
        environment: ({ LANG: "C", LC_ALL: "C" })
        command: ["bash", "-c",
            "echo cpu:$(sensors | awk '/Tctl:/ {print $2}; /Package id 0:/ {print $4}' | head -1 | tr -d '+' | cut -d'.' -f1); "
            + "if command -v nvidia-smi &>/dev/null; then nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,name --format=csv,noheader,nounits 2>/dev/null | head -1; "
            + "elif [ -f /sys/class/drm/card0/device/gpu_busy_percent ]; then u=$(cat /sys/class/drm/card0/device/gpu_busy_percent); "
            + "t=$(sensors 2>/dev/null | awk '/junction:/{print $2}' | tr -d '+' | cut -d. -f1 | head -1); [ -z \"$t\" ] && t=\"--\"; "
            + "n=$(cat /sys/class/drm/card0/device/product_name 2>/dev/null || echo 'AMD GPU'); echo \"$u, $t, $n\"; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const l = line.trim();
                    if (l.startsWith("cpu:")) {
                        const v = l.slice(4).trim();
                        if (v.length > 0) root.cpuTemp = v + "°C";
                    } else if (l.includes(",")) {
                        const parts = l.split(/,\s*/);
                        if (parts.length >= 3) {
                            root.gpuUsage = parseFloat(parts[0]) / 100;
                            root.gpuTemp = parts[1].trim() + "°C";
                            root.gpuModel = parts.slice(2).join(", ").trim();
                        }
                    }
                }
            }
        }
    }

    Timer {
        interval: 3000
        running: root.pollingVisible
        repeat: true
        onTriggered: hwProbeProc.running = false, hwProbeProc.running = true
    }

    Component.onCompleted: {
        diskProc.running = true
        hwProbeProc.running = true
    }
}
