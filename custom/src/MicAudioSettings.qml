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
import QGroundControl.AppSettings
import QGroundControl.Controls

// Connection settings for the mic-box. The host is the server address of the
// active Links Manager link (the router forwards the ports to the mic).
SettingsPage {
    id: root

    readonly property var _mic: QGroundControl.corePlugin ? QGroundControl.corePlugin.micAudio : null
    readonly property real _fieldWidth: ScreenTools.defaultFontPixelWidth * 12

    SettingsGroupLayout {
        Layout.fillWidth: true
        heading: qsTr("Mic Audio")
        headingDescription: qsTr("The mic address is the server address of the active link in Links Manager.")
        visible: _mic !== null

        RowLayout {
            Layout.fillWidth: true
            QGCLabel { text: qsTr("Mic host (from active link)"); Layout.fillWidth: true }
            QGCLabel { text: _mic && _mic.host !== "" ? _mic.host : qsTr("no active link") }
        }

        RowLayout {
            Layout.fillWidth: true
            QGCLabel { text: qsTr("RTSP port (stream)"); Layout.fillWidth: true }
            QGCTextField {
                Layout.preferredWidth: _fieldWidth
                numericValuesOnly: true
                validator: IntValidator { bottom: 1; top: 65535 }
                text: _mic ? _mic.rtspPort : ""
                onEditingFinished: if (acceptableInput) _mic.rtspPort = parseInt(text)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            QGCLabel { text: qsTr("HTTP port (tuning API)"); Layout.fillWidth: true }
            QGCTextField {
                Layout.preferredWidth: _fieldWidth
                numericValuesOnly: true
                validator: IntValidator { bottom: 1; top: 65535 }
                text: _mic ? _mic.httpPort : ""
                onEditingFinished: if (acceptableInput) _mic.httpPort = parseInt(text)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            QGCLabel { text: qsTr("RTSP transport"); Layout.fillWidth: true }
            QGCComboBox {
                Layout.preferredWidth: _fieldWidth
                model: [ qsTr("UDP"), qsTr("TCP") ]
                currentIndex: _mic && _mic.useTcp ? 1 : 0
                onActivated: (index) => { _mic.useTcp = (index === 1) }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            QGCLabel { text: qsTr("Jitter buffer latency, ms"); Layout.fillWidth: true }
            QGCTextField {
                Layout.preferredWidth: _fieldWidth
                numericValuesOnly: true
                validator: IntValidator { bottom: 0; top: 2000 }
                text: _mic ? _mic.latencyMs : ""
                onEditingFinished: if (acceptableInput) _mic.latencyMs = parseInt(text)
            }
        }

        QGCCheckBoxSlider {
            Layout.fillWidth: true
            text: qsTr("Start listening on first heartbeat")
            checked: _mic ? _mic.autoStart : false
            onClicked: _mic.autoStart = checked
        }

        QGCLabel {
            Layout.fillWidth: true
            text: qsTr("Port, transport and latency changes apply the next time you turn the mic on. "
                       + "The mic serves one listener: a new client takes the stream from the current one. "
                       + "Do not keep the mic web page open together with QGC: both read the same level window.")
            wrapMode: Text.WordWrap
            font.pointSize: ScreenTools.smallFontPointSize
        }
    }
}
