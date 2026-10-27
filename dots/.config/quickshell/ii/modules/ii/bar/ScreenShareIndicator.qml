import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell.Io
import "./cards"

MouseArea {
    id: indicator
    property bool vertical: false

    implicitWidth: 40
    implicitHeight: Appearance.sizes.barHeight

    property bool activelyScreenSharing: false
    
    hoverEnabled: true
    Component.onCompleted: rootItem.toggleHighlight(true)

    Process {
        id: screenShareProc
        running: true
        command: ["bash", "-c", Directories.screenshareStateScript]
        // The watcher publishes the state file; if it ever dies, bring it back so the
        // indicator cannot silently stop updating for the rest of the session.
        onExited: respawnTimer.start()
    }

    Timer {
        id: respawnTimer
        interval: 3000
        repeat: false
        onTriggered: screenShareProc.running = true
    }
    
    FileView {
        id: stateFile
        path: Directories.screenshareStatePath
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: {
            indicator.activelyScreenSharing = !stateFile.text().trim().toLowerCase().includes("none")
            rootItem.toggleVisible(indicator.activelyScreenSharing)
        }
    }

    MaterialSymbol {
        id: iconIndicator
        z: 1
        text: "cast"
        anchors {
            top: parent.top
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
        }
        color: Appearance.colors.colOnPrimary
        font.pixelSize: Appearance.font.pixelSize.huge
    }

    StyledPopup {
        hoverTarget: indicator
        animate: false
        contentItem: HeroCard {
            compactMode: true
            anchors.centerIn: parent
            icon: "cast_connected"

            title: stateFile.text().trim()
            subtitle: Translation.tr("is using your screen")

            pillText: Translation.tr("Sharing..")
            pillIcon: "screen_share"
        }
    }
}