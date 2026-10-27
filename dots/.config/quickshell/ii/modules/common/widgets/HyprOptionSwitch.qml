import qs.services
import Quickshell.Io

ConfigSwitch {
    id: root

    required property string optionKey
    property bool fallback: false

    checked: Boolean(HyprlandOptions.get(root.optionKey, root.fallback))
    onCheckedChanged: {
        if (checked === Boolean(HyprlandOptions.get(root.optionKey, root.fallback))) return
        HyprlandOptions.apply(root.optionKey, checked)
        reloadProc.running = true
    }

    // The configurator only rewrites the lua override file, so the running
    // compositor keeps the old value until it is told to reload.
    Process {
        id: reloadProc
        command: ["hyprctl", "reload"]
        onRunningChanged: if (!running) HyprlandOptions.refresh()
    }
}
