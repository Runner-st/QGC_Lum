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

Item {
    id: root

    readonly property var manager: QGroundControl.corePlugin ? QGroundControl.corePlugin.cameraManager : null

    property string cameraName: ""
    property string cameraUrl: ""
    property int editingIndex: -1

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    function startNewCamera() {
        editingIndex = -1
        cameraName = ""
        cameraUrl = ""
    }

    function editCamera(index) {
        if (!manager) {
            return
        }

        const data = manager.cameraAt(index)
        if (!data || data.name === undefined) {
            return
        }

        editingIndex = index
        cameraName = data.name
        cameraUrl = data.url
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelWidth
        spacing: ScreenTools.defaultFontPixelHeight

        SectionHeader {
            text: qsTr("Camera manager")
        }

        QGCLabel {
            wrapMode: Text.WordWrap
            text: qsTr("Configure RTSP video streams used by the Camera manager plugin. The first saved camera is used as the primary video stream by default.")
        }

        RowLayout {
            spacing: ScreenTools.defaultFontPixelWidth

            QGCButton {
                text: qsTr("Add new")
                onClicked: startNewCamera()
            }

            QGCButton {
                text: editingIndex >= 0 ? qsTr("Save changes") : qsTr("Save")
                enabled: manager && cameraName.trim().length > 0 && cameraUrl.trim().length > 0
                onClicked: {
                    if (!manager) {
                        return
                    }

                    if (editingIndex >= 0) {
                        manager.updateCamera(editingIndex, cameraName, cameraUrl)
                    } else {
                        manager.addCamera(cameraName, cameraUrl)
                    }
                    startNewCamera()
                }
            }

            QGCButton {
                text: qsTr("Cancel")
                visible: editingIndex >= 0
                onClicked: startNewCamera()
            }
        }

        GridLayout {
            columns: 2
            columnSpacing: ScreenTools.defaultFontPixelWidth
            rowSpacing: ScreenTools.defaultFontPixelHeight / 2

            QGCLabel {
                text: qsTr("Camera name")
            }

            QGCTextField {
                text: root.cameraName
                onTextChanged: root.cameraName = text
                placeholderText: qsTr("e.g. Front camera")
                Layout.fillWidth: true
            }

            QGCLabel {
                text: qsTr("URL")
            }

            QGCTextField {
                text: root.cameraUrl
                onTextChanged: root.cameraUrl = text
                placeholderText: qsTr("rtsp://example/stream")
                Layout.fillWidth: true
            }
        }

        Item { Layout.preferredHeight: ScreenTools.defaultFontPixelHeight / 2 }

        Repeater {
            id: cameraRepeater
            model: manager ? manager.cameras : []

            delegate: Frame {
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                padding: ScreenTools.defaultFontPixelHeight / 2

                ColumnLayout {
                    width: parent.width
                    spacing: ScreenTools.defaultFontPixelHeight / 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCLabel {
                            text: modelData.name
                            font.bold: modelData.isPrimary
                            Layout.fillWidth: true
                        }

                        QGCLabel {
                            text: modelData.isPrimary ? qsTr("Primary") : ""
                            font.bold: true
                            visible: modelData.isPrimary
                        }
                    }

                    QGCLabel {
                        text: modelData.url
                        color: qgcPal.text
                        font.pointSize: ScreenTools.defaultFontPointSize
                        wrapMode: Text.WrapAnywhere
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        spacing: ScreenTools.defaultFontPixelWidth

                        QGCButton {
                            text: qsTr("Edit")
                            onClicked: editCamera(modelData.index)
                        }

                        QGCButton {
                            text: qsTr("Remove")
                            onClicked: manager.removeCamera(modelData.index)
                        }

                        QGCButton {
                            text: qsTr("Set as main")
                            visible: !modelData.isPrimary
                            onClicked: manager.promoteToPrimary(modelData.index)
                        }
                    }
                }
            }
        }

        QGCLabel {
            visible: !manager || manager.cameras.length === 0
            text: qsTr("No cameras configured yet.")
            font.italic: true
        }

        Item { Layout.fillHeight: true }
    }
}
