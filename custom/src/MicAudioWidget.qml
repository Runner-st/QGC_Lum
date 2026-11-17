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
import QGroundControl.MicAudio
import "qrc:/Custom/qml/QGroundControl/FlightDisplay" as CustomFlight

// Mic-box bar at the top center of the Fly view:
// on/off switch (RTSP PLAY / TEARDOWN), state, output level, tuning panel.
// It is grey until the first heartbeat (same rule as the servo buttons).
Rectangle {
    id: root

    property var  micAudio: null
    // True after the first heartbeat (active vehicle exists).
    property bool controlsEnabled: false

    readonly property int  _state:     micAudio ? micAudio.state : MicAudioController.Off
    readonly property bool _on:        _state !== MicAudioController.Off && _state !== MicAudioController.Error
    readonly property bool _available: micAudio !== null && micAudio.available
    readonly property var  _status:    micAudio ? micAudio.status : ({})
    readonly property bool _levelValid: micAudio !== null && micAudio.statusValid && _status.rtsp_playing === true
    readonly property real _peakDb:    _levelValid && isFinite(Number(_status.out_peak_db)) ? Number(_status.out_peak_db) : -96
    readonly property bool _clip:      _levelValid && (_status.in_clip_now === true || _status.out_clip_now === true)

    readonly property real _margin:    ScreenTools.defaultFontPixelWidth * 0.5
    readonly property real _rowHeight: ScreenTools.defaultFontPixelHeight * 1.6

    // While the sound plays, the switch stays usable without a vehicle,
    // so the operator can always turn the mic off.
    enabled:      micAudio !== null && (controlsEnabled || _on)
    width:        barRow.implicitWidth + _margin * 4
    height:       _rowHeight + _margin * 2
    radius:       height / 2
    color:        qgcPal.window
    border.color: _clip ? "red" : qgcPal.text
    border.width: 1
    opacity:      enabled ? 0.9 : 0.5

    QGCPalette { id: qgcPal; colorGroupEnabled: root.enabled }

    function _stateColor() {
        switch (_state) {
        case MicAudioController.Connecting:
        case MicAudioController.Reconnecting:
            return "orange"
        case MicAudioController.Playing:
            return "limegreen"
        case MicAudioController.Error:
            return "red"
        default:
            return qgcPal.colorGrey
        }
    }

    function _maybeAutoStart() {
        if (controlsEnabled && micAudio && micAudio.autoStart && _available
                && _state === MicAudioController.Off) {
            micAudio.start()
        }
    }

    onControlsEnabledChanged: _maybeAutoStart()
    on_AvailableChanged: {
        // Close the panel when the mic address is gone (no active link).
        if (!_available) {
            tuningPanel.close()
        }
        _maybeAutoStart()
    }
    Component.onCompleted:    _maybeAutoStart()

    // Link A -> link B keeps "available" true: auto-start on the new host too.
    Connections {
        target: root.micAudio
        function onHostChanged() { root._maybeAutoStart() }
    }

    RowLayout {
        id: barRow
        anchors.centerIn: parent
        spacing: _margin * 2

        QGCColoredImage {
            Layout.preferredWidth:  _rowHeight * 0.8
            Layout.preferredHeight: _rowHeight * 0.8
            source:   "qrc:/InstrumentValueIcons/mic.svg"
            color:    root._stateColor()
            sourceSize.height: height
        }

        QGCSwitch {
            id: onSwitch
            text:    qsTr("MIC")
            checked: root._on
            enabled: root._available && micAudio.audioSupported
            // onToggled covers both click and drag of the switch.
            onToggled: {
                micAudio.toggle()
                checked = Qt.binding(function() { return root._on })
            }
        }

        QGCLabel {
            id: stateLabel
            Layout.maximumWidth: ScreenTools.defaultFontPixelWidth * 22
            elide: Text.ElideRight
            text: {
                if (!micAudio)                return ""
                if (!micAudio.audioSupported) return qsTr("No GStreamer")
                if (!root._available)         return qsTr("No link")
                if (_state === MicAudioController.Error && micAudio.errorText !== "")
                    return micAudio.errorText
                return micAudio.stateText
            }
            color: _state === MicAudioController.Error ? "red" : qgcPal.text

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                ToolTip.visible: containsMouse && micAudio && micAudio.errorText !== ""
                ToolTip.text:    micAudio ? micAudio.errorText : ""
                ToolTip.delay:   300
            }
        }

        // Output peak level, -60..0 dBFS. Red near full scale or on clipping.
        Rectangle {
            id: levelBar
            Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 10
            Layout.preferredHeight: _rowHeight * 0.4
            color:        qgcPal.windowShade
            border.color: qgcPal.text
            border.width: 1

            Rectangle {
                anchors.left:   parent.left
                anchors.top:    parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 1
                width: (parent.width - 2) * Math.max(0, Math.min(1, (root._peakDb + 60) / 60))
                color: (root._clip || root._peakDb > -3) ? "red" : "limegreen"
                visible: root._levelValid
            }
        }

        QGCLabel {
            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 7
            horizontalAlignment: Text.AlignRight
            text: root._levelValid ? root._peakDb.toFixed(0) + " dB" : "-- dB"
            font.pointSize: ScreenTools.smallFontPointSize
        }

        QGCColoredImage {
            id: gearIcon
            Layout.preferredWidth:  _rowHeight * 0.8
            Layout.preferredHeight: _rowHeight * 0.8
            source: "/qmlimages/Gears.svg"
            color:  tuningPanel.opened ? qgcPal.buttonHighlight : qgcPal.text
            sourceSize.height: height
            enabled: root._available

            QGCMouseArea {
                fillItem: parent
                onClicked: tuningPanel.opened ? tuningPanel.close() : tuningPanel.open()
            }
        }
    }

    CustomFlight.MicTuningPanel {
        id: tuningPanel
        micAudio: root.micAudio
        x: (root.width - width) / 2
        y: root.height + root._margin
    }
}
