/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtMultimedia

import QGroundControl
import QGroundControl.Controls

Item {
    id: root

    property string streamUrl: ""
    property string streamName: ""
    property string cameraType: ""
    property int streamIndex: -1
    property var linksManager: null

    // Hide/show state
    property bool _isExpanded: true

    // Actual height when expanded vs collapsed
    implicitHeight: _isExpanded ? width * (9/16) : ScreenTools.defaultFontPixelHeight * 2

    function _setExpanded(expanded) {
        _isExpanded = expanded
    }

    // Watch for stream URL changes and reconnect appropriately
    onStreamUrlChanged: {
        if (streamUrl.length > 0) {
            mediaPlayer.stop()
            mediaPlayer.source = ""

            var isC12 = cameraType.toLowerCase().indexOf("skydroidc12") >= 0
            if (isC12) {
                console.log("PIP C12: Stream URL changed, delaying reconnection to: " + streamName)
                delayedStartTimer.start()
            } else {
                mediaPlayer.source = makeLowLatencyUrl(streamUrl)
                mediaPlayer.play()
            }
        }
    }

    // Helper function to add low-latency options to RTSP URLs
    // For C12 cameras, pass URL without modifications (like VLC does)
    function makeLowLatencyUrl(url) {
        if (!url || url.length === 0) return url
        if (!url.toLowerCase().startsWith("rtsp://")) return url

        // C12 cameras support multiple connections
        var isC12 = root.cameraType.toLowerCase().indexOf("skydroidc12") >= 0

        if (isC12) {
            // For C12: Pass URL without modifications - Qt/FFmpeg will auto-negotiate
            // VLC connects successfully this way, so we match that behavior
            console.log("PIP C12: Connecting to raw URL: " + url)
            return url
        } else {
            // Use UDP for other cameras (lower latency)
            var separator = url.indexOf("?") >= 0 ? "&" : "?"
            return url + separator + "rtsp_transport=udp&buffer_size=0"
        }
    }

    // Retry timer for failed connections
    Timer {
        id: retryTimer
        interval: 3000  // Retry every 3 seconds for faster reconnection
        repeat: true
        running: root.streamUrl.length > 0 && mediaPlayer.playbackState !== MediaPlayer.PlayingState && _isExpanded && !delayedStartTimer.running

        onTriggered: {
            if (root.streamUrl.length > 0) {
                console.log("Retrying stream: " + root.streamName)
                mediaPlayer.stop()
                mediaPlayer.source = ""
                var isC12 = root.cameraType.toLowerCase().indexOf("skydroidc12") >= 0
                if (isC12) {
                    // For C12, use delayed retry
                    delayedStartTimer.interval = 2000
                    delayedStartTimer.start()
                } else {
                    mediaPlayer.source = root.makeLowLatencyUrl(root.streamUrl)
                    mediaPlayer.play()
                }
            }
        }
    }

    // Connection timeout - force retry if stuck in loading state
    Timer {
        id: connectionTimeoutTimer
        // C12 cameras may need more time for RTSP session negotiation with multiple connections
        interval: {
            var isC12 = root.cameraType.toLowerCase().indexOf("skydroidc12") >= 0
            return isC12 ? 10000 : 5000  // 10 seconds for C12, 5 seconds for others
        }
        repeat: false
        running: root.streamUrl.length > 0 && mediaPlayer.mediaStatus === MediaPlayer.LoadingMedia && _isExpanded

        onTriggered: {
            console.log("Connection timeout for stream: " + root.streamName + " - forcing retry")
            mediaPlayer.stop()
            mediaPlayer.source = ""
        }
    }

    // Delayed start timer for C12 cameras - let main stream establish first
    Timer {
        id: delayedStartTimer
        interval: 2000  // 2 second delay
        repeat: false
        running: false
        onTriggered: {
            console.log("PIP C12: Starting delayed connection to: " + root.streamName)
            mediaPlayer.source = root.makeLowLatencyUrl(root.streamUrl)
            mediaPlayer.play()
        }
    }

    // Video player for this stream
    MediaPlayer {
        id: mediaPlayer
        videoOutput: videoOutput
        autoPlay: true

        Component.onCompleted: {
            // For C12 cameras, delay PIP connection to let main stream establish first
            var isC12 = root.cameraType.toLowerCase().indexOf("skydroidc12") >= 0
            if (isC12 && root.streamUrl.length > 0) {
                console.log("PIP C12: Delaying connection for " + root.streamName)
                delayedStartTimer.start()
            } else {
                source = root.makeLowLatencyUrl(root.streamUrl)
                if (source.toString().length > 0) {
                    play()
                }
            }
        }

        onSourceChanged: {
            if (source.toString().length > 0) {
                var isC12 = root.cameraType.toLowerCase().indexOf("skydroidc12") >= 0
                if (!isC12) {  // Only auto-play for non-C12 (C12 handled by timer)
                    play()
                }
            }
        }

        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.PlayingState) {
                retryTimer.stop()
            }
        }

        onMediaStatusChanged: {
            // Detect stalled or dead streams and force reconnection
            if (mediaStatus === MediaPlayer.StalledMedia ||
                mediaStatus === MediaPlayer.EndOfMedia ||
                mediaStatus === MediaPlayer.InvalidMedia) {
                console.log("PIP stream stalled/ended, forcing reconnection: " + root.streamName)
                stop()
                source = ""
                // Retry timer will pick it up
            }
        }

        onErrorOccurred: (error, errorString) => {
            console.warn("StreamPipItem: Stream error for " + root.streamName + ": " + errorString + " - will retry")
        }
    }

    // Stream health check timer - detects frozen streams that still report as playing
    Timer {
        id: streamHealthTimer
        interval: 10000  // Check every 10 seconds
        repeat: true
        running: root.streamUrl.length > 0 && mediaPlayer.playbackState === MediaPlayer.PlayingState && _isExpanded

        property int lastPosition: 0

        onTriggered: {
            // If position hasn't changed and we think we're playing, stream is frozen
            if (mediaPlayer.position === lastPosition && mediaPlayer.position > 0) {
                console.log("PIP stream frozen detected, forcing reconnection: " + root.streamName)
                mediaPlayer.stop()
                mediaPlayer.source = ""
                mediaPlayer.source = root.makeLowLatencyUrl(root.streamUrl)
                mediaPlayer.play()
            }
            lastPosition = mediaPlayer.position
        }
    }

    // Helper property to check if we actually have video playing
    property bool _isActuallyPlaying: mediaPlayer.playbackState === MediaPlayer.PlayingState &&
                                      (mediaPlayer.mediaStatus === MediaPlayer.BufferedMedia ||
                                       mediaPlayer.mediaStatus === MediaPlayer.BufferingMedia)

    // Main PIP container - visible when expanded
    Item {
        id: pipContent
        anchors.fill: parent
        visible: _isExpanded
        clip: true

        VideoOutput {
            id: videoOutput
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop
            visible: root._isActuallyPlaying
        }

        // Fallback when video not playing
        Rectangle {
            anchors.fill: parent
            color: "black"
            visible: !root._isActuallyPlaying

            QGCLabel {
                anchors.centerIn: parent
                text: root.streamName
                color: "white"
                font.pointSize: ScreenTools.smallFontPointSize
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                width: parent.width - ScreenTools.defaultFontPixelWidth
            }
        }

        // Stream name label at bottom (when playing)
        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 2
            width: nameLabel.width + ScreenTools.defaultFontPixelWidth
            height: nameLabel.height + 4
            color: Qt.rgba(0, 0, 0, 0.7)
            radius: 2
            visible: root._isActuallyPlaying

            QGCLabel {
                id: nameLabel
                anchors.centerIn: parent
                text: root.streamName
                color: "white"
                font.pointSize: ScreenTools.smallFontPointSize
            }
        }
    }

    // Click handler - swap this stream to main view (only when expanded)
    MouseArea {
        id: pipMouseArea
        anchors.fill: parent
        enabled: _isExpanded
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (linksManager && streamIndex >= 0) {
                linksManager.setMainStreamIndex(streamIndex)
            }
        }
    }

    // Swap icon (top-right) - matches stock PIP resize icon position/style
    Image {
        id: swapIcon
        source: "/qmlimages/MapSync.svg"
        mipmap: true
        fillMode: Image.PreserveAspectFit
        anchors.right: parent.right
        anchors.top: parent.top
        visible: _isExpanded && (ScreenTools.isMobile || pipMouseArea.containsMouse)
        height: ScreenTools.defaultFontPixelHeight * 2.5
        width: ScreenTools.defaultFontPixelHeight * 2.5
        sourceSize.height: height
    }

    // Hide icon (bottom-left) - matches stock PIP hide icon
    Image {
        id: hideIcon
        source: "/qmlimages/pipHide.svg"
        mipmap: true
        fillMode: Image.PreserveAspectFit
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        visible: _isExpanded && (ScreenTools.isMobile || pipMouseArea.containsMouse)
        height: ScreenTools.defaultFontPixelHeight * 2.5
        width: ScreenTools.defaultFontPixelHeight * 2.5
        sourceSize.height: height

        MouseArea {
            anchors.fill: parent
            onClicked: root._setExpanded(false)
        }
    }

    // Show button when collapsed - matches stock PIP show button
    Rectangle {
        id: showButton
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        height: ScreenTools.defaultFontPixelHeight * 2
        width: ScreenTools.defaultFontPixelHeight * 2
        radius: ScreenTools.defaultFontPixelHeight / 3
        visible: !_isExpanded
        color: Qt.rgba(0, 0, 0, 0.75)

        Image {
            width: parent.width * 0.75
            height: parent.height * 0.75
            sourceSize.height: height
            source: "/res/buttonRight.svg"
            mipmap: true
            fillMode: Image.PreserveAspectFit
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root._setExpanded(true)
        }
    }

    // Collapsed state label showing stream name
    Rectangle {
        anchors.left: showButton.right
        anchors.leftMargin: 4
        anchors.verticalCenter: showButton.verticalCenter
        height: collapsedLabel.height + 4
        width: collapsedLabel.width + ScreenTools.defaultFontPixelWidth
        radius: 4
        color: Qt.rgba(0, 0, 0, 0.75)
        visible: !_isExpanded

        QGCLabel {
            id: collapsedLabel
            anchors.centerIn: parent
            text: root.streamName
            color: "white"
            font.pointSize: ScreenTools.smallFontPointSize
        }
    }
}
