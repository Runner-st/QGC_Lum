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

QGCPopupDialog {
    id: root
    title: isNew ? qsTr("Add New Link") : qsTr("Edit Link")
    buttons: Dialog.Save | Dialog.Cancel

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    property var editingConfig: null
    property var originalConfig: null
    property bool isNew: false

    readonly property var _linksManager: QGroundControl.corePlugin ? QGroundControl.corePlugin.linksManager : null
    readonly property bool _formValid: nameField.text.trim().length > 0 &&
                                        serverAddressField.text.trim().length > 0 &&
                                        serverPortField.acceptableInput

    onAccepted: {
        if (!_formValid || !editingConfig || !_linksManager) return

        // Apply form values to config
        editingConfig.name = nameField.text.trim()
        editingConfig.serverAddress = serverAddressField.text.trim()
        editingConfig.serverPort = parseInt(serverPortField.text)
        editingConfig.autoConnect = autoConnectSwitch.checked

        if (isNew) {
            _linksManager.addConfiguration(editingConfig)
        } else {
            _linksManager.saveConfiguration(originalConfig, editingConfig)
        }
    }

    onRejected: {
        if (editingConfig && _linksManager) {
            if (isNew) {
                editingConfig.destroy()
            } else {
                _linksManager.cancelEditing(editingConfig)
            }
        }
    }

    ColumnLayout {
        width: ScreenTools.defaultFontPixelWidth * 60
        spacing: ScreenTools.defaultFontPixelHeight

        // Link Name
        ColumnLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelHeight / 4

            QGCLabel {
                text: qsTr("Link Name")
                font.bold: true
            }

            QGCTextField {
                id: nameField
                Layout.fillWidth: true
                placeholderText: qsTr("Enter a name for this link")
                text: editingConfig ? editingConfig.name : ""
            }
        }

        // Server Configuration
        Rectangle {
            Layout.fillWidth: true
            height: serverColumn.height + ScreenTools.defaultFontPixelHeight
            color: "transparent"
            border.color: qgcPal.groupBorder
            border.width: 1
            radius: 4

            ColumnLayout {
                id: serverColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: ScreenTools.defaultFontPixelHeight / 2
                spacing: ScreenTools.defaultFontPixelHeight / 2

                QGCLabel {
                    text: qsTr("Flight Controller Connection")
                    font.bold: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelHeight / 4

                        QGCLabel { text: qsTr("Server Address") }
                        QGCTextField {
                            id: serverAddressField
                            Layout.fillWidth: true
                            placeholderText: "192.168.1.100"
                            text: editingConfig ? editingConfig.serverAddress : ""
                        }
                    }

                    ColumnLayout {
                        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 15
                        spacing: ScreenTools.defaultFontPixelHeight / 4

                        QGCLabel { text: qsTr("Port") }
                        QGCTextField {
                            id: serverPortField
                            Layout.fillWidth: true
                            placeholderText: "14550"
                            text: editingConfig ? editingConfig.serverPort.toString() : "14550"
                            inputMethodHints: Qt.ImhDigitsOnly
                            validator: IntValidator { bottom: 1; top: 65535 }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    QGCCheckBox {
                        id: autoConnectSwitch
                        text: qsTr("Auto-connect on startup")
                        checked: editingConfig ? editingConfig.autoConnect : false
                    }
                }
            }
        }

        // Camera 1 Configuration
        CameraConfigEditor {
            Layout.fillWidth: true
            heading: qsTr("Camera 1")
            cameraConfig: editingConfig ? editingConfig.camera1 : null
        }

        // Camera 2 Configuration
        CameraConfigEditor {
            Layout.fillWidth: true
            heading: qsTr("Camera 2 (Optional)")
            cameraConfig: editingConfig ? editingConfig.camera2 : null
        }

        // Servo Button Configuration
        ServoButtonConfigEditor {
            Layout.fillWidth: true
            heading: qsTr("Servo Buttons")
            linkConfig: editingConfig
        }

        // Validation message
        QGCLabel {
            Layout.fillWidth: true
            visible: !_formValid
            text: qsTr("Please fill in Link Name and Server Address")
            color: "orange"
            wrapMode: Text.WordWrap
        }
    }
}
