import qs.modules.common
import qs.services
import QtQuick

// Single-line lyrics with scroll transition effect.
// Shows only the current line; on change, old line slides up and fades out
// while new line slides up from below and fades in.

Item {
    id: root
    clip: true

    readonly property bool hasSyncedLines: LyricsService.syncedLines.length > 0
    readonly property int currentIndex: hasSyncedLines ? LyricsService.currentIndex : -1
    readonly property string currentText: currentIndex >= 0 && currentIndex < LyricsService.syncedLines.length
        ? LyricsService.syncedLines[currentIndex].text : ""

    property real fontSize: Appearance.font.pixelSize.smallie
    property bool useGradientMask: false
    property real gradientDensity: 0.25

    Component.onCompleted: {
        LyricsService.initiliazeLyrics()
    }

    // Outgoing line (previous)
    Item {
        id: outgoing
        width: parent.width
        height: parent.height
        opacity: 0
        y: 0

        StyledText {
            id: outgoingText
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            color: Appearance.colors.colSubtext
            font.pixelSize: root.fontSize
        }

        states: [
            State {
                name: "exiting_forward"
                when: root._exitDirection === 1
                PropertyChanges { target: outgoing; opacity: 0; y: -root.height * 0.4 }
            },
            State {
                name: "exiting_backward"
                when: root._exitDirection === -1
                PropertyChanges { target: outgoing; opacity: 0; y: root.height * 0.4 }
            }
        ]

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(outgoing)
        }
        Behavior on y {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(outgoing)
        }
    }

    // Incoming line (current)
    Item {
        id: incoming
        width: parent.width
        height: parent.height
        opacity: 1
        y: 0

        StyledText {
            id: incomingText
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            color: Appearance.colors.colOnLayer0
            font.pixelSize: root.fontSize * 1.1
            font.weight: Font.DemiBold
        }

        states: [
            State {
                name: "entering_forward"
                when: root._enterDirection === 1 && root._isAnimating
                PropertyChanges { target: incoming; opacity: 1; y: 0 }
            },
            State {
                name: "entering_backward"
                when: root._enterDirection === -1 && root._isAnimating
                PropertyChanges { target: incoming; opacity: 1; y: 0 }
            }
        ]

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(incoming)
        }
        Behavior on y {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(incoming)
        }
    }

    // Transition state
    property int _exitDirection: 0   // 1 = forward (old goes up), -1 = backward (old goes down)
    property int _enterDirection: 0
    property bool _isAnimating: false
    property int _lastIndex: -1

    onCurrentIndexChanged: {
        if (currentIndex === _lastIndex || currentIndex < 0) return;

        const goingForward = currentIndex > _lastIndex;
        _lastIndex = currentIndex;

        // Set outgoing text to previous line
        const prevIdx = goingForward ? currentIndex - 1 : currentIndex + 1;
        if (prevIdx >= 0 && prevIdx < LyricsService.syncedLines.length) {
            outgoingText.text = LyricsService.syncedLines[prevIdx].text;
        }

        // Set incoming text to current line
        incomingText.text = currentText;

        // Start transition
        _exitDirection = goingForward ? 1 : -1;
        _enterDirection = goingForward ? 1 : -1;
        _isAnimating = true;

        // Reset outgoing position before animating
        outgoing.y = 0;
        outgoing.opacity = 1;

        // Animate outgoing away
        _exitDirection = goingForward ? 1 : -1;

        // After a short delay, reset for next transition
        _resetTimer.restart();
    }

    Timer {
        id: _resetTimer
        interval: 350
        onTriggered: {
            root._isAnimating = false;
            root._exitDirection = 0;
            root._enterDirection = 0;
        }
    }

    // Initial state: show current line immediately
    Binding {
        target: incomingText
        property: "text"
        value: root.currentText
        when: !root._isAnimating
    }
}
