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

    readonly property bool remoteControlFieldsValid:
        !remoteControlCheck.checked ||
        (powerField.acceptableInput &&
         deviceCountField.acceptableInput &&
         selectionField.acceptableInput &&
         activationField.acceptableInput &&
         !_rdcConflict &&
         !_rdcMainConflict)

    // True when both Main-controls and RDC are enabled AND at least one
    // Main-controls preset pair collides with an RDC-generated (channel, pulse).
    readonly property bool _rdcMainConflict: {
        if (!linkConfig) return false
        if (!linkConfig.mainControlsEnabled || !linkConfig.remoteDeviceControlEnabled) return false
        var presets = linkConfig.mainControlsPresetList()
        for (var i = 0; i < presets.length; i++) {
            if (_rdcReservedPair(presets[i].channel, presets[i].pulseWidth)) return true
        }
        return false
    }

    // True when RDC is enabled and at least one user-added servo button collides
    // with an RDC-generated (channel, pulse) pair.
    readonly property bool _rdcConflict: {
        if (!linkConfig || !linkConfig.remoteDeviceControlEnabled || !linkConfig.servoButtons) return false
        var list = linkConfig.servoButtons
        for (var i = 0; i < list.count; i++) {
            var b = list.get(i)
            if (b && _rdcReservedPair(b.channel, b.pulseWidth)) return true
        }
        return false
    }

    function _rdcReservedPair(channel, pulse) {
        if (!linkConfig || !linkConfig.remoteDeviceControlEnabled) return false
        var pc = linkConfig.powerContact
        var sc = linkConfig.selectionContact
        var ac = linkConfig.activationContact
        var N  = linkConfig.deviceCount
        if (channel === pc && (pulse === 1000 || pulse === 2000)) return true
        if (channel === ac && (pulse === 1500 || pulse === 2000)) return true
        if (channel === sc) {
            if (pulse === 0) return true
            if (N === 1 && pulse === 1500) return true
            if (N > 1) {
                for (var j = 1; j <= N; j++) {
                    if (pulse === Math.round(1000 + (j - 1) * 1000 / (N - 1))) return true
                }
            }
        }
        return false
    }

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

        QGCLabel {
            Layout.fillWidth: true
            visible: _rdcConflict
            color: "red"
            wrapMode: Text.WordWrap
            text: qsTr("One or more servo buttons conflict with the Remote device control channels (highlighted below). Remove or edit them to save the link.")
        }

        QGCLabel {
            Layout.fillWidth: true
            visible: _rdcMainConflict
            color: "red"
            wrapMode: Text.WordWrap
            text: qsTr("Remote device control channels/pulses conflict with the Main controls preset (channels 8, 9, 12). Adjust the Remote device control fields or disable one of the two.")
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

        // Remote device control: virtual preset group rendered in the Fly view
        // when enabled. Channel/count values are persisted per-link.
        QGCCheckBox {
            id: remoteControlCheck
            text: qsTr("Remote device control")
            checked: linkConfig ? linkConfig.remoteDeviceControlEnabled : false
            onClicked: {
                var wantedOn = checked
                checked = Qt.binding(function() { return linkConfig ? linkConfig.remoteDeviceControlEnabled : false })
                if (!linkConfig) return
                // Reset to defaults on every enable transition so stale values
                // from a previous disable don't persist visually.
                if (wantedOn && !linkConfig.remoteDeviceControlEnabled) {
                    linkConfig.powerContact      = 10
                    linkConfig.deviceCount       = 6
                    linkConfig.selectionContact  = 5
                    linkConfig.activationContact = 6
                    powerField.text       = Qt.binding(function() { return linkConfig ? linkConfig.powerContact.toString()      : "10" })
                    deviceCountField.text = Qt.binding(function() { return linkConfig ? linkConfig.deviceCount.toString()       : "6"  })
                    selectionField.text   = Qt.binding(function() { return linkConfig ? linkConfig.selectionContact.toString()  : "5"  })
                    activationField.text  = Qt.binding(function() { return linkConfig ? linkConfig.activationContact.toString() : "6"  })
                }
                linkConfig.remoteDeviceControlEnabled = wantedOn
            }
        }

        ColumnLayout {
            visible: remoteControlCheck.checked
            Layout.fillWidth: true
            Layout.leftMargin: ScreenTools.defaultFontPixelWidth * 2
            spacing: ScreenTools.defaultFontPixelHeight / 4

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth
                QGCLabel {
                    text: qsTr("\u041A\u043E\u043D\u0442\u0430\u043A\u0442 \u0436\u0438\u0432\u043B\u0435\u043D\u043D\u044F:")
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 22
                }
                QGCTextField {
                    id: powerField
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator { bottom: 1; top: 18 }
                    text: linkConfig ? linkConfig.powerContact.toString() : "10"
                    onEditingFinished: if (linkConfig && acceptableInput) linkConfig.powerContact = parseInt(text, 10)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth
                QGCLabel {
                    text: qsTr("\u041A\u0456\u043B\u044C\u043A\u0456\u0441\u0442\u044C \u043F\u0440\u0438\u0441\u0442\u0440\u043E\u0457\u0432:")
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 22
                }
                QGCTextField {
                    id: deviceCountField
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator { bottom: 1; top: 32 }
                    text: linkConfig ? linkConfig.deviceCount.toString() : "6"
                    onEditingFinished: if (linkConfig && acceptableInput) linkConfig.deviceCount = parseInt(text, 10)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth
                QGCLabel {
                    text: qsTr("\u041A\u043E\u043D\u0442\u0430\u043A\u0442 \u0432\u0438\u0431\u043E\u0440\u0443:")
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 22
                }
                QGCTextField {
                    id: selectionField
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator { bottom: 1; top: 18 }
                    text: linkConfig ? linkConfig.selectionContact.toString() : "5"
                    onEditingFinished: if (linkConfig && acceptableInput) linkConfig.selectionContact = parseInt(text, 10)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: ScreenTools.defaultFontPixelWidth
                QGCLabel {
                    text: qsTr("\u041A\u043E\u043D\u0442\u0430\u043A\u0442 \u0430\u043A\u0442\u0438\u0432\u0430\u0446\u0456\u0457:")
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 22
                }
                QGCTextField {
                    id: activationField
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10
                    inputMethodHints: Qt.ImhDigitsOnly
                    validator: IntValidator { bottom: 1; top: 18 }
                    text: linkConfig ? linkConfig.activationContact.toString() : "6"
                    onEditingFinished: if (linkConfig && acceptableInput) linkConfig.activationContact = parseInt(text, 10)
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

                readonly property bool _rowConflict: linkConfig &&
                                                      (((mainControlsCheck.checked || _showMainControlsConflict) &&
                                                        linkConfig.isMainControlsPreset(object.channel, object.pulseWidth)) ||
                                                       _rdcReservedPair(object.channel, object.pulseWidth))

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
