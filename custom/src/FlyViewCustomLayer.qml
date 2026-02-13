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
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id: root

    property var parentToolInsets
    property var totalToolInsets: toolInsets
    property var mapControl

    Component.onCompleted: {
        console.log("FlyViewCustomLayer loaded")
        console.log("_hasCorePlugin:", _hasCorePlugin)
        console.log("_linksManager:", _linksManager)
    }

    readonly property real _margin: ScreenTools.defaultFontPixelWidth
    readonly property bool _hasVehicle: QGroundControl.multiVehicleManager.activeVehicle !== null
    readonly property bool _hasCorePlugin: QGroundControl.corePlugin !== null && QGroundControl.corePlugin !== undefined
    readonly property var _linksManager: _hasCorePlugin ? QGroundControl.corePlugin.linksManager : null
    readonly property bool _hasActiveLink: _linksManager !== null && _linksManager.hasActiveLink
    readonly property bool _hasC12Camera: _hasActiveLink && _linksManager.activeLink && _linksManager.activeLink.camera1 && _linksManager.activeLink.camera1.cameraType === 2
    readonly property bool _hasTopotekCamera: _hasActiveLink && _linksManager.activeLink && _linksManager.activeLink.camera1 && _linksManager.activeLink.camera1.cameraType === 3
    readonly property bool _hasHerelinkCamera: _hasActiveLink && _linksManager.activeLink && _linksManager.activeLink.camera1 && _linksManager.activeLink.camera1.cameraType === 1
    readonly property var  _herelinkStream: _hasCorePlugin ? QGroundControl.corePlugin.herelinkVideoStream : null

    // Debug logging function
    function debugWidgetState() {
        console.log("=== WIDGET STATE DEBUG ===")
        console.log("_hasActiveLink:", _hasActiveLink)
        console.log("_hasC12Camera:", _hasC12Camera)
        console.log("_hasTopotekCamera:", _hasTopotekCamera)

        if (_linksManager && _linksManager.activeLink) {
            console.log("Active link exists")
            if (_linksManager.activeLink.camera1) {
                console.log("camera1 exists")
                console.log("camera1.cameraType:", _linksManager.activeLink.camera1.cameraType)
                console.log("camera1.topotekCameraIp:", _linksManager.activeLink.camera1.topotekCameraIp)
                console.log("camera1.topotekControlPort:", _linksManager.activeLink.camera1.topotekControlPort)
            } else {
                console.log("camera1 is NULL")
            }
        } else {
            console.log("No active link or _linksManager")
        }
        console.log("==========================")
    }

    // Watch for changes
    on_HasActiveLinkChanged: debugWidgetState()
    on_HasC12CameraChanged: debugWidgetState()
    on_HasTopotekCameraChanged: debugWidgetState()

    function _triggerServo(channel, pulseWidth) {
        if (!_hasVehicle || !_hasCorePlugin) {
            return
        }

        QGroundControl.corePlugin.triggerServoCommand(channel, pulseWidth)
    }

    QGCToolInsets {
        id: toolInsets
        leftEdgeTopInset: parentToolInsets.leftEdgeTopInset
        leftEdgeCenterInset: parentToolInsets.leftEdgeCenterInset
        leftEdgeBottomInset: parentToolInsets.leftEdgeBottomInset
        rightEdgeTopInset: parentToolInsets.rightEdgeTopInset
        rightEdgeCenterInset: Math.max(parentToolInsets.rightEdgeCenterInset, cameraWidgetContainer.visible ? cameraWidgetContainer.width + _margin : 0)
        rightEdgeBottomInset: parentToolInsets.rightEdgeBottomInset
        topEdgeLeftInset: parentToolInsets.topEdgeLeftInset
        topEdgeCenterInset: parentToolInsets.topEdgeCenterInset
        topEdgeRightInset: parentToolInsets.topEdgeRightInset
        bottomEdgeLeftInset: Math.max(parentToolInsets.bottomEdgeLeftInset, buttonFlow.visible ? buttonFlow.implicitHeight + (_margin * 2) : 0)
        bottomEdgeCenterInset: parentToolInsets.bottomEdgeCenterInset
        bottomEdgeRightInset: parentToolInsets.bottomEdgeRightInset
    }

    Flow {
        id: buttonFlow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: _margin
        anchors.rightMargin: _margin
        anchors.bottomMargin: _margin
        spacing: _margin / 2
        visible: _hasActiveLink && buttonRepeater.count > 0

        Repeater {
            id: buttonRepeater
            model: _hasActiveLink ? _linksManager.activeServoButtons : []

            QGCButton {
                text: modelData.name
                width: Math.max(ScreenTools.defaultFontPixelWidth * 4, implicitWidth)
                height: ScreenTools.defaultFontPixelHeight * 2
                enabled: _hasVehicle && _hasCorePlugin
                onClicked: _triggerServo(modelData.channel, modelData.pulse)
            }
        }
    }

    // Camera Widget Container - holds both C12 and Topotek widgets
    Rectangle {
        id: cameraWidgetContainer
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: _margin

        visible: _hasC12Camera || _hasTopotekCamera || _hasHerelinkCamera
        width: widgetColumn.width
        height: widgetColumn.height
        color: "transparent"

        z: QGroundControl.zOrderWidgets

        Column {
            id: widgetColumn
            spacing: _margin

            // Herelink HDMI Switch Button
            QGCButton {
                visible: _hasHerelinkCamera
                enabled: !(_herelinkStream && _herelinkStream.settingInProgress)
                text: {
                    var videoSettings = QGroundControl.settingsManager.videoSettings
                    return videoSettings.cameraId.rawValue === 0 ? qsTr("HDMI1") : qsTr("HDMI2")
                }
                width: Math.max(ScreenTools.defaultFontPixelWidth * 8, implicitWidth)
                height: ScreenTools.defaultFontPixelHeight * 2.5
                onClicked: {
                    if (_herelinkStream) {
                        _herelinkStream.switchHdmiSource()
                    }
                }
            }

            // C12 Camera Widget
            Loader {
                id: c12WidgetLoader
                active: _hasC12Camera
                visible: _hasC12Camera
                source: _hasC12Camera ? "C12CameraWidget.qml" : ""

                onLoaded: {
                    if (item && _hasCorePlugin) {
                        item.c12Controller = QGroundControl.corePlugin.c12Controller
                    }
                }
            }

            // Topotek Camera Widget
            Loader {
                id: topotekWidgetLoader
                active: _hasTopotekCamera
                visible: _hasTopotekCamera
                source: _hasTopotekCamera ? "TopotekCameraWidget.qml" : ""

                onLoaded: {
                    if (item && _hasCorePlugin) {
                        item.topotekController = QGroundControl.corePlugin.topotekController
                    }
                }
            }
        }
    }
}
