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

Item {
    id: root

    property var parentToolInsets
    property var totalToolInsets: toolInsets
    property var mapControl

    readonly property real _margin: ScreenTools.defaultFontPixelWidth
    readonly property bool _hasVehicle: QGroundControl.multiVehicleManager.activeVehicle !== null
    readonly property bool _hasCorePlugin: QGroundControl.corePlugin !== null && QGroundControl.corePlugin !== undefined
    readonly property var _linksManager: _hasCorePlugin ? QGroundControl.corePlugin.linksManager : null
    readonly property bool _hasActiveLink: _linksManager !== null && _linksManager.hasActiveLink
    readonly property bool _hasC12Camera: _hasActiveLink && _linksManager.activeLink && _linksManager.activeLink.camera1 && _linksManager.activeLink.camera1.cameraType === 2

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
        rightEdgeCenterInset: Math.max(parentToolInsets.rightEdgeCenterInset, c12Widget.visible ? c12Widget.width + _margin : 0)
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

    // C12 Camera Control Widget
    C12CameraWidget {
        id: c12Widget
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: _margin

        visible: _hasC12Camera
        c12Controller: _hasCorePlugin ? QGroundControl.corePlugin.c12Controller : null

        z: QGroundControl.zOrderWidgets
    }
}
