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

// Topotek KHP290A609 Camera Control Widget
// Provides PTZ, zoom, thermal controls with smart button behavior:
// - Brief tap: command → 0.2s → stop
// - Press & hold: continuous command → stop on release
Rectangle {
    id: root

    width: mainColumn.width + (_margin * 2)
    height: mainColumn.height + (_margin * 2)
    radius: ScreenTools.defaultFontPixelWidth * 0.5
    color: qgcPal.window
    border.color: qgcPal.text
    border.width: 1
    opacity: 0.9

    property var topotekController: null
    property bool isConnected: topotekController ? topotekController.isConnected : false

    readonly property real _margin: ScreenTools.defaultFontPixelWidth * 0.5
    readonly property real _buttonSize: ScreenTools.defaultFontPixelHeight * 2.5
    readonly property real _spacing: ScreenTools.defaultFontPixelWidth * 0.25

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    // Auto-center on connection
    Connections {
        target: topotekController
        function onConnected() {
            if (topotekController && topotekController.isConnected) {
                autoCenterTimer.start()
            }
        }
    }

    Timer {
        id: autoCenterTimer
        interval: 500  // 500ms delay after connection
        repeat: false
        onTriggered: {
            if (topotekController && topotekController.isConnected) {
                topotekController.centerGimbal()
            }
        }
    }

    // Shared timer for brief tap stop delay
    Timer {
        id: stopDelayTimer
        interval: 200
        repeat: false
        property var targetButton: null
        onTriggered: {
            if (targetButton) {
                targetButton.stopCommand()
            }
        }
    }

    ColumnLayout {
        id: mainColumn
        anchors.centerIn: parent
        spacing: _spacing

        // Header
        QGCLabel {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Topotek")
            font.pointSize: ScreenTools.smallFontPointSize
            font.bold: true
        }

        // Movement Controls (Joystick with icons)
        Grid {
            Layout.alignment: Qt.AlignHCenter
            columns: 3
            rows: 3
            columnSpacing: _spacing
            rowSpacing: _spacing

            // Top row: empty, tilt up, empty
            Item { width: _buttonSize; height: _buttonSize }

            ContinuousButton {
                buttonWidth: _buttonSize
                buttonHeight: _buttonSize
                iconText: "▲"
                buttonEnabled: isConnected
                onStartCommand: if (topotekController) topotekController.tiltUp()
                onStopCommand: if (topotekController) topotekController.stopPanTilt()
            }

            Item { width: _buttonSize; height: _buttonSize }

            // Middle row: pan left, center, pan right
            ContinuousButton {
                buttonWidth: _buttonSize
                buttonHeight: _buttonSize
                iconText: "◀"
                buttonEnabled: isConnected
                onStartCommand: if (topotekController) topotekController.panLeft()
                onStopCommand: if (topotekController) topotekController.stopPanTilt()
            }

            // Center button
            QGCButton {
                width: _buttonSize
                height: _buttonSize
                text: "⊙"
                font.pointSize: ScreenTools.largeFontPointSize
                font.bold: true
                enabled: isConnected
                onClicked: if (topotekController) topotekController.centerGimbal()
            }

            ContinuousButton {
                buttonWidth: _buttonSize
                buttonHeight: _buttonSize
                iconText: "▶"
                buttonEnabled: isConnected
                onStartCommand: if (topotekController) topotekController.panRight()
                onStopCommand: if (topotekController) topotekController.stopPanTilt()
            }

            // Bottom row: empty, tilt down, empty
            Item { width: _buttonSize; height: _buttonSize }

            ContinuousButton {
                buttonWidth: _buttonSize
                buttonHeight: _buttonSize
                iconText: "▼"
                buttonEnabled: isConnected
                onStartCommand: if (topotekController) topotekController.tiltDown()
                onStopCommand: if (topotekController) topotekController.stopPanTilt()
            }

            Item { width: _buttonSize; height: _buttonSize }
        }

        // Day Zoom Controls
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            color: "transparent"
            border.color: qgcPal.text
            border.width: 1
            radius: ScreenTools.defaultFontPixelWidth * 0.25
            width: dayZoomColumn.width + (_spacing * 2)
            height: dayZoomColumn.height + (_spacing * 2)

            ColumnLayout {
                id: dayZoomColumn
                anchors.centerIn: parent
                spacing: _spacing * 0.5

                QGCLabel {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Day Zoom")
                    font.pointSize: ScreenTools.smallFontPointSize
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: _spacing

                    ContinuousButton {
                        buttonWidth: _buttonSize
                        buttonHeight: _buttonSize * 0.7
                        iconText: "+"
                        buttonEnabled: isConnected
                                onStartCommand: if (topotekController) topotekController.dayZoomIn()
                        onStopCommand: if (topotekController) topotekController.stopDayZoom()
                    }

                    ContinuousButton {
                        buttonWidth: _buttonSize
                        buttonHeight: _buttonSize * 0.7
                        iconText: "-"
                        buttonEnabled: isConnected
                                onStartCommand: if (topotekController) topotekController.dayZoomOut()
                        onStopCommand: if (topotekController) topotekController.stopDayZoom()
                    }
                }
            }
        }

        // Thermal Zoom Controls
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            color: "transparent"
            border.color: qgcPal.text
            border.width: 1
            radius: ScreenTools.defaultFontPixelWidth * 0.25
            width: thermalZoomColumn.width + (_spacing * 2)
            height: thermalZoomColumn.height + (_spacing * 2)

            ColumnLayout {
                id: thermalZoomColumn
                anchors.centerIn: parent
                spacing: _spacing * 0.5

                QGCLabel {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Thermal Zoom")
                    font.pointSize: ScreenTools.smallFontPointSize
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: _spacing

                    ContinuousButton {
                        buttonWidth: _buttonSize
                        buttonHeight: _buttonSize * 0.7
                        iconText: "+"
                        buttonEnabled: isConnected
                                onStartCommand: if (topotekController) topotekController.thermalZoomIn()
                        onStopCommand: if (topotekController) topotekController.stopThermalZoom()
                    }

                    ContinuousButton {
                        buttonWidth: _buttonSize
                        buttonHeight: _buttonSize * 0.7
                        iconText: "-"
                        buttonEnabled: isConnected
                                onStartCommand: if (topotekController) topotekController.thermalZoomOut()
                        onStopCommand: if (topotekController) topotekController.stopThermalZoom()
                    }
                }
            }
        }

        // Feature buttons row 1
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: _spacing

            QGCButton {
                text: qsTr("Palette")
                enabled: isConnected
                Layout.preferredWidth: _buttonSize * 1.3
                Layout.preferredHeight: _buttonSize * 0.7
                onClicked: if (topotekController) topotekController.cyclePalette()
            }

            QGCButton {
                text: qsTr("PIP")
                enabled: isConnected
                Layout.preferredWidth: _buttonSize * 1.3
                Layout.preferredHeight: _buttonSize * 0.7
                onClicked: if (topotekController) topotekController.togglePIP()
            }
        }

        // Feature buttons row 2
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: _spacing

            QGCButton {
                text: qsTr("Follow")
                enabled: isConnected
                Layout.preferredWidth: _buttonSize * 1.3
                Layout.preferredHeight: _buttonSize * 0.7
                onClicked: if (topotekController) topotekController.setFollowMode()
            }

            QGCButton {
                text: qsTr("Lock")
                enabled: isConnected
                Layout.preferredWidth: _buttonSize * 1.3
                Layout.preferredHeight: _buttonSize * 0.7
                onClicked: if (topotekController) topotekController.setLockMode()
            }
        }

        // Feature buttons row 3
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: _spacing

            QGCButton {
                text: qsTr("Tilt")
                enabled: isConnected
                Layout.preferredWidth: _buttonSize * 1.3
                Layout.preferredHeight: _buttonSize * 0.7
                onClicked: if (topotekController) topotekController.tiltDown90()
            }

            QGCButton {
                text: qsTr("IR Cut")
                enabled: isConnected
                Layout.preferredWidth: _buttonSize * 1.3
                Layout.preferredHeight: _buttonSize * 0.7
                onClicked: if (topotekController) topotekController.toggleIRCut()
            }
        }

        // Defog controls
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            color: "transparent"
            border.color: qgcPal.text
            border.width: 1
            radius: ScreenTools.defaultFontPixelWidth * 0.25
            width: defogColumn.width + (_spacing * 2)
            height: defogColumn.height + (_spacing * 2)

            ColumnLayout {
                id: defogColumn
                anchors.centerIn: parent
                spacing: _spacing * 0.5

                QGCLabel {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Defog")
                    font.pointSize: ScreenTools.smallFontPointSize
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: _spacing

                    QGCButton {
                        text: "+"
                        enabled: isConnected
                        width: _buttonSize
                        height: _buttonSize * 0.7
                        onClicked: if (topotekController) topotekController.increaseDefog()
                    }

                    QGCButton {
                        text: "-"
                        enabled: isConnected
                        width: _buttonSize
                        height: _buttonSize * 0.7
                        onClicked: if (topotekController) topotekController.decreaseDefog()
                    }
                }
            }
        }
    }

    // Continuous Button Component
    // Implements smart press/hold logic:
    // - Brief tap: command → 0.2s → stop
    // - Press & hold: continuous command → stop on release
    component ContinuousButton: Rectangle {
        id: btn

        property real buttonWidth: _buttonSize
        property real buttonHeight: _buttonSize
        property string iconText: ""
        property bool buttonEnabled: false

        signal startCommand()
        signal stopCommand()

        // Local palette for this component - colorGroupEnabled bound to buttonEnabled
        QGCPalette { id: btnPal; colorGroupEnabled: buttonEnabled }

        width: buttonWidth
        height: buttonHeight
        radius: ScreenTools.defaultFontPixelWidth * 0.25
        color: mouseArea.pressed ? btnPal.buttonHighlight : btnPal.button

        property bool isHolding: false
        property real pressStartTime: 0
        readonly property real holdThreshold: 200  // milliseconds

        QGCLabel {
            anchors.centerIn: parent
            text: iconText
            font.pointSize: ScreenTools.largeFontPointSize
            color: btnPal.buttonText
        }

        Timer {
            id: holdDetectionTimer
            interval: holdThreshold
            repeat: false
            onTriggered: {
                btn.isHolding = true
                repeatTimer.start()
            }
        }

        Timer {
            id: repeatTimer
            interval: 100  // Send command every 100ms while holding
            repeat: true
            onTriggered: {
                btn.startCommand()
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            enabled: buttonEnabled

            onPressed: {
                btn.pressStartTime = Date.now()
                btn.isHolding = false
                holdDetectionTimer.start()
                btn.startCommand()
            }

            onReleased: {
                holdDetectionTimer.stop()
                repeatTimer.stop()

                var pressDuration = Date.now() - btn.pressStartTime

                if (btn.isHolding) {
                    // Was holding - immediately send stop
                    btn.stopCommand()
                } else {
                    // Was brief tap - schedule stop after 200ms from press start
                    var remainingTime = holdThreshold - pressDuration
                    if (remainingTime > 0) {
                        stopDelayTimer.interval = remainingTime
                    } else {
                        stopDelayTimer.interval = 0
                    }
                    stopDelayTimer.targetButton = btn
                    stopDelayTimer.start()
                }

                btn.isHolding = false
            }

            onCanceled: {
                holdDetectionTimer.stop()
                repeatTimer.stop()
                if (btn.isHolding) {
                    btn.stopCommand()
                }
                btn.isHolding = false
            }
        }
    }
}
