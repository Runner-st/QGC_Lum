/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import org.freedesktop.gstreamer.Qt6GLVideoItem

import QGroundControl
import QGroundControl.Controls

Item {
    id: root

    property string streamUrl: ""
    property string streamName: ""
    property string cameraType: ""
    property int streamIndex: -1
    property var linksManager: null
    property var videoReceiver: null  // Assigned by StreamPipColumn

    // Hide/show state
    property bool _isExpanded: true

    // Actual height when expanded vs collapsed
    implicitHeight: _isExpanded ? width * (9/16) : ScreenTools.defaultFontPixelHeight * 2

    function _setExpanded(expanded) {
        _isExpanded = expanded
    }

    // Force restart the stream (called by StreamPipColumn on reconnection)
    function forceRestart() {
        if (videoReceiver) {
            console.log("PIP " + streamName + " forcing restart")
            videoReceiver.stop()
            // Use delayed start for proper sequencing
            forceRestartTimer.start()
        }
    }

    // Timer for forced restart after stop
    Timer {
        id: forceRestartTimer
        interval: 500  // Wait for stop to complete
        repeat: false
        onTriggered: {
            if (videoReceiver && root.streamUrl.length > 0) {
                console.log("PIP " + root.streamName + " restarting after force stop")
                var isC12 = root.cameraType.toLowerCase().indexOf("skydroidc12") >= 0
                if (isC12) {
                    delayedStartTimer.start()
                } else {
                    var timeout = 5000
                    videoReceiver.start(timeout)
                }
            }
        }
    }

    // Monitor videoReceiver assignment
    onVideoReceiverChanged: {
        if (videoReceiver) {
            console.log("PIP: VideoReceiver assigned for " + streamName)

            // Set object name for video sink discovery
            videoItem.objectName = videoReceiver.name

            // Start playback (receiver already configured in C++)
            var isC12 = cameraType.toLowerCase().indexOf("skydroidc12") >= 0
            if (isC12 && streamUrl.length > 0) {
                console.log("PIP C12: Delaying connection for " + streamName)
                delayedStartTimer.start()
            } else if (streamUrl.length > 0) {
                var timeout = 5000
                videoReceiver.start(timeout)
            }
        }
    }

    // Retry timer for failed connections or stuck streams
    // Triggers when we have a stream URL but no actual video decoding
    Timer {
        id: retryTimer
        interval: 3000  // Retry every 3 seconds
        repeat: true
        // Run when: have URL, have receiver, NOT decoding (stuck or failed), expanded, not in other timers
        running: root.streamUrl.length > 0 && videoReceiver && !videoReceiver.decoding && _isExpanded &&
                 !delayedStartTimer.running && !forceRestartTimer.running

        onTriggered: {
            if (root.streamUrl.length > 0 && videoReceiver) {
                console.log("Retrying PIP stream: " + root.streamName + " (streaming=" + videoReceiver.streaming + ", decoding=" + videoReceiver.decoding + ")")
                videoReceiver.stop()

                var isC12 = root.cameraType.toLowerCase().indexOf("skydroidc12") >= 0
                if (isC12) {
                    // For C12, use delayed retry
                    delayedStartTimer.interval = 2000
                    delayedStartTimer.start()
                } else {
                    var timeout = 5000
                    videoReceiver.start(timeout)
                }
            }
        }
    }

    // Connection timeout - force retry if stuck in streaming-but-not-decoding state
    Timer {
        id: connectionTimeoutTimer
        // C12 cameras may need more time for RTSP session negotiation
        interval: {
            var isC12 = root.cameraType.toLowerCase().indexOf("skydroidc12") >= 0
            return isC12 ? 12000 : 8000  // 12 seconds for C12, 8 seconds for others
        }
        repeat: false
        // Run when streaming started but decoding hasn't begun
        running: root.streamUrl.length > 0 && videoReceiver && videoReceiver.streaming && !videoReceiver.decoding && _isExpanded

        onTriggered: {
            console.log("Connection timeout for PIP stream: " + root.streamName + " - streaming but not decoding, forcing retry")
            if (videoReceiver) {
                videoReceiver.stop()
            }
        }
    }

    // Delayed start timer for C12 cameras - let main stream establish first
    Timer {
        id: delayedStartTimer
        interval: 2000  // 2 second delay
        repeat: false
        running: false
        onTriggered: {
            if (videoReceiver && root.streamUrl.length > 0) {
                console.log("PIP C12: Starting delayed connection to: " + root.streamName)
                var timeout = 10000  // C12 gets longer timeout
                videoReceiver.start(timeout)
            }
        }
    }

    // Helper property to check if we actually have video playing
    property bool _isActuallyPlaying: videoReceiver ? videoReceiver.decoding : false

    // Connect to VideoReceiver signals
    Connections {
        target: videoReceiver

        function onStreamingChanged(active) {
            console.log("PIP " + root.streamName + " streaming changed: " + (active ? "yes" : "no"))
            if (active) {
                retryTimer.stop()
            }
        }

        function onDecodingChanged(active) {
            console.log("PIP " + root.streamName + " decoding changed: " + (active ? "yes" : "no"))
        }

        function onVideoSizeChanged(size) {
            console.log("PIP " + root.streamName + " resized: " + size.width + "x" + size.height)
        }

        function onOnStartComplete(status) {
            console.log("PIP " + root.streamName + " start complete, status: " + status)
            if (status === 0 && videoReceiver) {  // STATUS_OK = 0
                // Setup video sink from QML side (C++ can't find dynamically created QML items)
                if (!videoReceiver.sink) {
                    console.log("PIP " + root.streamName + " setting up video sink from QML")
                    QGroundControl.videoManager.setupPipVideoSink(videoReceiver, videoItem)
                } else if (videoReceiver.sink) {
                    videoReceiver.startDecoding(videoReceiver.sink)
                }
            }
        }

        function onOnStopComplete(status) {
            console.log("PIP " + root.streamName + " stop complete, status: " + status)
            // Retry timer will handle reconnection if needed
        }
    }

    // Main PIP container - visible when expanded
    Item {
        id: pipContent
        anchors.fill: parent
        visible: _isExpanded
        clip: true

        // GStreamer video item
        GstGLQt6VideoItem {
            id: videoItem
            anchors.fill: parent
            // objectName set dynamically when videoReceiver assigned
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
