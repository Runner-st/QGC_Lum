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
    readonly property int _servoChannel: 9

    function _sendServoPulse(pulseWidth) {
        const activeVehicle = QGroundControl.multiVehicleManager.activeVehicle
        if (activeVehicle) {
            activeVehicle.sendServoCommand(_servoChannel, pulseWidth)
        }
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
        bottomEdgeLeftInset: Math.max(parentToolInsets.bottomEdgeLeftInset, buttonRow.visible ? buttonRow.height + (_margin * 2) : 0)
        bottomEdgeCenterInset: parentToolInsets.bottomEdgeCenterInset
        bottomEdgeRightInset: parentToolInsets.bottomEdgeRightInset
    }

    Row {
        id: buttonRow
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: _margin
        spacing: _margin / 2

        QGCButton {
            id: cam0Button
            text: qsTr("Cam0")
            width: Math.max(ScreenTools.defaultFontPixelWidth * 4, implicitWidth)
            height: ScreenTools.defaultFontPixelHeight * 2
            enabled: _hasVehicle
            onClicked: _sendServoPulse(990)
        }

        QGCButton {
            id: cam45Button
            text: qsTr("Cam45")
            width: Math.max(ScreenTools.defaultFontPixelWidth * 4, implicitWidth)
            height: ScreenTools.defaultFontPixelHeight * 2
            enabled: _hasVehicle
            onClicked: _sendServoPulse(1500)
        }

        QGCButton {
            id: cam90Button
            text: qsTr("Cam90")
            width: Math.max(ScreenTools.defaultFontPixelWidth * 4, implicitWidth)
            height: ScreenTools.defaultFontPixelHeight * 2
            enabled: _hasVehicle
            onClicked: _sendServoPulse(2000)
        }
    }
}
