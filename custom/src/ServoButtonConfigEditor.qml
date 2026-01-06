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

    property var linkConfig: null
    property string heading: qsTr("Servo Buttons")

    implicitHeight: contentColumn.height + ScreenTools.defaultFontPixelHeight
    color: "transparent"
    border.color: qgcPal.groupBorder
    border.width: 1
    radius: 4

    property int _editingIndex: -1
    readonly property bool _formValid: nameField.text.trim().length > 0 &&
                                        channelField.acceptableInput &&
                                        pulseField.acceptableInput

    function _resetForm() {
        _editingIndex = -1
        nameField.text = ""
        channelField.text = ""
        pulseField.text = ""
    }

    function _submit() {
        if (!_formValid || !linkConfig) return

        const channel = parseInt(channelField.text, 10)
        const pulse = parseInt(pulseField.text, 10)

        if (_editingIndex >= 0) {
            linkConfig.updateServoButton(_editingIndex, nameField.text.trim(), channel, pulse)
        } else {
            linkConfig.addServoButton(nameField.text.trim(), channel, pulse)
        }

        _resetForm()
    }

    function _beginEdit(index) {
        if (!linkConfig || !linkConfig.servoButtons) return

        var btn = linkConfig.servoButtons.get(index)
        if (btn) {
            _editingIndex = index
            nameField.text = btn.name
            channelField.text = btn.channel.toString()
            pulseField.text = btn.pulseWidth.toString()
        }
    }

    function _deleteButton(index) {
        if (!linkConfig) return

        linkConfig.removeServoButton(index)
        if (_editingIndex === index) {
            _resetForm()
        } else if (_editingIndex > index) {
            _editingIndex = _editingIndex - 1
        }
    }

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

        // Add/Edit form
        ColumnLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelHeight / 4

            QGCLabel {
                text: _editingIndex >= 0 ? qsTr("Edit servo button") : qsTr("Add servo button")
                font.pointSize: ScreenTools.smallFontPointSize
                color: qgcPal.textFieldText
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text: qsTr("Name:")
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10
                }

                QGCTextField {
                    id: nameField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Button name")
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text: qsTr("Channel:")
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10
                }

                QGCTextField {
                    id: channelField
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12
                    placeholderText: qsTr("1-18")
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator { bottom: 1; top: 18 }
                }

                QGCLabel {
                    text: qsTr("Pulse (us):")
                }

                QGCTextField {
                    id: pulseField
                    Layout.fillWidth: true
                    placeholderText: qsTr("500-3000")
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator { bottom: 500; top: 3000 }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCButton {
                    text: _editingIndex >= 0 ? qsTr("Save") : qsTr("Add")
                    enabled: _formValid
                    onClicked: _submit()
                }

                QGCButton {
                    visible: _editingIndex >= 0
                    text: qsTr("Cancel")
                    onClicked: _resetForm()
                }
            }
        }

        // Separator
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: qgcPal.groupBorder
            visible: linkConfig && linkConfig.servoButtons && linkConfig.servoButtons.count > 0
        }

        // Button list header
        QGCLabel {
            Layout.fillWidth: true
            visible: linkConfig && linkConfig.servoButtons && linkConfig.servoButtons.count === 0
            text: qsTr("No servo buttons configured for this link.")
            font.pointSize: ScreenTools.smallFontPointSize
            color: qgcPal.textFieldText
        }

        // Configured buttons list
        Repeater {
            id: buttonRepeater
            model: linkConfig ? linkConfig.servoButtons : []

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    Layout.fillWidth: true
                    text: object.name + qsTr(" - CH %1, %2 us").arg(object.channel).arg(object.pulseWidth)
                    elide: Text.ElideRight
                }

                QGCButton {
                    text: qsTr("Edit")
                    onClicked: _beginEdit(index)
                }

                QGCButton {
                    text: qsTr("Delete")
                    onClicked: _deleteButton(index)
                }
            }
        }
    }
}
