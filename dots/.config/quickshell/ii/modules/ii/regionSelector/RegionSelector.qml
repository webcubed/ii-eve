pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Scope {
    id: root

    function dismiss() {
        GlobalStates.regionSelectorOpen = false
    }

    property var action: RegionSelection.SnipAction.Copy
    property var selectionMode: RegionSelection.SelectionMode.RectCorners

    // Built-in annotation editor state (opened after a snip with the Edit action)
    property bool annotateOpen: false
    property string annotatePath: ""
    property var annotateScreen: null

    AnnotationEditor {
        visible: root.annotateOpen
        imagePath: root.annotatePath
        targetScreen: root.annotateScreen
        onDismiss: root.annotateOpen = false
    }

    Variants {
        model: Quickshell.screens
        
        delegate: Loader {
            id: regionSelectorLoader
            required property var modelData

            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(regionSelectorLoader.modelData)
            property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)

            active: GlobalStates.regionSelectorOpen && (!Config.options.regionSelector.showOnlyOnFocusedMonitor || monitorIsFocused)

            sourceComponent: RegionSelection {
                screen: regionSelectorLoader.modelData
                onDismiss: root.dismiss()
                // Close the selector first, open the editor on the next tick so
                // the two layer-shell surfaces never coexist (same reason as Translate).
                onAnnotationReady: (path, targetScreen) => {
                    root.annotatePath = path;
                    root.annotateScreen = targetScreen;
                    Qt.callLater(() => root.annotateOpen = true);
                }
                action: root.action
                selectionMode: root.selectionMode
            }
        }
    }

    function screenshot() {
        root.action = RegionSelection.SnipAction.Copy
        root.selectionMode = RegionSelection.SelectionMode.RectCorners
        GlobalStates.regionSelectorOpen = true
    }

    function annotate() {
        root.action = RegionSelection.SnipAction.Edit
        root.selectionMode = RegionSelection.SelectionMode.RectCorners
        GlobalStates.regionSelectorOpen = true
    }

    function search() {
        root.action = RegionSelection.SnipAction.Search
        if (Config.options.search.imageSearch.useCircleSelection) {
            root.selectionMode = RegionSelection.SelectionMode.Circle
        } else {
            root.selectionMode = RegionSelection.SelectionMode.RectCorners
        }
        GlobalStates.regionSelectorOpen = true
    }

    function ocr() {
        root.action = RegionSelection.SnipAction.CharRecognition
        root.selectionMode = RegionSelection.SelectionMode.RectCorners
        GlobalStates.regionSelectorOpen = true
    }

    function translate() {
        root.action = RegionSelection.SnipAction.Translate
        root.selectionMode = RegionSelection.SelectionMode.RectCorners
        GlobalStates.regionSelectorOpen = true
    }

    // "Send part of the screen" in the AI chat: snip goes to the clipboard,
    // RegionSelection calls Ai.handleClipboardAndAttach() when it's done.
    function askAI() {
        root.action = RegionSelection.SnipAction.AskAI
        root.selectionMode = RegionSelection.SelectionMode.RectCorners
        GlobalStates.regionSelectorOpen = true
    }

    Connections {
        target: GlobalStates
        function onSnipForAiRequested() {
            root.askAI()
        }
    }

    function record() {
        root.action = RegionSelection.SnipAction.Record
        root.selectionMode = RegionSelection.SelectionMode.RectCorners
        // If already open then re-trigger to stop recording
        if (GlobalStates.regionSelectorOpen) GlobalStates.regionSelectorOpen = false
        GlobalStates.regionSelectorOpen = true
    }

    function recordWithSound() {
        root.action = RegionSelection.SnipAction.RecordWithSound
        root.selectionMode = RegionSelection.SelectionMode.RectCorners
        // If already open then re-trigger to stop recording
        if (GlobalStates.regionSelectorOpen) GlobalStates.regionSelectorOpen = false
        GlobalStates.regionSelectorOpen = true
    }

    IpcHandler {
        target: "region"

        function screenshot() {
            root.screenshot()
        }
        function annotate() {
            root.annotate()
        }
        function search() {
            root.search()
        }
        function ocr() {
            root.ocr()
        }
        function translate() {
            root.translate()
        }
        function record() {
            root.record()
        }
        function recordWithSound() {
            root.recordWithSound()
        }
    }

    GlobalShortcut {
        name: "regionScreenshot"
        description: "Takes a screenshot of the selected region"
        onPressed: root.screenshot()
    }
    GlobalShortcut {
        name: "regionAnnotate"
        description: "Snips the selected region and opens the annotation editor"
        onPressed: root.annotate()
    }
    GlobalShortcut {
        name: "regionSearch"
        description: "Searches the selected region"
        onPressed: root.search()
    }
    GlobalShortcut {
        name: "regionOcr"
        description: "Recognizes text in the selected region"
        onPressed: root.ocr()
    }
    GlobalShortcut {
        name: "regionTranslate"
        description: "Translates text in the selected region"
        onPressed: root.translate()
    }
    GlobalShortcut {
        name: "regionRecord"
        description: "Records the selected region"
        onPressed: root.record()
    }
    GlobalShortcut {
        name: "regionRecordWithSound"
        description: "Records the selected region with sound"
        onPressed: root.recordWithSound()
    }
}
