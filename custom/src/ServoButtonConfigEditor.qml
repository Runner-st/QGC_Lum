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

    property bool _showMainControlsConflict: false
    property string _manualAddError: ""

    function _conflictIndices() {
        var out = []
        if (!linkConfig || !linkConfig.servoButtons) return out
        var list = linkConfig.servoButtons
        for (var i = 0; i < list.count; i++) {
            var b = list.get(i)
            if (b && linkConfig.isMainControlsPreset(b.channel, b.pulseWidth)) out.push(i)
        }
        return out
    }

    Connections {
        target: linkConfig ? linkConfig.servoButtons : null
        function onCountChanged() {
            if (_showMainControlsConflict && _conflictIndices().length === 0) {
                _showMainControlsConflict = false
            }
        }
    }

    function _resetForm() {
        _editingIndex = -1
        nameField.text = ""
        channelField.text = ""
        pulseField.text = ""
        _manualAddError = ""
    }

    function _submit() {
        if (!_formValid || !linkConfig) return

        const channel = parseInt(channelField.text, 10)
        const pulse = parseInt(pulseField.text, 10)

        if (linkConfig.mainControlsEnabled && linkConfig.isMainControlsPreset(channel, pulse)) {
            _manualAddError = qsTr("CH %1, %2 us is reserved by the Main controls preset.").arg(channel).arg(pulse)
            return
        }
        _manualAddError = ""

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
                    placeholderText: qsTr("0-3000")
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator { bottom: 0; top: 3000 }
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

            QGCLabel {
                Layout.fillWidth: true
                visible: _manualAddError.length > 0
                color: "red"
                wrapMode: Text.WordWrap
                text: _manualAddError
            }
        }

        // Main controls preset toggle: virtual preset group of 5 buttons that
        // shows in the main Fly view when enabled (never stored in servoButtons).
        QGCCheckBox {
            id: mainControlsCheck
            text: qsTr("Add main controls")
            checked: linkConfig ? linkConfig.mainControlsEnabled : false
            onClicked: {
                // Qt has already toggled `checked`; capture user intent then re-bind
                // to the backing property so the visual state always tracks truth.
                var wantedOn = checked
                checked = Qt.binding(function() { return linkConfig ? linkConfig.mainControlsEnabled : false })
                if (!linkConfig) return
                if (wantedOn) {
                    if (_conflictIndices().length > 0) {
                        _showMainControlsConflict = true   // stays off via binding
                    } else {
                        linkConfig.mainControlsEnabled = true
                        _showMainControlsConflict = false
                    }
                } else {
                    linkConfig.mainControlsEnabled = false
                    _showMainControlsConflict = false
                    _manualAddError = ""
                }
            }
        }

        QGCLabel {
            Layout.fillWidth: true
            visible: _showMainControlsConflict
            color: "red"
            wrapMode: Text.WordWrap
            text: qsTr("Cannot enable Main controls: one or more of your servo buttons uses the same channel and pulse as a preset (highlighted below). Remove or edit them first.")
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

                readonly property bool _rowConflict: linkConfig &&
                                                      (mainControlsCheck.checked || _showMainControlsConflict) &&
                                                      linkConfig.isMainControlsPreset(object.channel, object.pulseWidth)

                QGCLabel {
                    Layout.fillWidth: true
                    text: object.name + qsTr(" - CH %1, %2 us").arg(object.channel).arg(object.pulseWidth)
                    color: parent._rowConflict ? "red" : qgcPal.text
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
