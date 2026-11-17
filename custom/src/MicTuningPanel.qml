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

// Drop-down tuning panel for the mic-box (same controls as the board web page).
// Sliders show the values the board returned (it clamps and rounds them).
// Tuning works without listening; levels make sense only while RTSP plays.
Popup {
    id: root

    property var micAudio: null

    readonly property var  _cfg:      micAudio ? micAudio.config : ({})
    readonly property bool _loaded:   micAudio !== null && micAudio.configLoaded
    readonly property var  _status:   micAudio ? micAudio.status : ({})
    readonly property real _margin:   ScreenTools.defaultFontPixelWidth
    readonly property real _maxHeight: mainWindow.height * 0.7
    property bool _showHints: false

    width:       ScreenTools.defaultFontPixelWidth * 46
    height:      Math.min(contentColumn.implicitHeight + padding * 2, _maxHeight)
    padding:     _margin
    modal:       false
    focus:       true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    // Keep the controller that was told "open", so it is told "closed" even
    // if micAudio changes or the popup is destroyed while open.
    property var _openedMic: null

    function _releaseMic() {
        if (_openedMic) {
            _openedMic.panelOpen = false
            _openedMic = null
        }
    }

    onOpened: {
        _releaseMic()
        _openedMic = micAudio
        if (_openedMic) _openedMic.panelOpen = true
    }
    onClosed:               _releaseMic()
    onMicAudioChanged:      close()
    Component.onDestruction: _releaseMic()

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    background: Rectangle {
        color:        qgcPal.window
        border.color: qgcPal.text
        border.width: 1
        radius:       ScreenTools.defaultFontPixelWidth * 0.5
        opacity:      0.95
    }

    function _fmt(value, decimals) {
        return value === undefined ? "--" : Number(value).toFixed(decimals)
    }

    // Slider for one board config key.
    component CfgSlider: ColumnLayout {
        id: cs

        property string key
        property string label
        property string hint
        property int    decimals: 0
        property alias  from:     slider.from
        property alias  to:       slider.to
        property alias  stepSize: slider.stepSize

        Layout.fillWidth: true
        spacing: 0

        function sync() {
            var v = root._cfg[key]
            // Skip while the user drags or while newer changes are not answered.
            if (v !== undefined && !slider.pressed && !root.micAudio.configPending) {
                slider.value = Number(v)
            }
        }

        Component.onCompleted: sync()
        Connections {
            target: root.micAudio
            function onConfigChanged() { cs.sync() }
        }

        RowLayout {
            Layout.fillWidth: true
            QGCLabel { text: cs.label; Layout.fillWidth: true }
            QGCLabel {
                text: root._loaded ? Number(slider.value).toFixed(cs.decimals) : "--"
                font.bold: true
            }
        }
        QGCSlider {
            id: slider
            Layout.fillWidth: true
            enabled: root._loaded
            snapMode: Slider.SnapAlways
            onMoved: root.micAudio.setConfigValue(cs.key, value)
        }
        QGCLabel {
            Layout.fillWidth: true
            visible: root._showHints && cs.hint !== ""
            text: cs.hint
            wrapMode: Text.WordWrap
            font.pointSize: ScreenTools.smallFontPointSize
            color: qgcPal.colorGrey
        }
    }

    // Check box for one boolean board config key.
    component CfgCheck: ColumnLayout {
        id: cc

        property string key
        property string label
        property string hint

        Layout.fillWidth: true
        spacing: 0

        function sync() {
            var v = root._cfg[key]
            if (v !== undefined && !root.micAudio.configPending) {
                box.checked = v === true || v === 1 || v === "1"
            }
        }

        Component.onCompleted: sync()
        Connections {
            target: root.micAudio
            function onConfigChanged() { cc.sync() }
        }

        QGCCheckBox {
            id: box
            text: cc.label
            enabled: root._loaded
            onClicked: root.micAudio.setConfigValue(cc.key, checked)
        }
        QGCLabel {
            Layout.fillWidth: true
            visible: root._showHints && cc.hint !== ""
            text: cc.hint
            wrapMode: Text.WordWrap
            font.pointSize: ScreenTools.smallFontPointSize
            color: qgcPal.colorGrey
        }
    }

    contentItem: QGCFlickable {
        clip:          true
        contentWidth:  width
        contentHeight: contentColumn.implicitHeight

        ColumnLayout {
            id: contentColumn
            width: parent.width
            spacing: _margin * 0.75

            // ---- Header and status ----
            RowLayout {
                Layout.fillWidth: true
                QGCLabel {
                    Layout.fillWidth: true
                    text: qsTr("Mic tuning") + (micAudio && micAudio.host !== "" ? "  (" + micAudio.host + ")" : "")
                    font.bold: true
                }
                QGCCheckBox {
                    text: qsTr("Hints")
                    checked: root._showHints
                    onClicked: root._showHints = checked
                }
            }

            QGCLabel {
                Layout.fillWidth: true
                visible: micAudio !== null && !micAudio.reachable
                text: _loaded ? qsTr("Mic not reachable") : qsTr("Waiting for the mic...")
                color: "orange"
            }

            QGCLabel {
                Layout.fillWidth: true
                visible: micAudio !== null && micAudio.statusValid
                font.pointSize: ScreenTools.smallFontPointSize
                font.family: ScreenTools.fixedFontFamily
                text: micAudio && micAudio.statusValid
                      ? qsTr("RTSP client %1, playing %2\nin peak %3 dB  out peak %4 dB  rms %5 dB%6")
                            .arg(_status.rtsp_client ? qsTr("yes") : qsTr("no"))
                            .arg(_status.rtsp_playing ? qsTr("yes") : qsTr("no"))
                            .arg(_fmt(_status.in_peak_db, 1))
                            .arg(_fmt(_status.out_peak_db, 1))
                            .arg(_fmt(_status.out_rms_db, 1))
                            .arg((_status.in_clip_now || _status.out_clip_now) ? qsTr("  CLIP") : "")
                      : ""
                color: (_status.in_clip_now || _status.out_clip_now) ? "red" : qgcPal.text
            }

            // ---- Codec and gain ----
            CfgSlider {
                key: "pga_db"; label: qsTr("Codec PGA, dB")
                from: 0; to: 30; stepSize: 3
                hint: qsTr("Analog mic preamp in the codec (3 dB steps). Raise it for quiet sources; lower it if \"in clip\" keeps counting. Most effective for signal-to-noise.")
            }
            CfgSlider {
                key: "adc_scale"; label: qsTr("Codec ADC scale")
                from: 0; to: 7; stepSize: 1
                hint: qsTr("Digital gain stage in the codec (coarse). Lower it if the input clips even with a low PGA.")
            }
            CfgSlider {
                key: "adc_vol"; label: qsTr("Codec ADC volume")
                from: 0; to: 255; stepSize: 1
                hint: qsTr("Fine ADC volume in the codec (200 is about 0 dB). Leave near the default; use it for small trims.")
            }
            CfgSlider {
                key: "gain_db"; label: qsTr("Software gain, dB")
                from: -24; to: 36; stepSize: 0.5; decimals: 1
                hint: qsTr("Software gain applied after the filters. Use it for final loudness; it cannot fix input clipping (reduce PGA/scale for that).")
            }

            // ---- High-pass ----
            CfgCheck {
                key: "hpf_on"; label: qsTr("High-pass filter")
                hint: qsTr("Cuts low frequencies (wind rumble, handling noise) below the cut-off. Also removes engine and other low sounds.")
            }
            CfgSlider {
                key: "hpf_hz"; label: qsTr("High-pass cut-off, Hz")
                from: 40; to: 1000; stepSize: 5
                hint: qsTr("Frequency where the filter is 3 dB down. Raise it until wind disappears, stop before engines or voices get thin (voice: keep below ~300 Hz).")
            }
            CfgSlider {
                key: "hpf_order"; label: qsTr("High-pass order")
                from: 2; to: 6; stepSize: 2
                hint: qsTr("Filter steepness: 2 = 12 dB/oct, 4 = 24 dB/oct, 6 = 36 dB/oct. Steeper removes more below the cut-off but sounds less natural.")
            }

            // ---- Low-pass ----
            CfgCheck {
                key: "lpf_on"; label: qsTr("Low-pass filter")
                hint: qsTr("Cuts high frequencies (hiss, wind whistle, electrical noise) above the cut-off. Together with the high-pass it sets the band you hear.")
            }
            CfgSlider {
                key: "lpf_hz"; label: qsTr("Low-pass cut-off, Hz")
                from: 300; to: 3800; stepSize: 50
                hint: qsTr("Frequency where the filter is 3 dB down. Nothing above 4000 Hz exists in the 8 kHz stream. Kept at least 100 Hz above the high-pass.")
            }
            CfgSlider {
                key: "lpf_order"; label: qsTr("Low-pass order")
                from: 2; to: 6; stepSize: 2
                hint: qsTr("Same steepness choice as for the high-pass: 2 = 12 dB/oct, 4 = 24, 6 = 36.")
            }

            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("Changes apply at once but are lost on mic reboot until you press Save.")
                wrapMode: Text.WordWrap
                font.pointSize: ScreenTools.smallFontPointSize
                color: qgcPal.colorGrey
            }

            RowLayout {
                Layout.fillWidth: true
                QGCButton {
                    text: qsTr("Save to flash")
                    enabled: root._loaded
                    onClicked: micAudio.saveConfig()
                }
                QGCButton {
                    text: qsTr("Reset to defaults")
                    enabled: root._loaded
                    onClicked: micAudio.resetConfig()
                }
                QGCButton {
                    text: qsTr("Reload")
                    onClicked: micAudio.refreshConfig()
                }
            }

            QGCLabel {
                Layout.fillWidth: true
                visible: text !== ""
                text: micAudio ? micAudio.tuningMessage : ""
                wrapMode: Text.WordWrap
            }

            // ---- Local playback (this computer only) ----
            Rectangle { Layout.fillWidth: true; height: 1; color: qgcPal.groupBorder }

            RowLayout {
                Layout.fillWidth: true
                QGCLabel { text: qsTr("Local volume") }
                QGCSlider {
                    id: volumeSlider
                    Layout.fillWidth: true
                    from: 0; to: 2; stepSize: 0.05
                    value: micAudio ? micAudio.volume : 1
                    onMoved: micAudio.volume = value
                }
                QGCLabel { text: Math.round(volumeSlider.value * 100) + "%" }
                QGCCheckBox {
                    text: qsTr("Mute")
                    checked: micAudio ? micAudio.muted : false
                    onClicked: micAudio.muted = checked
                }
            }
        }
    }
}
