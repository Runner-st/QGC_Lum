/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Controls
import QtMultimedia

import QGroundControl
import QGroundControl.FlightDisplay
import QGroundControl.FlightMap
import QGroundControl.Controls

Item {
    id:     root
    clip:   true

    property bool useSmallFont: true

    // LinksManager integration
    readonly property var  _linksManager:       QGroundControl.corePlugin ? QGroundControl.corePlugin.linksManager : null
    readonly property var  _activeLink:         _linksManager ? _linksManager.activeLink : null
    readonly property var  _streamUrls:         _linksManager ? _linksManager.activeStreamUrls : []
    readonly property var  _streamNames:        _linksManager ? _linksManager.activeStreamNames : []
    readonly property int  _mainStreamIndex:    _linksManager ? _linksManager.mainStreamIndex : 0
    readonly property bool _hasLinksManagerStream: _activeLink !== null && _streamUrls.length > 0
    readonly property string _mainStreamUrl:    _hasLinksManagerStream ? (_streamUrls[_mainStreamIndex] || "") : ""
    readonly property string _mainStreamName:   _hasLinksManagerStream ? (_streamNames[_mainStreamIndex] || "") : ""

    // Helper function to add low-latency options to RTSP URLs
    function makeLowLatencyUrl(url) {
        if (!url || url.length === 0) return url
        if (!url.toLowerCase().startsWith("rtsp://")) return url

        // Add FFmpeg low-latency options for RTSP streams
        // rtsp_transport=udp - use UDP for lower latency (vs TCP)
        // buffer_size=0 - minimal buffer
        // These options are passed via URL query string to FFmpeg
        var separator = url.indexOf("?") >= 0 ? "&" : "?"
        return url + separator + "rtsp_transport=udp&buffer_size=0"
    }

    // Standard VideoManager properties
    property double _ar:                QGroundControl.videoManager.gstreamerEnabled
                                            ? QGroundControl.videoManager.videoSize.width / QGroundControl.videoManager.videoSize.height
                                            : QGroundControl.videoManager.aspectRatio
    property bool   _showGrid:          QGroundControl.settingsManager.videoSettings.gridLines.rawValue
    property var    _dynamicCameras:    globals.activeVehicle ? globals.activeVehicle.cameraManager : null
    property bool   _connected:         globals.activeVehicle ? !globals.activeVehicle.communicationLost : false
    property int    _curCameraIndex:    _dynamicCameras ? _dynamicCameras.currentCamera : 0
    property bool   _isCamera:          _dynamicCameras ? _dynamicCameras.cameras.count > 0 : false
    property var    _camera:            _isCamera ? _dynamicCameras.cameras.get(_curCameraIndex) : null
    property bool   _hasZoom:           _camera && _camera.hasZoom
    property int    _fitMode:           QGroundControl.settingsManager.videoSettings.videoFit.rawValue

    property bool   _isMode_FIT_WIDTH:  _fitMode === 0
    property bool   _isMode_FIT_HEIGHT: _fitMode === 1
    property bool   _isMode_FILL:       _fitMode === 2
    property bool   _isMode_NO_CROP:    _fitMode === 3

    function getWidth() {
        return videoBackground.getWidth()
    }
    function getHeight() {
        return videoBackground.getHeight()
    }

    property double _thermalHeightFactor: 0.85

    // LinksManager Stream Display (FFmpeg fallback - only shown when GStreamer not handling it)
    Item {
        id: linksManagerVideo
        anchors.fill: parent
        // Hide when VideoManager is handling the stream via GStreamer (hasOverrideUri)
        visible: _hasLinksManagerStream && !QGroundControl.videoManager.hasOverrideUri
        z: 1  // Above standard video

        // Retry timer for failed connections (only when using FFmpeg fallback)
        Timer {
            id: retryTimer
            interval: 3000  // Retry every 3 seconds for faster reconnection
            repeat: true
            running: _hasLinksManagerStream && !QGroundControl.videoManager.hasOverrideUri && linksMediaPlayer.playbackState !== MediaPlayer.PlayingState

            onTriggered: {
                if (root._mainStreamUrl.length > 0) {
                    console.log("Retrying stream connection: " + root._mainStreamName)
                    linksMediaPlayer.stop()
                    linksMediaPlayer.source = ""
                    linksMediaPlayer.source = root.makeLowLatencyUrl(root._mainStreamUrl)
                    linksMediaPlayer.play()
                }
            }
        }

        // Connection timeout - force retry if stuck in loading state (only when using FFmpeg fallback)
        Timer {
            id: connectionTimeoutTimer
            interval: 5000  // 5 second connection timeout
            repeat: false
            running: _hasLinksManagerStream && !QGroundControl.videoManager.hasOverrideUri && linksMediaPlayer.mediaStatus === MediaPlayer.LoadingMedia

            onTriggered: {
                console.log("Connection timeout for stream: " + root._mainStreamName + " - forcing retry")
                linksMediaPlayer.stop()
                linksMediaPlayer.source = ""
            }
        }

        MediaPlayer {
            id: linksMediaPlayer
            source: root.makeLowLatencyUrl(root._mainStreamUrl)
            videoOutput: linksVideoOutput
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

            onMediaStatusChanged: {
                // Detect stalled or dead streams and force reconnection
                if (mediaStatus === MediaPlayer.StalledMedia ||
                    mediaStatus === MediaPlayer.EndOfMedia ||
                    mediaStatus === MediaPlayer.InvalidMedia) {
                    console.log("Stream stalled/ended, forcing reconnection: " + root._mainStreamName)
                    stop()
                    source = ""
                    // Retry timer will pick it up
                }
            }

            onErrorOccurred: (error, errorString) => {
                console.warn("LinksManager video error: " + errorString + " - will retry")
            }
        }

        // Stream health check timer - detects frozen streams that still report as playing (only when using FFmpeg fallback)
        Timer {
            id: streamHealthTimer
            interval: 10000  // Check every 10 seconds
            repeat: true
            running: _hasLinksManagerStream && !QGroundControl.videoManager.hasOverrideUri && linksMediaPlayer.playbackState === MediaPlayer.PlayingState

            property int lastPosition: 0

            onTriggered: {
                // If position hasn't changed and we think we're playing, stream is frozen
                if (linksMediaPlayer.position === lastPosition && linksMediaPlayer.position > 0) {
                    console.log("Stream frozen detected, forcing reconnection: " + root._mainStreamName)
                    linksMediaPlayer.stop()
                    linksMediaPlayer.source = ""
                    linksMediaPlayer.source = root.makeLowLatencyUrl(root._mainStreamUrl)
                    linksMediaPlayer.play()
                }
                lastPosition = linksMediaPlayer.position
            }
        }

        // Helper property to check if we actually have video playing
        // playbackState becomes PlayingState immediately on play(), but mediaStatus
        // only becomes BufferedMedia/BufferingMedia when we actually have video data
        property bool _isActuallyPlaying: linksMediaPlayer.playbackState === MediaPlayer.PlayingState &&
                                          (linksMediaPlayer.mediaStatus === MediaPlayer.BufferedMedia ||
                                           linksMediaPlayer.mediaStatus === MediaPlayer.BufferingMedia)

        VideoOutput {
            id: linksVideoOutput
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop
            visible: linksManagerVideo._isActuallyPlaying
        }

        // Fallback when LinksManager stream not playing
        Rectangle {
            anchors.fill: parent
            color: "black"
            visible: !linksManagerVideo._isActuallyPlaying

            Image {
                id: noVideoImage
                anchors.fill: parent
                source: "/res/NoVideoBackground.jpg"
                fillMode: Image.PreserveAspectCrop
            }

            Rectangle {
                anchors.centerIn: parent
                width: linksNoVideoLabel.contentWidth + ScreenTools.defaultFontPixelHeight
                height: linksNoVideoLabel.contentHeight + ScreenTools.defaultFontPixelHeight
                radius: ScreenTools.defaultFontPixelWidth / 2
                color: "black"
                opacity: 0.5
            }

            QGCLabel {
                id: linksNoVideoLabel
                text: root._mainStreamName.length > 0 ?
                      qsTr("CONNECTING TO %1...").arg(root._mainStreamName.toUpperCase()) :
                      qsTr("WAITING FOR STREAM")
                font.bold: true
                color: "white"
                font.pointSize: useSmallFont ? ScreenTools.smallFontPointSize : ScreenTools.largeFontPointSize
                anchors.centerIn: parent
            }
        }

        // Stream name overlay when playing (top-center to avoid tool strip)
        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: ScreenTools.defaultFontPixelWidth
            width: streamNameLabel.width + ScreenTools.defaultFontPixelWidth * 2
            height: streamNameLabel.height + ScreenTools.defaultFontPixelHeight / 2
            color: Qt.rgba(0, 0, 0, 0.6)
            radius: 4
            visible: linksManagerVideo._isActuallyPlaying

            QGCLabel {
                id: streamNameLabel
                anchors.centerIn: parent
                text: root._mainStreamName
                color: "white"
                font.pointSize: ScreenTools.defaultFontPointSize
            }
        }
    }

    // Standard VideoManager display (GStreamer - shown when LinksManager not active OR when VideoManager is handling LinksManager stream)
    Item {
        anchors.fill: parent
        visible: !_hasLinksManagerStream || QGroundControl.videoManager.hasOverrideUri

        Image {
            id:             noVideo
            anchors.fill:   parent
            source:         "/res/NoVideoBackground.jpg"
            fillMode:       Image.PreserveAspectCrop
            visible:        !(QGroundControl.videoManager.decoding)

            Rectangle {
                anchors.centerIn:   parent
                width:              noVideoLabel.contentWidth + ScreenTools.defaultFontPixelHeight
                height:             noVideoLabel.contentHeight + ScreenTools.defaultFontPixelHeight
                radius:             ScreenTools.defaultFontPixelWidth / 2
                color:              "black"
                opacity:            0.5
            }

            QGCLabel {
                id:                 noVideoLabel
                text:               QGroundControl.settingsManager.videoSettings.streamEnabled.rawValue ? qsTr("WAITING FOR VIDEO") : qsTr("VIDEO DISABLED")
                font.bold:          true
                color:              "white"
                font.pointSize:     useSmallFont ? ScreenTools.smallFontPointSize : ScreenTools.largeFontPointSize
                anchors.centerIn:   parent
            }
        }

        Rectangle {
            id:             videoBackground
            anchors.fill:   parent
            color:          "black"
            visible:        QGroundControl.videoManager.decoding
            function getWidth() {
                if(_ar != 0.0){
                    if(_isMode_FIT_HEIGHT
                            || (_isMode_FILL && (root.width/root.height < _ar))
                            || (_isMode_NO_CROP && (root.width/root.height > _ar))){
                        return root.height * _ar
                    }
                }
                return root.width
            }
            function getHeight() {
                if(_ar != 0.0){
                    if(_isMode_FIT_WIDTH
                            || (_isMode_FILL && (root.width/root.height > _ar))
                            || (_isMode_NO_CROP && (root.width/root.height < _ar))){
                        return root.width * (1 / _ar)
                    }
                }
                return root.height
            }
            Component {
                id: videoBackgroundComponent
                QGCVideoBackground {
                    id:             videoContent
                    objectName:     "videoContent"

                    Connections {
                        target: QGroundControl.videoManager
                        function onImageFileChanged(filename) {
                            videoContent.grabToImage(function(result) {
                                if (!result.saveToFile(filename)) {
                                    console.error('Error capturing video frame');
                                }
                            });
                        }
                    }

                    Rectangle {
                        color:  Qt.rgba(1,1,1,0.5)
                        height: parent.height
                        width:  1
                        x:      parent.width * 0.33
                        visible: _showGrid && !QGroundControl.videoManager.fullScreen
                    }
                    Rectangle {
                        color:  Qt.rgba(1,1,1,0.5)
                        height: parent.height
                        width:  1
                        x:      parent.width * 0.66
                        visible: _showGrid && !QGroundControl.videoManager.fullScreen
                    }
                    Rectangle {
                        color:  Qt.rgba(1,1,1,0.5)
                        width:  parent.width
                        height: 1
                        y:      parent.height * 0.33
                        visible: _showGrid && !QGroundControl.videoManager.fullScreen
                    }
                    Rectangle {
                        color:  Qt.rgba(1,1,1,0.5)
                        width:  parent.width
                        height: 1
                        y:      parent.height * 0.66
                        visible: _showGrid && !QGroundControl.videoManager.fullScreen
                    }
                }
            }
            Loader {
                height:             parent.getHeight()
                width:              parent.getWidth()
                anchors.centerIn:   parent
                visible:            QGroundControl.videoManager.decoding
                sourceComponent:    videoBackgroundComponent

                property bool videoDisabled: QGroundControl.settingsManager.videoSettings.videoSource.rawValue === QGroundControl.settingsManager.videoSettings.disabledVideoSource
            }

            //-- Thermal Image
            Item {
                id:                 thermalItem
                width:              height * QGroundControl.videoManager.thermalAspectRatio
                height:             _camera ? (_camera.thermalMode === MavlinkCameraControl.THERMAL_FULL ? parent.height : (_camera.thermalMode === MavlinkCameraControl.THERMAL_PIP ? ScreenTools.defaultFontPixelHeight * 12 : parent.height * _thermalHeightFactor)) : 0
                anchors.centerIn:   parent
                visible:            QGroundControl.videoManager.hasThermal && _camera.thermalMode !== MavlinkCameraControl.THERMAL_OFF
                function pipOrNot() {
                    if(_camera) {
                        if(_camera.thermalMode === MavlinkCameraControl.THERMAL_PIP) {
                            anchors.centerIn    = undefined
                            anchors.top         = parent.top
                            anchors.topMargin   = mainWindow.header.height + (ScreenTools.defaultFontPixelHeight * 0.5)
                            anchors.left        = parent.left
                            anchors.leftMargin  = ScreenTools.defaultFontPixelWidth * 12
                        } else {
                            anchors.top         = undefined
                            anchors.topMargin   = undefined
                            anchors.left        = undefined
                            anchors.leftMargin  = undefined
                            anchors.centerIn    = parent
                        }
                    }
                }
                Connections {
                    target:                 _camera
                    function onThermalModeChanged() { thermalItem.pipOrNot() }
                }
                onVisibleChanged: {
                    thermalItem.pipOrNot()
                }
                QGCVideoBackground {
                    id:             thermalVideo
                    objectName:     "thermalVideo"
                    anchors.fill:   parent
                    opacity:        _camera ? (_camera.thermalMode === MavlinkCameraControl.THERMAL_BLEND ? _camera.thermalOpacity / 100 : 1.0) : 0
                }
            }
            //-- Zoom
            PinchArea {
                id:             pinchZoom
                enabled:        _hasZoom
                anchors.fill:   parent
                onPinchStarted: pinchZoom.zoom = 0
                onPinchUpdated: {
                    if(_hasZoom) {
                        var z = 0
                        if(pinch.scale < 1) {
                            z = Math.round(pinch.scale * -10)
                        } else {
                            z = Math.round(pinch.scale)
                        }
                        if(pinchZoom.zoom != z) {
                            _camera.stepZoom(z)
                        }
                    }
                }
                property int zoom: 0
            }
        }
    }

    // Listen for LinksManager stream changes (only for FFmpeg fallback - GStreamer is handled by VideoManager)
    Connections {
        target: _linksManager
        function onActiveStreamsChanged() {
            // Only handle for FFmpeg fallback
            if (_hasLinksManagerStream && !QGroundControl.videoManager.hasOverrideUri && root._mainStreamUrl.length > 0) {
                linksMediaPlayer.stop()
                linksMediaPlayer.source = ""
                linksMediaPlayer.source = root.makeLowLatencyUrl(root._mainStreamUrl)
                linksMediaPlayer.play()
            }
        }
        function onMainStreamIndexChanged() {
            // Only handle for FFmpeg fallback - GStreamer stream index change is handled by LinksManagerController -> VideoManager
            if (_hasLinksManagerStream && !QGroundControl.videoManager.hasOverrideUri) {
                // Force source reload when main stream index changes
                linksMediaPlayer.stop()
                linksMediaPlayer.source = ""
                // Need to re-read the URL with the NEW index
                var newUrl = root._streamUrls[root._mainStreamIndex] || ""
                console.log("Main stream index changed to: " + root._mainStreamIndex + ", URL: " + newUrl)
                if (newUrl.length > 0) {
                    linksMediaPlayer.source = root.makeLowLatencyUrl(newUrl)
                    linksMediaPlayer.play()
                }
            }
        }
    }
}
