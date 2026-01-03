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
    property int streamIndex: -1
    property var linksManager: null

    // Hide/show state
    property bool _isExpanded: true

    // Actual height when expanded vs collapsed
    implicitHeight: _isExpanded ? width * (9/16) : ScreenTools.defaultFontPixelHeight * 2

    function _setExpanded(expanded) {
        _isExpanded = expanded
    }

    // Retry timer for failed connections
    Timer {
        id: retryTimer
        interval: 5000  // Retry every 5 seconds
        repeat: true
        running: root.streamUrl.length > 0 && mediaPlayer.playbackState !== MediaPlayer.PlayingState && _isExpanded

        onTriggered: {
            if (root.streamUrl.length > 0) {
                console.log("Retrying stream: " + root.streamName)
                mediaPlayer.stop()
                mediaPlayer.source = ""
                mediaPlayer.source = root.streamUrl
                mediaPlayer.play()
            }
        }
    }

    // Video player for this stream
    MediaPlayer {
        id: mediaPlayer
        source: root.streamUrl
        videoOutput: videoOutput
        autoPlay: true

        onSourceChanged: {
            if (source.toString().length > 0) {
                play()
            }
        }

        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.PlayingState) {
                retryTimer.stop()
            }
        }

        onErrorOccurred: (error, errorString) => {
            console.warn("StreamPipItem: Stream error for " + root.streamName + ": " + errorString + " - will retry")
        }
    }

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
        }

        // Fallback when video not playing
        Rectangle {
            anchors.fill: parent
            color: "black"
            visible: mediaPlayer.playbackState !== MediaPlayer.PlayingState

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
            visible: mediaPlayer.playbackState === MediaPlayer.PlayingState

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
