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
        qsTr("Skydroid C12")
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

        // Stream 1
        ColumnLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelHeight / 4

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
            text: qsTr("RTSP URLs are preset for this camera type")
            font.pointSize: ScreenTools.smallFontPointSize
            color: qgcPal.textFieldText
            wrapMode: Text.WordWrap
        }
    }
}
