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

        onErrorOccurred: (error, errorString) => {
            console.warn("StreamPipItem: Stream error for " + root.streamName + ": " + errorString)
        }
    }

    // Main PIP container - matches stock PIP styling
    Rectangle {
        id: pipBackground
        anchors.fill: parent
        color: "black"
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

        // Stream name label at bottom
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

    // Click handler - swap this stream to main view
    MouseArea {
        id: pipMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (linksManager && streamIndex >= 0) {
                linksManager.setMainStreamIndex(streamIndex)
            }
        }
    }

    // Swap icon (matches stock PIP style) - shown on hover
    Image {
        id: swapIcon
        source: "/qmlimages/MapSync.svg"
        mipmap: true
        fillMode: Image.PreserveAspectFit
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: ScreenTools.defaultFontPixelWidth / 2
        visible: pipMouseArea.containsMouse
        height: ScreenTools.defaultFontPixelHeight * 2
        width: height
        sourceSize.height: height

        // Semi-transparent background for the icon
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            color: Qt.rgba(0, 0, 0, 0.5)
            radius: 4
            z: -1
        }
    }

    // Highlight border on hover (matches stock PIP behavior)
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: pipMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.8) : Qt.rgba(1, 1, 1, 0.3)
        border.width: pipMouseArea.containsMouse ? 2 : 1
    }
}
