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

    readonly property var _linksManager: QGroundControl.corePlugin ? QGroundControl.corePlugin.linksManager : null
    readonly property var _activeLink: _linksManager ? _linksManager.activeLink : null
    readonly property var _streamUrls: _linksManager ? _linksManager.activeStreamUrls : []
    readonly property var _streamNames: _linksManager ? _linksManager.activeStreamNames : []
    readonly property int _mainStreamIndex: _linksManager ? _linksManager.mainStreamIndex : 0

    // Main stream URL - first stream becomes main
    readonly property string _mainStreamUrl: _streamUrls.length > 0 ? _streamUrls[_mainStreamIndex] : ""
    readonly property string _mainStreamName: _streamNames.length > 0 ? _streamNames[_mainStreamIndex] : ""

    // Only visible when there's an active link with at least one stream
    visible: _activeLink !== null && _streamUrls.length > 0

    // Video player for the main stream
    MediaPlayer {
        id: mediaPlayer
        source: root._mainStreamUrl
        videoOutput: videoOutput
        autoPlay: true

        onErrorOccurred: (error, errorString) => {
            console.warn("MainStreamView: Stream error for " + root._mainStreamName + ": " + errorString)
        }

        onSourceChanged: {
            if (source.toString().length > 0) {
                play()
            }
        }
    }

    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
    }

    // Fallback placeholder when no video
    Rectangle {
        anchors.fill: parent
        color: "black"
        visible: mediaPlayer.playbackState !== MediaPlayer.PlayingState && root.visible

        QGCLabel {
            anchors.centerIn: parent
            text: root._mainStreamName.length > 0 ?
                  qsTr("Connecting to %1...").arg(root._mainStreamName) :
                  qsTr("No video stream")
            color: "white"
            font.pointSize: ScreenTools.largeFontPointSize
        }
    }

    // Stream name overlay
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: ScreenTools.defaultFontPixelWidth
        width: streamLabel.width + ScreenTools.defaultFontPixelWidth * 2
        height: streamLabel.height + ScreenTools.defaultFontPixelHeight / 2
        color: Qt.rgba(0, 0, 0, 0.6)
        radius: 4
        visible: root.visible && mediaPlayer.playbackState === MediaPlayer.PlayingState

        QGCLabel {
            id: streamLabel
            anchors.centerIn: parent
            text: root._mainStreamName
            color: "white"
            font.pointSize: ScreenTools.defaultFontPointSize
        }
    }

    // Listen for stream changes
    Connections {
        target: _linksManager
        function onActiveStreamsChanged() {
            // Restart playback when streams change
            if (root._mainStreamUrl.length > 0) {
                mediaPlayer.stop()
                mediaPlayer.play()
            }
        }
        function onMainStreamIndexChanged() {
            // Restart playback when main stream changes
            if (root._mainStreamUrl.length > 0) {
                mediaPlayer.stop()
                mediaPlayer.play()
            }
        }
    }
}
