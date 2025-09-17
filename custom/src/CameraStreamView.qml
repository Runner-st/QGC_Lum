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
import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightDisplay

Item {
    id: root
    width: ScreenTools.defaultFontPixelWidth * 13
    height: width * 0.65
    clip: true

    property int streamIndex: -1
    property string streamName: ""
    property var cameraManager: null

    readonly property bool gstreamerAvailable: QGroundControl.videoManager.gstreamerEnabled
    readonly property bool qtMultimediaAvailable: QGroundControl.videoManager.qtmultimediaEnabled
    readonly property bool hasVideoBackend: gstreamerAvailable || qtMultimediaAvailable

    property int _registeredIndex: -1
    property var _registeredItem: null

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    function unregisterStream() {
        if (!cameraManager || _registeredIndex < 0) {
            _registeredIndex = -1
            _registeredItem = null
            return
        }

        cameraManager.unregisterView(_registeredIndex)
        _registeredIndex = -1
        _registeredItem = null
    }

    function registerStream() {
        if (!cameraManager || !hasVideoBackend || streamIndex < 0 || !videoLoader.item) {
            if (_registeredIndex >= 0) {
                unregisterStream()
            }
            return
        }

        if (_registeredIndex === streamIndex && _registeredItem === videoLoader.item) {
            return
        }

        if (_registeredIndex >= 0) {
            unregisterStream()
        }

        cameraManager.registerView(streamIndex, videoLoader.item)
        _registeredIndex = streamIndex
        _registeredItem = videoLoader.item
    }

    Rectangle {
        anchors.fill: parent
        radius: ScreenTools.defaultFontPixelWidth / 3
        color: qgcPal.windowShadeDark
        border.color: qgcPal.windowShade
        border.width: 1
    }

    Loader {
        id: videoLoader
        anchors.fill: parent
        active: hasVideoBackend
        sourceComponent: gstreamerAvailable ? gstreamerComponent : (qtMultimediaAvailable ? qtMultimediaComponent : null)
        onStatusChanged: {
            if (status === Loader.Ready) {
                registerStream()
            } else if (status === Loader.Null || status === Loader.Error) {
                unregisterStream()
            }
        }
    }

    Component {
        id: gstreamerComponent

        FlightDisplayViewGStreamer {
            anchors.fill: parent
            antialiasing: true
        }
    }

    Component {
        id: qtMultimediaComponent

        FlightDisplayViewQtMultimedia {
            anchors.fill: parent
        }
    }

    Rectangle {
        anchors.fill: parent
        color: qgcPal.windowShadeDark
        border.color: qgcPal.windowShade
        border.width: 1
        visible: !hasVideoBackend

        QGCLabel {
            text: qsTr("Video preview unavailable")
            anchors.centerIn: parent
            color: qgcPal.text
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            width: parent.width - ScreenTools.defaultFontPixelWidth * 2
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: Qt.rgba(qgcPal.window.r, qgcPal.window.g, qgcPal.window.b, 0.65)
        height: streamLabel.implicitHeight + ScreenTools.defaultFontPixelHeight / 4

        QGCLabel {
            id: streamLabel
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            text: streamName
            font.pointSize: ScreenTools.smallFontPointSize
            elide: Text.ElideRight
            width: root.width - ScreenTools.defaultFontPixelWidth
            horizontalAlignment: Text.AlignHCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (cameraManager && streamIndex >= 0) {
                cameraManager.promoteToPrimary(streamIndex)
            }
        }
    }

    Component.onCompleted: registerStream()

    onCameraManagerChanged: registerStream()
    onStreamIndexChanged: registerStream()
    onHasVideoBackendChanged: hasVideoBackend ? registerStream() : unregisterStream()
    onGstreamerAvailableChanged: registerStream()
    onQtMultimediaAvailableChanged: registerStream()

    Component.onDestruction: unregisterStream()
}
