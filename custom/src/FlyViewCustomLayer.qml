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
import QGroundControl.C12Camera
import QGroundControl.TopotekCamera

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
    readonly property bool _hasTopotekCamera: _hasActiveLink && _linksManager.activeLink && _linksManager.activeLink.camera1 && _linksManager.activeLink.camera1.cameraType === 3

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

        visible: _hasC12Camera || _hasTopotekCamera
        width: widgetColumn.width
        height: widgetColumn.height
        color: "transparent"

        z: QGroundControl.zOrderWidgets

        Column {
            id: widgetColumn
            spacing: _margin

            // C12 Camera Widget
            Loader {
                id: c12WidgetLoader
                active: _hasC12Camera
                visible: _hasC12Camera
                sourceComponent: C12CameraWidget {
                    c12Controller: _hasCorePlugin ? QGroundControl.corePlugin.c12Controller : null
                }
            }

            // Topotek Camera Widget
            Loader {
                id: topotekWidgetLoader
                active: _hasTopotekCamera
                visible: _hasTopotekCamera
                sourceComponent: TopotekCameraWidget {
                    topotekController: _hasCorePlugin ? QGroundControl.corePlugin.topotekController : null
                }
            }
        }
    }
}
