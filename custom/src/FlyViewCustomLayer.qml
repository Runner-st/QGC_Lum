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
        rightEdgeCenterInset: Math.max(parentToolInsets.rightEdgeCenterInset, c12Widget.active && c12Widget.item ? c12Widget.item.width + _margin : 0)
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
    Loader {
        id: c12Widget
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: _margin

        active: _hasC12Camera
        visible: _hasC12Camera

        sourceComponent: Component {
            Item {
                width: widgetRect.width
                height: widgetRect.height

                Rectangle {
                    id: widgetRect
                    width: mainColumn.width + (_margin * 2)
                    height: mainColumn.height + (_margin * 2)
                    radius: ScreenTools.defaultFontPixelWidth * 0.5
                    color: qgcPal.window
                    border.color: qgcPal.text
                    border.width: 1
                    opacity: 0.9

                    property var c12Controller: _hasCorePlugin ? QGroundControl.corePlugin.c12Controller : null
                    property bool isConnected: c12Controller ? c12Controller.isConnected : false
                    property real buttonSize: ScreenTools.defaultFontPixelHeight * 2.5
                    property real itemSpacing: ScreenTools.defaultFontPixelWidth * 0.25

                    QGCPalette { id: qgcPal; colorGroupEnabled: true }

                    ColumnLayout {
                        id: mainColumn
                        anchors.centerIn: parent
                        spacing: widgetRect.itemSpacing

                        // Header
                        QGCLabel {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("C12 Camera")
                            font.pointSize: ScreenTools.smallFontPointSize
                            font.bold: true
                        }

                        // Movement Controls (Joystick pattern)
                        Grid {
                            Layout.alignment: Qt.AlignHCenter
                            columns: 3
                            rows: 3
                            columnSpacing: widgetRect.itemSpacing
                            rowSpacing: widgetRect.itemSpacing

                            // Top row: Up button centered
                            Item { width: widgetRect.buttonSize; height: widgetRect.buttonSize }

                            QGCButton {
                                width: widgetRect.buttonSize
                                height: widgetRect.buttonSize
                                text: "▲"
                                enabled: widgetRect.isConnected
                                autoRepeat: true
                                autoRepeatDelay: 300
                                autoRepeatInterval: 200
                                onClicked: if (widgetRect.c12Controller) widgetRect.c12Controller.moveUp()
                            }

                            Item { width: widgetRect.buttonSize; height: widgetRect.buttonSize }

                            // Middle row: Left and Right buttons
                            QGCButton {
                                width: widgetRect.buttonSize
                                height: widgetRect.buttonSize
                                text: "◀"
                                font.pointSize: ScreenTools.defaultFontPointSize * 2
                                enabled: widgetRect.isConnected
                                autoRepeat: true
                                autoRepeatDelay: 300
                                autoRepeatInterval: 200
                                onClicked: if (widgetRect.c12Controller) widgetRect.c12Controller.moveLeft()
                            }

                            Item { width: widgetRect.buttonSize; height: widgetRect.buttonSize }

                            QGCButton {
                                width: widgetRect.buttonSize
                                height: widgetRect.buttonSize
                                text: "▶"
                                font.pointSize: ScreenTools.defaultFontPointSize * 2
                                enabled: widgetRect.isConnected
                                autoRepeat: true
                                autoRepeatDelay: 300
                                autoRepeatInterval: 200
                                onClicked: if (widgetRect.c12Controller) widgetRect.c12Controller.moveRight()
                            }

                            // Bottom row: Down button centered
                            Item { width: widgetRect.buttonSize; height: widgetRect.buttonSize }

                            QGCButton {
                                width: widgetRect.buttonSize
                                height: widgetRect.buttonSize
                                text: "▼"
                                enabled: widgetRect.isConnected
                                autoRepeat: true
                                autoRepeatDelay: 300
                                autoRepeatInterval: 200
                                onClicked: if (widgetRect.c12Controller) widgetRect.c12Controller.moveDown()
                            }

                            Item { width: widgetRect.buttonSize; height: widgetRect.buttonSize }
                        }

                        // Zoom Controls
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: widgetRect.itemSpacing

                            QGCButton {
                                text: qsTr("Zoom+")
                                Layout.preferredWidth: widgetRect.buttonSize * 1.5
                                Layout.preferredHeight: widgetRect.buttonSize * 0.8
                                enabled: widgetRect.isConnected
                                autoRepeat: true
                                autoRepeatDelay: 300
                                autoRepeatInterval: 200
                                onClicked: if (widgetRect.c12Controller) widgetRect.c12Controller.zoomIn()
                            }

                            QGCButton {
                                text: qsTr("Zoom-")
                                Layout.preferredWidth: widgetRect.buttonSize * 1.5
                                Layout.preferredHeight: widgetRect.buttonSize * 0.8
                                enabled: widgetRect.isConnected
                                autoRepeat: true
                                autoRepeatDelay: 300
                                autoRepeatInterval: 200
                                onClicked: if (widgetRect.c12Controller) widgetRect.c12Controller.zoomOut()
                            }
                        }

                        // Center Controls
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: widgetRect.itemSpacing

                            QGCButton {
                                text: qsTr("Center")
                                Layout.preferredWidth: widgetRect.buttonSize * 1.5
                                Layout.preferredHeight: widgetRect.buttonSize * 0.8
                                enabled: widgetRect.isConnected
                                onClicked: if (widgetRect.c12Controller) widgetRect.c12Controller.centerCamera()
                            }

                            QGCButton {
                                text: qsTr("Tilt")
                                Layout.preferredWidth: widgetRect.buttonSize * 1.5
                                Layout.preferredHeight: widgetRect.buttonSize * 0.8
                                enabled: widgetRect.isConnected
                                onClicked: if (widgetRect.c12Controller) widgetRect.c12Controller.centerTiltOnly()
                            }
                        }

                        // Thermal Controls
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: widgetRect.itemSpacing

                            QGCButton {
                                text: qsTr("Palette")
                                Layout.preferredWidth: widgetRect.buttonSize * 1.5
                                Layout.preferredHeight: widgetRect.buttonSize * 0.8
                                enabled: widgetRect.isConnected
                                onClicked: if (widgetRect.c12Controller) widgetRect.c12Controller.cyclePalette()
                            }

                            QGCButton {
                                text: qsTr("Vert")
                                Layout.preferredWidth: widgetRect.buttonSize * 1.5
                                Layout.preferredHeight: widgetRect.buttonSize * 0.8
                                enabled: widgetRect.isConnected
                                onClicked: if (widgetRect.c12Controller) widgetRect.c12Controller.sendVertCommand()
                            }
                        }
                    }
                }
            }
        }

        z: QGroundControl.zOrderWidgets
    }
}
