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

    property var parentToolInsets
    property var totalToolInsets: toolInsets
    property var mapControl

    readonly property real _margin: ScreenTools.defaultFontPixelWidth
    readonly property bool _hasVehicle: QGroundControl.multiVehicleManager.activeVehicle !== null
    readonly property bool _hasCorePlugin: QGroundControl.corePlugin !== null && QGroundControl.corePlugin !== undefined
    readonly property var  _cameraManager: _hasCorePlugin ? QGroundControl.corePlugin.cameraManager : null
    readonly property real _buttonInset: buttonFlow.visible ? buttonFlow.implicitHeight + (_margin * 2) : 0
    readonly property real _secondaryInset: secondaryStreamsColumn.visible ? (_buttonInset + secondaryStreamsColumn.implicitHeight + _margin) : 0

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
        rightEdgeCenterInset: parentToolInsets.rightEdgeCenterInset
        rightEdgeBottomInset: parentToolInsets.rightEdgeBottomInset
        topEdgeLeftInset: parentToolInsets.topEdgeLeftInset
        topEdgeCenterInset: parentToolInsets.topEdgeCenterInset
        topEdgeRightInset: parentToolInsets.topEdgeRightInset
        bottomEdgeLeftInset: Math.max(parentToolInsets.bottomEdgeLeftInset, _buttonInset, _secondaryInset)
        bottomEdgeCenterInset: parentToolInsets.bottomEdgeCenterInset
        bottomEdgeRightInset: parentToolInsets.bottomEdgeRightInset
    }

    Column {
        id: secondaryStreamsColumn
        anchors.left: parent.left
        anchors.bottom: buttonFlow.top
        anchors.leftMargin: _margin
        anchors.bottomMargin: _margin
        spacing: _margin / 2
        visible: _cameraManager && _cameraManager.secondaryStreamsVisible && _cameraManager.secondaryCameras.length > 0

        Repeater {
            model: secondaryStreamsColumn.visible ? _cameraManager.secondaryCameras : []

            CameraStreamView {
                streamIndex: modelData.index
                streamName: modelData.name
                cameraManager: _cameraManager
            }
        }
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
        visible: _hasCorePlugin && buttonRepeater.count > 0

        Repeater {
            id: buttonRepeater
            model: _hasCorePlugin ? QGroundControl.corePlugin.servoButtons : []

            QGCButton {
                text: modelData.name
                width: Math.max(ScreenTools.defaultFontPixelWidth * 4, implicitWidth)
                height: ScreenTools.defaultFontPixelHeight * 2
                enabled: _hasVehicle && _hasCorePlugin
                onClicked: _triggerServo(modelData.channel, modelData.pulse)
            }
        }
    }
}
