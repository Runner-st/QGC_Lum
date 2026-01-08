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

// C12 Camera Control Widget
// Provides PTZ, zoom, and thermal palette controls for Skydroid C12
Rectangle {
    id: root

    width: mainColumn.width + (_margin * 2)
    height: mainColumn.height + (_margin * 2)
    radius: ScreenTools.defaultFontPixelWidth * 0.5
    color: qgcPal.window
    border.color: qgcPal.text
    border.width: 1
    opacity: 0.9

    property var c12Controller: null
    property bool isConnected: c12Controller ? c12Controller.isConnected : false

    readonly property real _margin: ScreenTools.defaultFontPixelWidth * 0.5
    readonly property real _buttonSize: ScreenTools.defaultFontPixelHeight * 2.5
    readonly property real _spacing: ScreenTools.defaultFontPixelWidth * 0.25

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    ColumnLayout {
        id: mainColumn
        anchors.centerIn: parent
        spacing: _spacing

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
            columnSpacing: _spacing
            rowSpacing: _spacing

            // Top row: Up button centered
            Item { width: _buttonSize; height: _buttonSize }

            QGCButton {
                id: upButton
                width: _buttonSize
                height: _buttonSize
                text: "▲"
                enabled: isConnected
                autoRepeat: true
                autoRepeatDelay: 300
                autoRepeatInterval: 200
                onClicked: if (c12Controller) c12Controller.moveUp()
            }

            Item { width: _buttonSize; height: _buttonSize }

            // Middle row: Left and Right buttons
            QGCButton {
                id: leftButton
                width: _buttonSize
                height: _buttonSize
                text: "◀"
                font.pointSize: ScreenTools.defaultFontPointSize * 2
                enabled: isConnected
                autoRepeat: true
                autoRepeatDelay: 300
                autoRepeatInterval: 200
                onClicked: if (c12Controller) c12Controller.moveLeft()
            }

            Item { width: _buttonSize; height: _buttonSize } // Center space

            QGCButton {
                id: rightButton
                width: _buttonSize
                height: _buttonSize
                text: "▶"
                font.pointSize: ScreenTools.defaultFontPointSize * 2
                enabled: isConnected
                autoRepeat: true
                autoRepeatDelay: 300
                autoRepeatInterval: 200
                onClicked: if (c12Controller) c12Controller.moveRight()
            }

            // Bottom row: Down button centered
            Item { width: _buttonSize; height: _buttonSize }

            QGCButton {
                id: downButton
                width: _buttonSize
                height: _buttonSize
                text: "▼"
                enabled: isConnected
                autoRepeat: true
                autoRepeatDelay: 300
                autoRepeatInterval: 200
                onClicked: if (c12Controller) c12Controller.moveDown()
            }

            Item { width: _buttonSize; height: _buttonSize }
        }

        // Zoom Controls
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: _spacing

            QGCButton {
                text: qsTr("Zoom+")
                Layout.preferredWidth: _buttonSize * 1.5
                Layout.preferredHeight: _buttonSize * 0.8
                enabled: isConnected
                autoRepeat: true
                autoRepeatDelay: 300
                autoRepeatInterval: 200
                onClicked: if (c12Controller) c12Controller.zoomIn()
            }

            QGCButton {
                text: qsTr("Zoom-")
                Layout.preferredWidth: _buttonSize * 1.5
                Layout.preferredHeight: _buttonSize * 0.8
                enabled: isConnected
                autoRepeat: true
                autoRepeatDelay: 300
                autoRepeatInterval: 200
                onClicked: if (c12Controller) c12Controller.zoomOut()
            }
        }

        // Center Controls
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: _spacing

            QGCButton {
                text: qsTr("Center")
                Layout.preferredWidth: _buttonSize * 1.5
                Layout.preferredHeight: _buttonSize * 0.8
                enabled: isConnected
                onClicked: if (c12Controller) c12Controller.centerCamera()
            }

            QGCButton {
                text: qsTr("Tilt")
                Layout.preferredWidth: _buttonSize * 1.5
                Layout.preferredHeight: _buttonSize * 0.8
                enabled: isConnected
                onClicked: if (c12Controller) c12Controller.centerTiltOnly()
            }
        }

        // Thermal Controls
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: _spacing

            QGCButton {
                text: qsTr("Palette")
                Layout.preferredWidth: _buttonSize * 1.5
                Layout.preferredHeight: _buttonSize * 0.8
                enabled: isConnected
                onClicked: if (c12Controller) c12Controller.cyclePalette()
            }

            QGCButton {
                text: qsTr("Vert")
                Layout.preferredWidth: _buttonSize * 1.5
                Layout.preferredHeight: _buttonSize * 0.8
                enabled: isConnected
                onClicked: if (c12Controller) c12Controller.sendVertCommand()
            }
        }
    }
}
