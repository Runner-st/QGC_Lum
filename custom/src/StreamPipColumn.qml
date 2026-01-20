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

import QGroundControl
import QGroundControl.Controls

Item {
    id: root

    property var pipViewReference: null  // Reference to the stock PipView for sizing

    readonly property var _linksManager: QGroundControl.corePlugin ? QGroundControl.corePlugin.linksManager : null
    readonly property var _videoManager: QGroundControl.videoManager
    readonly property var _activeLink: _linksManager ? _linksManager.activeLink : null
    readonly property var _streamUrls: _linksManager ? _linksManager.activeStreamUrls : []
    readonly property var _streamNames: _linksManager ? _linksManager.activeStreamNames : []
    readonly property var _cameraTypes: _linksManager ? _linksManager.activeCameraTypes : []
    readonly property int _mainStreamIndex: _linksManager ? _linksManager.mainStreamIndex : 0

    // Calculate number of secondary streams (exclude main stream)
    readonly property int _secondaryStreamCount: {
        if (!_activeLink || _streamUrls.length <= 1) return 0
        return _streamUrls.length - 1
    }

    // Track previous stream count to detect when streams become available
    property int _prevStreamCount: 0

    // Track if main video has started (prevents PIP from starting before main stream)
    property bool _mainVideoReady: false

    // Match the stock PIP sizing
    readonly property real _pipWidth: pipViewReference ? pipViewReference.width : parent.width * 0.2
    readonly property real _pipHeight: _pipWidth * (9/16)

    // Only visible when there are secondary streams to show
    visible: _secondaryStreamCount > 0

    width: _pipWidth
    height: pipColumn.height

    // Listen for link reconnection and stream changes
    Connections {
        target: _linksManager

        function onActiveLinkChanged() {
            console.log("StreamPipColumn: Active link changed, _activeLink=" + (_activeLink ? "yes" : "no") +
                       ", _streamUrls.length=" + _streamUrls.length)
            // Reset video ready state when link changes - PIPs will wait for videoStartReady
            _mainVideoReady = false
        }

        function onActiveStreamsChanged() {
            var newSecondaryCount = (_streamUrls.length > 1) ? (_streamUrls.length - 1) : 0
            console.log("StreamPipColumn: Active streams changed, count=" + _streamUrls.length +
                       ", secondary=" + newSecondaryCount + ", prev=" + _prevStreamCount)
            for (var i = 0; i < _streamUrls.length; i++) {
                console.log("  Stream " + i + ": " + (_streamUrls[i] || "(empty)"))
            }
            // Track stream count changes, but don't auto-start PIPs here
            // PIPs will be started when videoStartReady is emitted
            _prevStreamCount = newSecondaryCount
        }

        function onVideoStartReady() {
            console.log("StreamPipColumn: Main video started (videoStartReady), _secondaryStreamCount=" + _secondaryStreamCount)
            _mainVideoReady = true
            // PIPs will now activate via Loader's active binding
            // Add small delay before triggering restart to let Loaders initialize
            if (_secondaryStreamCount > 0) {
                console.log("StreamPipColumn: Scheduling PIP start after main video ready")
                pipStartTimer.start()
            }
        }
    }

    // Timer to start PIPs after main video starts (triggered by videoStartReady signal)
    Timer {
        id: pipStartTimer
        interval: 500  // 500ms delay after main stream to avoid bandwidth contention
        repeat: false
        onTriggered: {
            console.log("StreamPipColumn: Starting PIPs after main video ready")
            _restartAllPips()
        }
    }

    // Helper function to restart all PIP streams
    function _restartAllPips() {
        console.log("StreamPipColumn: _restartAllPips called, repeater count=" + pipRepeater.count)
        for (var i = 0; i < pipRepeater.count; i++) {
            var loader = pipRepeater.itemAt(i)
            console.log("  Loader " + i + ": " + (loader ? "exists" : "null") +
                       ", active=" + (loader ? loader.active : "n/a") +
                       ", item=" + (loader && loader.item ? "exists" : "null"))
            if (loader && loader.item && loader.item.forceRestart) {
                console.log("  Calling forceRestart on loader " + i)
                loader.item.forceRestart()
            }
        }
    }

    Component.onCompleted: {
        console.log("StreamPipColumn: Initialized, _activeLink=" + (_activeLink ? "yes" : "no") +
                   ", _streamUrls.length=" + _streamUrls.length +
                   ", _mainStreamIndex=" + _mainStreamIndex +
                   ", _secondaryStreamCount=" + _secondaryStreamCount)

        // Check if video is already ready at startup (not pending)
        // This handles the case where parameters were already loaded before QML initialized
        if (_linksManager && _activeLink && !_linksManager.videoStartPending) {
            console.log("StreamPipColumn: Video already ready at startup (not pending)")
            _mainVideoReady = true
        }
    }

    ColumnLayout {
        id: pipColumn
        spacing: ScreenTools.defaultFontPixelWidth / 2

        Repeater {
            id: pipRepeater
            model: _streamUrls.length

            // Only create items for non-main streams, and only after main video is ready
            Loader {
                id: streamLoader
                active: index !== _mainStreamIndex && root._mainVideoReady
                visible: active

                Layout.preferredWidth: root._pipWidth
                // Use item's implicitHeight to handle collapse/expand
                Layout.preferredHeight: item ? item.implicitHeight : root._pipHeight

                property var pipReceiver: null

                onActiveChanged: {
                    if (!active && pipReceiver && root._videoManager) {
                        // Destroy VideoReceiver when stream is no longer needed
                        console.log("Destroying PIP receiver for stream " + index)
                        root._videoManager.destroyPipReceiver(pipReceiver)
                        pipReceiver = null
                    }
                }

                onLoaded: {
                    // Create VideoReceiver when item loads (onActiveChanged doesn't fire reliably on initial creation)
                    if (active && root._videoManager && !pipReceiver) {
                        console.log("Creating PIP receiver for stream " + index + " (onLoaded)")
                        var receiverName = "pip_" + index
                        var streamUrl = _streamUrls[index] || ""
                        var camType = _cameraTypes[index] || ""

                        pipReceiver = root._videoManager.createPipReceiver(receiverName, streamUrl, camType)

                        if (pipReceiver && item) {
                            console.log("Assigning PIP receiver to stream item " + index)
                            item.videoReceiver = pipReceiver
                        }
                    }
                }

                sourceComponent: StreamPipItem {
                    width: root._pipWidth
                    streamUrl: _streamUrls[index] || ""
                    streamName: _streamNames[index] || qsTr("Stream %1").arg(index + 1)
                    cameraType: _cameraTypes[index] || ""
                    streamIndex: index
                    linksManager: _linksManager
                    // videoReceiver assigned dynamically via onLoaded
                }
            }
        }
    }
}
