/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls




//-------------------------------------------------------------------------
//-- Telemetry RSSI
Item {
    id:             control
    anchors.top:    parent.top
    anchors.bottom: parent.bottom
    width:          telemIcon.width * 1.1

    property bool showIndicator: _hasTelemetry || _showPersistent

    property var  _activeVehicle:   QGroundControl.multiVehicleManager.activeVehicle
    property bool _hasTelemetry:    _activeVehicle ? _activeVehicle.telemetryLRSSI !== 0 : false
    property bool _showPersistent:  false
    property bool _everHadTelemetry: false

    // Persistence timer - keeps indicator visible for 5 seconds after telemetry loss
    // This prevents flickering when Herelink intermittently sends RADIO_STATUS messages
    Timer {
        id: persistenceTimer
        interval: 5000  // 5 seconds
        repeat: false
        onTriggered: _showPersistent = false
    }

    on_HasTelemetryChanged: {
        if (_hasTelemetry) {
            _everHadTelemetry = true
            _showPersistent = true
            persistenceTimer.stop()
        } else if (_everHadTelemetry) {
            // Start countdown to hide
            persistenceTimer.restart()
        }
    }

    QGCColoredImage {
        id:                 telemIcon
        anchors.top:        parent.top
        anchors.bottom:     parent.bottom
        width:              height
        sourceSize.height:  height
        source:             "/qmlimages/TelemRSSI.svg"
        fillMode:           Image.PreserveAspectFit
        color:              qgcPal.buttonText
    }

    MouseArea {
        anchors.fill:   parent
        onClicked:      mainWindow.showIndicatorDrawer(telemRSSIInfoPage, control)
    }

    Component {
        id: telemRSSIInfoPage

        ToolIndicatorPage {
            showExpand: false

            contentComponent: SettingsGroupLayout {
                heading: qsTr("Telemetry RSSI Status")

                LabelledLabel {
                    label:      qsTr("Local RSSI:")
                    labelText:  _activeVehicle.telemetryLRSSI + " " + qsTr("dBm")
                }

                LabelledLabel {
                    label:      qsTr("Remote RSSI:")
                    labelText:  _activeVehicle.telemetryRRSSI + " " + qsTr("dBm")
                }

                LabelledLabel {
                    label:      qsTr("RX Errors:")
                    labelText:  _activeVehicle.telemetryRXErrors
                }

                LabelledLabel {
                    label:      qsTr("Errors Fixed:")
                    labelText:  _activeVehicle.telemetryFixed
                }

                LabelledLabel {
                    label:      qsTr("TX Buffer:")
                    labelText:  _activeVehicle.telemetryTXBuffer
                }

                LabelledLabel {
                    label:      qsTr("Local Noise:")
                    labelText:  _activeVehicle.telemetryLNoise
                }

                LabelledLabel {
                    label:      qsTr("Remote Noise:")
                    labelText:  _activeVehicle.telemetryRNoise
                }
            }
        }
    }
}
