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
    Item {
        id: pipContent
        anchors.fill: parent
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

    // Resize icon (top-right) - matches stock PIP
    Image {
        id: pipResizeIcon
        source: "/qmlimages/pipResize.svg"
        fillMode: Image.PreserveAspectFit
        mipmap: true
        anchors.right: parent.right
        anchors.top: parent.top
        visible: ScreenTools.isMobile || pipMouseArea.containsMouse
        height: ScreenTools.defaultFontPixelHeight * 2.5
        width: ScreenTools.defaultFontPixelHeight * 2.5
        sourceSize.height: height
    }

    // Swap/Sync icon (top-left) - matches stock PIP popup icon position
    Image {
        id: swapIcon
        source: "/qmlimages/MapSync.svg"
        mipmap: true
        fillMode: Image.PreserveAspectFit
        anchors.left: parent.left
        anchors.top: parent.top
        visible: !ScreenTools.isMobile && pipMouseArea.containsMouse
        height: ScreenTools.defaultFontPixelHeight * 2.5
        width: ScreenTools.defaultFontPixelHeight * 2.5
        sourceSize.height: height
    }
}
