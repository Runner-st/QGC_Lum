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

    // Match the stock PIP sizing
    readonly property real _pipWidth: pipViewReference ? pipViewReference.width : parent.width * 0.2
    readonly property real _pipHeight: _pipWidth * (9/16)

    // Only visible when there are secondary streams to show
    visible: _secondaryStreamCount > 0

    width: _pipWidth
    height: pipColumn.height

    ColumnLayout {
        id: pipColumn
        spacing: ScreenTools.defaultFontPixelWidth / 2

        Repeater {
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
                    if (active && root._videoManager) {
                        // Create VideoReceiver for this PIP stream
                        console.log("Creating PIP receiver for stream " + index)
                        var receiverName = "pip_" + index
                        var streamUrl = _streamUrls[index] || ""
                        var camType = _cameraTypes[index] || ""

                        pipReceiver = root._videoManager.createPipReceiver(receiverName, streamUrl, camType)

                        if (pipReceiver) {
                            // Assign receiver to item when loaded
                            if (item) {
                                item.videoReceiver = pipReceiver
                            }
                        }
                    } else if (!active && pipReceiver && root._videoManager) {
                        // Destroy VideoReceiver when stream is no longer needed
                        console.log("Destroying PIP receiver for stream " + index)
                        root._videoManager.destroyPipReceiver(pipReceiver)
                        pipReceiver = null
                    }
                }

                onLoaded: {
                    // Assign VideoReceiver to item after it's loaded
                    if (item && pipReceiver) {
                        console.log("Assigning PIP receiver to stream item " + index)
                        item.videoReceiver = pipReceiver
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
