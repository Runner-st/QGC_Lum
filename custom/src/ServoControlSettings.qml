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

SettingsPage {
    id: root

    property int _editingIndex: -1
    readonly property bool _pluginReady: QGroundControl.corePlugin !== null && QGroundControl.corePlugin !== undefined
    readonly property bool _formValid: nameField.text.trim().length > 0 && channelField.acceptableInput && pulseField.acceptableInput

    function _resetForm() {
        _editingIndex = -1
        nameField.text = ""
        channelField.text = ""
        pulseField.text = ""
    }

    function _submit() {
        if (!_formValid) {
            return
        }

        if (!_pluginReady) {
            return
        }

        const plugin = QGroundControl.corePlugin
        if (!plugin) {
            return
        }

        const channel = parseInt(channelField.text, 10)
        const pulse = parseInt(pulseField.text, 10)

        if (_editingIndex >= 0) {
            plugin.updateServoButton(_editingIndex, nameField.text, channel, pulse)
        } else {
            plugin.addServoButton(nameField.text, channel, pulse)
        }

        _resetForm()
    }

    function _beginEdit(index, data) {
        if (!_pluginReady) {
            return
        }

        _editingIndex = index
        nameField.text = data.name
        channelField.text = data.channel
        pulseField.text = data.pulse
    }

    function _deleteButton(index) {
        if (!_pluginReady) {
            return
        }

        QGroundControl.corePlugin.removeServoButton(index)
        if (_editingIndex === index) {
            _resetForm()
        } else if (_editingIndex > index) {
            _editingIndex = _editingIndex - 1
        }
    }

    SettingsGroupLayout {
        Layout.fillWidth: true
        heading: qsTr("Servo buttons")
        headingDescription: qsTr("Define custom servo control shortcuts that appear in the Fly View.")
        contentSpacing: ScreenTools.defaultFontPixelHeight

        ColumnLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelHeight / 2

            QGCLabel {
                Layout.fillWidth: true
                visible: !_pluginReady
                wrapMode: Text.WordWrap
                text: qsTr("Custom core plugin is unavailable. Servo button editing is disabled.")
            }

            QGCLabel {
                Layout.fillWidth: true
                text: _editingIndex >= 0 ? qsTr("Edit servo button") : qsTr("Add servo button")
                font.bold: true
            }

            QGCTextField {
                id: nameField
                Layout.fillWidth: true
                placeholderText: qsTr("Button name")
                enabled: _pluginReady
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCTextField {
                    id: channelField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Servo output")
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator { bottom: 1 }
                    enabled: _pluginReady
                }

                QGCTextField {
                    id: pulseField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Pulse width (\u00B5s)")
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator { bottom: 500; top: 3000 }
                    enabled: _pluginReady
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCButton {
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12
                    text: _editingIndex >= 0 ? qsTr("Save changes") : qsTr("Add button")
                    enabled: _pluginReady && _formValid
                    onClicked: _submit()
                }

                QGCButton {
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12
                    visible: _editingIndex >= 0
                    text: qsTr("Cancel edit")
                    onClicked: _resetForm()
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelHeight / 2

            QGCLabel {
                Layout.fillWidth: true
                visible: _pluginReady && buttonRepeater.count === 0
                wrapMode: Text.WordWrap
                text: qsTr("No servo buttons configured. Add a button above to control a servo from the Fly View.")
            }

            Repeater {
                id: buttonRepeater
                model: _pluginReady ? QGroundControl.corePlugin.servoButtons : []

                RowLayout {
                    Layout.fillWidth: true
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCLabel {
                        Layout.fillWidth: true
                        text: modelData.name + qsTr(" — CH %1 • %2 \u00B5s").arg(modelData.channel).arg(modelData.pulse)
                        elide: Text.ElideRight
                    }

                    QGCButton {
                        text: qsTr("Edit")
                        onClicked: _beginEdit(index, modelData)
                        enabled: _pluginReady
                    }

                    QGCButton {
                        text: qsTr("Delete")
                        onClicked: _deleteButton(index)
                        enabled: _pluginReady
                    }
                }
            }
        }
    }
}
