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
            if (_activeLink && _streamUrls.length > 0) {
                console.log("StreamPipColumn: Will restart PIP streams after delay")
                // Small delay to let main stream start first
                pipRestartTimer.start()
            }
        }

        function onActiveStreamsChanged() {
            var newSecondaryCount = (_streamUrls.length > 1) ? (_streamUrls.length - 1) : 0
            console.log("StreamPipColumn: Active streams changed, count=" + _streamUrls.length +
                       ", secondary=" + newSecondaryCount + ", prev=" + _prevStreamCount)
            for (var i = 0; i < _streamUrls.length; i++) {
                console.log("  Stream " + i + ": " + (_streamUrls[i] || "(empty)"))
            }
            // If secondary streams just became available, trigger PIP start
            if (newSecondaryCount > 0 && _prevStreamCount === 0) {
                console.log("StreamPipColumn: Streams now available, scheduling PIP start")
                pipStartTimer.start()
            }
            // Also restart if we already have streams but they might need refresh
            else if (newSecondaryCount > 0 && !pipStartTimer.running && !pipRestartTimer.running) {
                console.log("StreamPipColumn: Secondary streams available, scheduling PIP start")
                pipStartTimer.start()
            }
            _prevStreamCount = newSecondaryCount
        }
    }

    // Timer to restart PIP streams with delay after link change
    Timer {
        id: pipRestartTimer
        interval: 500  // 500ms delay to let main stream establish first
        repeat: false
        onTriggered: {
            console.log("StreamPipColumn: Restarting all PIP streams (link changed)")
            _restartAllPips()
        }
    }

    // Timer to start PIPs when streams first become available
    Timer {
        id: pipStartTimer
        interval: 1000  // 1 second delay to let everything initialize
        repeat: false
        onTriggered: {
            console.log("StreamPipColumn: Starting PIPs (streams became available)")
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
    }

    ColumnLayout {
        id: pipColumn
        spacing: ScreenTools.defaultFontPixelWidth / 2

        Repeater {
            id: pipRepeater
            model: _streamUrls.length

            // Only create items for non-main streams
            Loader {
                id: streamLoader
                active: index !== _mainStreamIndex
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
