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

Rectangle {
    id: root

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    property string heading: qsTr("Camera")
    property var cameraConfig: null

    implicitHeight: contentColumn.height + ScreenTools.defaultFontPixelHeight
    color: "transparent"
    border.color: qgcPal.groupBorder
    border.width: 1
    radius: 4

    readonly property var _cameraTypes: [
        qsTr("Generic IP Camera"),
        qsTr("Herelink HDMI"),
        qsTr("Skydroid C12"),
        qsTr("Topotek KHP290A609")
    ]

    // Check if streams should be read-only based on camera type
    readonly property bool _isPresetCamera: cameraConfig && cameraConfig.cameraType > 0

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: ScreenTools.defaultFontPixelHeight / 2
        spacing: ScreenTools.defaultFontPixelHeight / 2

        // Header
        QGCLabel {
            text: heading
            font.bold: true
        }

        // Camera Name
        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth

            QGCLabel {
                text: qsTr("Name:")
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12
            }

            QGCTextField {
                id: cameraNameField
                Layout.fillWidth: true
                placeholderText: qsTr("Camera name (optional)")
                text: cameraConfig ? cameraConfig.name : ""
                onTextChanged: {
                    if (cameraConfig) {
                        cameraConfig.name = text
                    }
                }
            }
        }

        // Camera Type
        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth

            QGCLabel {
                text: qsTr("Type:")
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12
            }

            QGCComboBox {
                id: cameraTypeCombo
                Layout.fillWidth: true
                model: _cameraTypes
                currentIndex: cameraConfig ? cameraConfig.cameraType : 0
                onActivated: (index) => {
                    if (cameraConfig) {
                        cameraConfig.cameraType = index
                        cameraConfig.applyPreset()
                        // Update text fields
                        stream1NameField.text = cameraConfig.stream1.name
                        stream1UrlField.text = cameraConfig.stream1.rtspUrl
                        stream2NameField.text = cameraConfig.stream2.name
                        stream2UrlField.text = cameraConfig.stream2.rtspUrl
                    }
                }
            }
        }

        // C12 Camera Configuration (only visible when SkydroidC12 selected)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelHeight / 4
            visible: cameraConfig && cameraConfig.cameraType === 2 // SkydroidC12

            QGCLabel {
                text: qsTr("C12 Camera Settings")
                font.bold: true
            }

            // Camera IP
            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text: qsTr("Camera IP:")
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12
                }

                QGCTextField {
                    id: c12IpField
                    Layout.fillWidth: true
                    placeholderText: "192.168.144.108"
                    text: cameraConfig ? cameraConfig.c12CameraIp : ""
                    onTextChanged: {
                        if (cameraConfig) {
                            cameraConfig.c12CameraIp = text
                        }
                    }
                }
            }

            // RTSP Stream 1 Suffix
            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text: qsTr("RTSP1 Suffix:")
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12
                }

                QGCTextField {
                    id: c12Rtsp1Field
                    Layout.fillWidth: true
                    placeholderText: "554/stream=1"
                    text: cameraConfig ? cameraConfig.c12Rtsp1Suffix : ""
                    onTextChanged: {
                        if (cameraConfig) {
                            cameraConfig.c12Rtsp1Suffix = text
                        }
                    }
                }
            }

            // RTSP Stream 2 Suffix
            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text: qsTr("RTSP2 Suffix:")
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12
                }

                QGCTextField {
                    id: c12Rtsp2Field
                    Layout.fillWidth: true
                    placeholderText: "555/stream=2"
                    text: cameraConfig ? cameraConfig.c12Rtsp2Suffix : ""
                    onTextChanged: {
                        if (cameraConfig) {
                            cameraConfig.c12Rtsp2Suffix = text
                        }
                    }
                }
            }

            // Control Port
            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text: qsTr("Control Port:")
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12
                }

                QGCTextField {
                    id: c12PortField
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8
                    placeholderText: "5000"
                    text: cameraConfig ? cameraConfig.c12ControlPort : ""
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator { bottom: 1; top: 65535 }
                    onTextChanged: {
                        if (cameraConfig && text !== "") {
                            cameraConfig.c12ControlPort = parseInt(text)
                        }
                    }
                }
            }

            // Info Label
            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("RTSP URLs will be auto-generated: rtsp://[IP]:[Suffix]")
                font.pointSize: ScreenTools.smallFontPointSize
                color: qgcPal.textFieldText
                wrapMode: Text.WordWrap
            }

            // Port Forwarded Connection checkbox
            QGCCheckBox {
                text: qsTr("Port Forwarded Connection")
                checked: cameraConfig ? cameraConfig.portForwarded : false
                onCheckedChanged: {
                    if (cameraConfig) {
                        cameraConfig.portForwarded = checked
                    }
                }
            }

            // Port Forwarding Info Label
            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("Enable if connecting through NAT/port forwarding. Uses TCP transport instead of UDP.")
                font.pointSize: ScreenTools.smallFontPointSize
                color: qgcPal.textFieldText
                wrapMode: Text.WordWrap
            }
        }

        // Topotek Camera Configuration (only visible when TopotekKHP290A609 selected)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelHeight / 4
            visible: cameraConfig && cameraConfig.cameraType === 3 // TopotekKHP290A609

            QGCLabel {
                text: qsTr("Topotek Camera Settings")
                font.bold: true
            }

            // Camera IP
            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text: qsTr("Camera IP:")
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12
                }

                QGCTextField {
                    id: topotekIpField
                    Layout.fillWidth: true
                    placeholderText: "192.168.144.108"
                    text: cameraConfig ? cameraConfig.topotekCameraIp : ""
                    onTextChanged: {
                        if (cameraConfig) {
                            cameraConfig.topotekCameraIp = text
                        }
                    }
                }
            }

            // RTSP Stream 1 Suffix
            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text: qsTr("RTSP1 Suffix:")
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12
                }

                QGCTextField {
                    id: topotekRtsp1Field
                    Layout.fillWidth: true
                    placeholderText: "554/stream=0"
                    text: cameraConfig ? cameraConfig.topotekRtsp1Suffix : ""
                    onTextChanged: {
                        if (cameraConfig) {
                            cameraConfig.topotekRtsp1Suffix = text
                        }
                    }
                }
            }

            // RTSP Stream 2 Suffix
            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text: qsTr("RTSP2 Suffix:")
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12
                }

                QGCTextField {
                    id: topotekRtsp2Field
                    Layout.fillWidth: true
                    placeholderText: "554/stream=1"
                    text: cameraConfig ? cameraConfig.topotekRtsp2Suffix : ""
                    onTextChanged: {
                        if (cameraConfig) {
                            cameraConfig.topotekRtsp2Suffix = text
                        }
                    }
                }
            }

            // Control Port
            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text: qsTr("Control Port:")
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12
                }

                QGCTextField {
                    id: topotekPortField
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 8
                    placeholderText: "9003"
                    text: cameraConfig ? cameraConfig.topotekControlPort : ""
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator { bottom: 1; top: 65535 }
                    onTextChanged: {
                        if (cameraConfig && text !== "") {
                            cameraConfig.topotekControlPort = parseInt(text)
                        }
                    }
                }
            }

            // Info Label
            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("RTSP URLs will be auto-generated: rtsp://[IP]:[Suffix]")
                font.pointSize: ScreenTools.smallFontPointSize
                color: qgcPal.textFieldText
                wrapMode: Text.WordWrap
            }
        }

        // Stream 1
        ColumnLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelHeight / 4
            visible: cameraConfig && cameraConfig.cameraType !== 2 && cameraConfig.cameraType !== 3  // Hide for C12 and Topotek

            QGCLabel {
                text: qsTr("Stream 1")
                font.pointSize: ScreenTools.smallFontPointSize
                color: qgcPal.textFieldText
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text: qsTr("Name:")
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12
                }

                QGCTextField {
                    id: stream1NameField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Stream name")
                    text: cameraConfig && cameraConfig.stream1 ? cameraConfig.stream1.name : ""
                    onTextChanged: {
                        if (cameraConfig && cameraConfig.stream1) {
                            cameraConfig.stream1.name = text
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text: qsTr("RTSP URL:")
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12
                }

                QGCTextField {
                    id: stream1UrlField
                    Layout.fillWidth: true
                    placeholderText: "rtsp://192.168.1.100:554/stream"
                    text: cameraConfig && cameraConfig.stream1 ? cameraConfig.stream1.rtspUrl : ""
                    readOnly: _isPresetCamera
                    onTextChanged: {
                        if (cameraConfig && cameraConfig.stream1 && !_isPresetCamera) {
                            cameraConfig.stream1.rtspUrl = text
                        }
                    }
                }
            }
        }

        // Stream 2
        ColumnLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelHeight / 4
            visible: cameraConfig && cameraConfig.cameraType !== 2 && cameraConfig.cameraType !== 3  // Hide for C12 and Topotek

            QGCLabel {
                text: qsTr("Stream 2")
                font.pointSize: ScreenTools.smallFontPointSize
                color: qgcPal.textFieldText
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text: qsTr("Name:")
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12
                }

                QGCTextField {
                    id: stream2NameField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Stream name")
                    text: cameraConfig && cameraConfig.stream2 ? cameraConfig.stream2.name : ""
                    onTextChanged: {
                        if (cameraConfig && cameraConfig.stream2) {
                            cameraConfig.stream2.name = text
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text: qsTr("RTSP URL:")
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12
                }

                QGCTextField {
                    id: stream2UrlField
                    Layout.fillWidth: true
                    placeholderText: "rtsp://192.168.1.100:554/stream2"
                    text: cameraConfig && cameraConfig.stream2 ? cameraConfig.stream2.rtspUrl : ""
                    readOnly: _isPresetCamera
                    onTextChanged: {
                        if (cameraConfig && cameraConfig.stream2 && !_isPresetCamera) {
                            cameraConfig.stream2.rtspUrl = text
                        }
                    }
                }
            }
        }

        // Preset note
        QGCLabel {
            Layout.fillWidth: true
            visible: _isPresetCamera
            text: {
                if (cameraConfig && cameraConfig.cameraType === 2) {
                    return qsTr("RTSP URLs are auto-generated from C12 settings above")
                } else if (cameraConfig && cameraConfig.cameraType === 3) {
                    return qsTr("RTSP URLs are auto-generated from Topotek settings above")
                } else {
                    return qsTr("RTSP URLs are preset for this camera type")
                }
            }
            font.pointSize: ScreenTools.smallFontPointSize
            color: qgcPal.textFieldText
            wrapMode: Text.WordWrap
        }
    }
}
