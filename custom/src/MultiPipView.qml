/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts
import QtMultimedia

import QGroundControl
import QGroundControl.Controls

Item {
    id: root

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    property real pipSize: parent.width * 0.12
    property real pipSpacing: ScreenTools.defaultFontPixelWidth / 2

    readonly property var _linksManager: QGroundControl.corePlugin ? QGroundControl.corePlugin.linksManager : null
    readonly property var _activeLink: _linksManager ? _linksManager.activeLink : null
    readonly property var _streamUrls: _linksManager ? _linksManager.activeStreamUrls : []
    readonly property var _streamNames: _linksManager ? _linksManager.activeStreamNames : []
    readonly property int _mainStreamIndex: _linksManager ? _linksManager.mainStreamIndex : 0

    // Only visible when there's an active link with streams
    visible: _activeLink !== null && _streamUrls.length > 0

    width: pipColumn.width
    height: pipColumn.height

    ColumnLayout {
        id: pipColumn
        spacing: pipSpacing

        Repeater {
            model: _streamUrls.length

            Rectangle {
                id: pipItem
                width: pipSize
                height: pipSize * (9/16)
                color: "black"
                border.color: {
                    if (index === _mainStreamIndex) {
                        return qgcPal.brandingBlue  // Highlight main stream
                    } else if (pipMouseArea.containsMouse) {
                        return qgcPal.brandingBlue
                    } else {
                        return qgcPal.groupBorder
                    }
                }
                border.width: (index === _mainStreamIndex || pipMouseArea.containsMouse) ? 2 : 1
                radius: 4
                opacity: index === _mainStreamIndex ? 0.7 : 1.0  // Dim the main stream indicator

                property string streamUrl: _streamUrls[index] || ""
                property string streamName: _streamNames[index] || qsTr("Stream %1").arg(index + 1)
                property bool isMainStream: index === _mainStreamIndex

                // Video player for this stream (thumbnail preview)
                MediaPlayer {
                    id: mediaPlayer
                    source: pipItem.streamUrl
                    videoOutput: videoOutput
                    autoPlay: true

                    onErrorOccurred: (error, errorString) => {
                        console.warn("MultiPipView: Stream error for " + pipItem.streamName + ": " + errorString)
                    }

                    Component.onCompleted: {
                        if (pipItem.streamUrl.length > 0) {
                            play()
                        }
                    }
                }

                VideoOutput {
                    id: videoOutput
                    anchors.fill: parent
                    anchors.margins: 1
                    fillMode: VideoOutput.PreserveAspectCrop
                }

                // Fallback when no video is available
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    color: "black"
                    visible: mediaPlayer.playbackState !== MediaPlayer.PlayingState

                    QGCLabel {
                        anchors.centerIn: parent
                        text: pipItem.streamName
                        color: "white"
                        font.pointSize: ScreenTools.smallFontPointSize
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width - 4
                    }
                }

                // "MAIN" indicator for the current main stream
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 2
                    width: mainLabel.width + 4
                    height: mainLabel.height + 2
                    color: qgcPal.brandingBlue
                    radius: 2
                    visible: pipItem.isMainStream

                    QGCLabel {
                        id: mainLabel
                        anchors.centerIn: parent
                        text: qsTr("MAIN")
                        color: "white"
                        font.pointSize: ScreenTools.smallFontPointSize * 0.8
                        font.bold: true
                    }
                }

                // Stream name overlay (for non-main streams when playing)
                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 2
                    width: streamLabel.width + ScreenTools.defaultFontPixelWidth
                    height: streamLabel.height + 4
                    color: Qt.rgba(0, 0, 0, 0.6)
                    radius: 2
                    visible: !pipItem.isMainStream && mediaPlayer.playbackState === MediaPlayer.PlayingState

                    QGCLabel {
                        id: streamLabel
                        anchors.centerIn: parent
                        text: pipItem.streamName
                        color: "white"
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                }

                // Click to swap handler
                MouseArea {
                    id: pipMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: pipItem.isMainStream ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (_linksManager && !pipItem.isMainStream) {
                            _linksManager.setMainStreamIndex(index)
                        }
                    }
                }

                // Swap icon on hover (only for non-main streams)
                Image {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 4
                    width: ScreenTools.defaultFontPixelHeight * 1.2
                    height: width
                    source: "/qmlimages/MapSync.svg"
                    visible: pipMouseArea.containsMouse && !pipItem.isMainStream
                    sourceSize.height: height
                    mipmap: true
                }
            }
        }
    }

    // Listen for stream changes
    Connections {
        target: _linksManager
        function onActiveStreamsChanged() {
            // Players will auto-restart due to source binding
        }
    }
}
