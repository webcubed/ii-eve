import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects
import qs.modules.common.utils
import Quickshell.Io

Item {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool isPlaying: activePlayer?.isPlaying ?? false
    readonly property bool hasMedia: activePlayer?.trackTitle != null && activePlayer.trackTitle !== ""

    // Dynamic island: show media when playing, window title when idle
    readonly property var activeWindow: ToplevelManager.activeToplevel
    readonly property string windowClass: activeWindow?.appId ?? ""
    readonly property string windowTitle: activeWindow?.title ?? ""
    readonly property int workspaceId: HyprlandData.activeWorkspace?.id ?? 1
    readonly property string displayText: hasMedia
        ? `${StringUtils.cleanMusicTitle(activePlayer.trackTitle)}${activePlayer.trackArtist ? ' • ' + activePlayer.trackArtist : ''}`
        : (windowTitle || windowClass || `${Translation.tr("Workspace")} ${workspaceId}`)

    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")

    property int customSize: Config.options.bar.mediaPlayer.customSize
    property int lyricsCustomSize: Config.options.bar.mediaPlayer.lyrics.customSize
    readonly property int maxWidth: 300

    property bool useFixedSize: Config.options.bar.mediaPlayer.useFixedSize
    readonly property bool lyricsEnabled: Config.options.bar.mediaPlayer.lyrics.enable
    function toggleLyrics() {
        Config.options.bar.mediaPlayer.lyrics.enable = !Config.options.bar.mediaPlayer.lyrics.enable;
    }
    readonly property bool useGradientMask: Config.options.bar.mediaPlayer.lyrics.useGradientMask
    readonly property string lyricsStyle: Config.options.bar.mediaPlayer.lyrics.style
    readonly property bool artworkEnabled: Config.options.bar.mediaPlayer.artwork.enable
    readonly property bool lyricsDynamicSize: Config.options.bar.mediaPlayer.lyrics.dynamicSize ?? false

    // Dynamic lyrics sizing
    property string _currentLyricText: LyricsService.syncedLines[LyricsService.currentIndex]?.text ?? ""
    TextMetrics {
        id: lyricsMetrics
        text: root._currentLyricText
        font.pixelSize: Appearance.font.pixelSize.smallie
    }
    readonly property int lyricsDynamicWidth: lyricsMetrics.advanceWidth + 40

    readonly property int progressButtonSize: 20
    readonly property int artworkBoxSize: artworkEnabled ? Math.min(25, Appearance.sizes.barHeight - 8) : 0
    readonly property int artworkContentPadding: artworkEnabled ? 6 : 0

    property int textMetricsSpacing: artworkEnabled ? 70 : 50
    property int textMetricsAdvance: Math.min(textMetrics.advanceWidth + textMetricsSpacing, Config.options.bar.mediaPlayer.maxSize)

    // Window title metrics for idle state
    TextMetrics {
        id: windowTextMetrics
        text: root.displayText
        font.pixelSize: Appearance.font.pixelSize.small
    }
    readonly property int windowTitleWidth: windowTextMetrics.advanceWidth + 20

    implicitWidth: {
        if (hasMedia) {
            if (LyricsService.hasSyncedLines && root.lyricsEnabled) {
                return root.lyricsDynamicSize
                    ? Math.min(Math.max(lyricsDynamicWidth, 120), lyricsCustomSize)
                    : lyricsCustomSize;
            }
            return useFixedSize ? customSize : textMetricsAdvance;
        }
        // Idle state: dynamic width based on window title
        return Math.min(windowTitleWidth, 350);
    }
    implicitHeight: Appearance.sizes.barHeight

    property list<real> visualizerPoints: []

    Behavior on implicitWidth {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(root)
    }

    Process {
        id: cavaProc
        running: activePlayer?.isPlaying ?? false
        command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/raw_output_config.txt`]
        stdout: SplitParser {
            onRead: data => {
                let points = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p));
                root.visualizerPoints = points;
            }
        }
        onRunningChanged: {
            if (!running) root.visualizerPoints = [];
        }
    }

    Component.onCompleted: {
        LyricsService.initiliazeLyrics()
    }

    readonly property string artSource: activePlayer?.trackArtUrl && activePlayer.trackArtUrl !== "" ? activePlayer.trackArtUrl : ""

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        height: Appearance.sizes.baseBarHeight - 8
        y: (root.height - height) / 2
        clip: true
        z: -1

        WaveVisualizer {
            anchors.fill: parent
            points: root.visualizerPoints
            live: activePlayer?.isPlaying ?? false
            color: Appearance.colors.colPrimary
            visible: root.visualizerPoints.length > 0
        }
    }

    Item {
        id: artworkItem
        visible: artworkEnabled && hasMedia
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: artworkEnabled ? artworkBoxSize : 0
        height: artworkEnabled ? artworkBoxSize : 0

        Rectangle {
            anchors.fill: parent
            color: Appearance.colors.colPrimaryContainer
            radius: Appearance.rounding.full

            Image {
                anchors.fill: parent
                source: root.artSource
                fillMode: Image.PreserveAspectCrop
                cache: false
                antialiasing: true
                width: parent.width
                height: parent.height
                sourceSize.width: width
                sourceSize.height: height

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: artworkItem.width
                        height: artworkItem.height
                        radius: Appearance.rounding.full
                    }
                }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: root.artSource.length === 0
                fill: 1
                text: "music_note"
                iconSize: Math.max(12, artworkItem.width * 0.5)
                color: Appearance.colors.colOnSecondaryContainer
            }
        }

        MouseArea {
            anchors.fill: parent
            z: 1
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: root.toggleLyrics()
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton | Qt.RightButton | Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onPressed: (event) => {
            if (event.button === Qt.LeftButton) {
                if (!hasMedia) return;
                if (Persistent.states.media?.popupRect) {
                    var globalPos = root.mapToItem(null, 0, 0);
                    Persistent.states.media.popupRect.x = globalPos.x;
                    Persistent.states.media.popupRect.y = globalPos.y;
                    Persistent.states.media.popupRect.width = root.width;
                    Persistent.states.media.popupRect.height = root.height;
                }
                GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen;
                return;
            }
            if (!activePlayer) return;
            if (event.button === Qt.MiddleButton) {
                activePlayer.togglePlaying();
            } else if (event.button === Qt.BackButton) {
                activePlayer.previous();
            } else if (event.button === Qt.ForwardButton || event.button === Qt.RightButton) {
                activePlayer.next();
            }
        }
    }

    Item {
        id: mediaCircProgSlot
        width: root.progressButtonSize
        height: root.progressButtonSize
        anchors.verticalCenter: parent.verticalCenter
        x: artworkEnabled && hasMedia ? root.width - width : 0
        visible: hasMedia

        ClippedFilledCircularProgress {
            id: mediaCircProg
            anchors.fill: parent
            implicitSize: root.progressButtonSize

            lineWidth: Appearance.rounding.unsharpen
            value: activePlayer?.position / activePlayer?.length
            colPrimary: Appearance.colors.colOnSecondaryContainer
            enableAnimation: false

            Item {
                anchors.centerIn: parent
                width: mediaCircProg.implicitSize
                height: mediaCircProg.implicitSize

                MaterialSymbol {
                    anchors.centerIn: parent
                    fill: 1
                    text: activePlayer?.isPlaying ? "pause" : "music_note"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.m3colors.m3onSecondaryContainer
                }
            }
        }
    }

    TextMetrics {
        id: textMetrics
        text: `${cleanedTitle}${activePlayer?.trackArtist ? ' • ' + activePlayer.trackArtist : ''}`
    }

    StyledText {
        visible: (!LyricsService.hasSyncedLines || !lyricsEnabled)
        anchors {
            horizontalCenter: parent.horizontalCenter
            horizontalCenterOffset: (artworkEnabled && hasMedia) ? 0 : (hasMedia ? mediaCircProgSlot.width / 2 : 0)
            verticalCenter: parent.verticalCenter
            verticalCenterOffset: 1
        }
        horizontalAlignment: Text.AlignHCenter
        width: (artworkEnabled && hasMedia) ? parent.implicitWidth - (artworkItem.width + mediaCircProgSlot.width + artworkContentPadding + 16) : parent.implicitWidth - (hasMedia ? mediaCircProgSlot.width + 16 : 16)
        elide: Text.ElideRight
        color: Appearance.colors.colOnLayer1
        text: root.displayText
    }

    Loader {
        id: lyricsItemLoader
        active: lyricsEnabled

        width: artworkEnabled ? parent.width - (artworkItem.width + mediaCircProg.implicitSize * 2) : parent.width - mediaCircProg.implicitSize * 2
        height: parent.height

        anchors.left: parent.left
        anchors.leftMargin: artworkEnabled ? mediaCircProg.implicitSize * 1.5 + artworkContentPadding : mediaCircProg.implicitSize * 1.5

        sourceComponent: Item {
            id: lyricsItem
            visible: lyricsEnabled

            anchors.centerIn: parent

            Loader {
                active: lyricsStyle == "static"
                anchors.fill: parent
                anchors.centerIn: parent
                sourceComponent: LyricsStatic {
                    anchors.fill: parent
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Loader {
                active: lyricsStyle == "scroller"
                anchors.fill: parent
                sourceComponent: LyricScroller {
                    id: lyricScroller

                    anchors.fill: parent
                    visible: lyricsStyle == "scroller" && LyricsService.hasSyncedLines

                    defaultLyricsSize: Appearance.font.pixelSize.smallest
                        useGradientMask: root.useGradientMask
                        halfVisibleLines: 1
                        downScale: 0.98
                        rowHeight: 10
                        gradientDensity: 0.25
                }
            }

            Loader {
                active: lyricsStyle == "current"
                anchors.fill: parent
                sourceComponent: LyricCurrentLine {
                    anchors.fill: parent
                    visible: lyricsStyle == "current" && LyricsService.hasSyncedLines
                    fontSize: Appearance.font.pixelSize.smallest
                    useGradientMask: root.useGradientMask
                    gradientDensity: 0.25
                }
            }
        }
    }
}
