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

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    property var parentToolInsets
    property var totalToolInsets: toolInsets
    property var mapControl

    // Height (including outer margin) occupied by the servo button stack at
    // the bottom-left, for FlyView.qml to push the PIP column up accordingly.
    readonly property real servoButtonsHeight: servoButtonsColumn.visible
                                                 ? servoButtonsColumn.implicitHeight + _margin
                                                 : 0

    Component.onCompleted: {
        console.log("FlyViewCustomLayer loaded")
        console.log("_hasCorePlugin:", _hasCorePlugin)
        console.log("_linksManager:", _linksManager)
        // on_XxxChanged handlers do not fire for initial values: start the
        // mode countdown here if the link and vehicle already exist.
        _maybeStartModeTimer()
    }

    readonly property real _margin: ScreenTools.defaultFontPixelWidth
    readonly property bool _hasVehicle: QGroundControl.multiVehicleManager.activeVehicle !== null
    readonly property bool _hasCorePlugin: QGroundControl.corePlugin !== null && QGroundControl.corePlugin !== undefined
    readonly property var _linksManager: _hasCorePlugin ? QGroundControl.corePlugin.linksManager : null
    readonly property bool _hasActiveLink: _linksManager !== null && _linksManager.hasActiveLink
    readonly property bool _hasC12Camera: _hasActiveLink && _linksManager.activeLink && _linksManager.activeLink.camera1 && _linksManager.activeLink.camera1.cameraType === 2
    readonly property bool _hasTopotekCamera: _hasActiveLink && _linksManager.activeLink && _linksManager.activeLink.camera1 && _linksManager.activeLink.camera1.cameraType === 3

    readonly property var _rdc: _hasActiveLink && _linksManager ? _linksManager.activeRemoteDeviceControl : null
    readonly property bool _rdcActive: _rdc && _rdc.enabled === true
    readonly property int _rdcN: _rdc ? (_rdc.deviceCount | 0) : 0
    readonly property int _rdcPower:  _rdc ? (_rdc.powerContact      | 0) : 0
    readonly property int _rdcSelect: _rdc ? (_rdc.selectionContact  | 0) : 0
    readonly property int _rdcAct:    _rdc ? (_rdc.activationContact | 0) : 0
    // Labels from custom/res/RemoteDeviceControlPresets.json (via C++).
    readonly property var _rdcLabels: _rdc && _rdc.labels ? _rdc.labels : ({})
    // A string, so deviceCombo._options (which resets the selection) is rebuilt
    // only when the label text really changes, not on each new labels object.
    readonly property string _rdcNoDeviceLabel: _rdcLabels.noDevice || ""

    // Debug logging function
    function debugWidgetState() {
        console.log("=== WIDGET STATE DEBUG ===")
        console.log("_hasActiveLink:", _hasActiveLink)
        console.log("_hasC12Camera:", _hasC12Camera)
        console.log("_hasTopotekCamera:", _hasTopotekCamera)

        if (_linksManager && _linksManager.activeLink) {
            console.log("Active link exists")
            if (_linksManager.activeLink.camera1) {
                console.log("camera1 exists")
                console.log("camera1.cameraType:", _linksManager.activeLink.camera1.cameraType)
                console.log("camera1.topotekCameraIp:", _linksManager.activeLink.camera1.topotekCameraIp)
                console.log("camera1.topotekControlPort:", _linksManager.activeLink.camera1.topotekControlPort)
            } else {
                console.log("camera1 is NULL")
            }
        } else {
            console.log("No active link or _linksManager")
        }
        console.log("==========================")
    }

    // Watch for changes
    on_HasActiveLinkChanged: debugWidgetState()
    on_HasC12CameraChanged: debugWidgetState()
    on_HasTopotekCameraChanged: debugWidgetState()

    function _triggerServo(channel, pulseWidth) {
        if (!_hasVehicle || !_hasCorePlugin) {
            return
        }

        QGroundControl.corePlugin.triggerServoCommand(channel, pulseWidth)
    }

    // ---- Main controls mode drop-down (AUTO / MANUAL / SAFE on CH12) ----
    // After the link is activated the drop-down shows AUTO and is locked.
    // It unlocks kModeUnlockDelayMs after the first heartbeat (activeVehicle)
    // and sends the default option (AUTO) at that moment.
    // If the vehicle is lost and comes back while the same link stays active,
    // the current option is sent again at once and the drop-down stays unlocked.
    readonly property int kModeUnlockDelayMs: 120000
    readonly property var _modeOptions: servoButtonsColumn._modeOptions
    readonly property int _modeOptionCount: _modeOptions.length
    readonly property var _activeLinkObj: _hasActiveLink ? _linksManager.activeLink : null
    property int  _modeIndex: 0
    property bool _modeUnlocked: false
    property bool _modeTimerStarted: false

    function _sendCurrentMode() {
        if (_modeIndex < 0 || _modeIndex >= _modeOptions.length) return
        var opt = _modeOptions[_modeIndex]
        _triggerServo(opt.channel, opt.pulse)
    }

    function _maybeStartModeTimer() {
        if (_hasVehicle && _hasActiveLink && _modeOptionCount > 0 && !_modeTimerStarted) {
            _modeTimerStarted = true
            modeUnlockTimer.start()
        }
    }

    function _resetModeState() {
        modeUnlockTimer.stop()
        modeResendTimer.stop()
        _modeUnlocked = false
        _modeTimerStarted = false
        _modeIndex = 0
        _maybeStartModeTimer()
    }

    on_ActiveLinkObjChanged: _resetModeState()
    on_ModeOptionCountChanged: _resetModeState()

    on_HasVehicleChanged: {
        if (!_hasVehicle) {
            modeResendTimer.stop()
            return
        }
        if (_modeUnlocked) {
            modeResendTimer.restart()
        } else {
            _maybeStartModeTimer()
        }
    }

    // A short loss of communication does not remove the Vehicle object
    // (_hasVehicle stays true). QGC only sets communicationLost. When the
    // communication comes back, send the current option again, because an
    // option selected during the loss did not reach the vehicle.
    readonly property var  _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    readonly property bool _commLost: _activeVehicle && _activeVehicle.vehicleLinkManager
                                      ? _activeVehicle.vehicleLinkManager.communicationLost : false

    on_CommLostChanged: {
        if (_commLost) {
            modeResendTimer.stop()
        } else if (_hasVehicle && _modeUnlocked) {
            modeResendTimer.restart()
        }
    }

    Timer {
        id: modeUnlockTimer
        interval: kModeUnlockDelayMs
        repeat: false
        // On unlock, send the default option (AUTO). If no vehicle is present
        // now, _triggerServo does nothing and the resend on reconnect sends it.
        onTriggered: {
            _modeUnlocked = true
            _sendCurrentMode()
        }
    }

    // Short delay so the new Vehicle object can take commands after the heartbeat.
    Timer {
        id: modeResendTimer
        interval: 1000
        repeat: false
        onTriggered: _sendCurrentMode()
    }

    QGCToolInsets {
        id: toolInsets
        leftEdgeTopInset: parentToolInsets.leftEdgeTopInset
        leftEdgeCenterInset: parentToolInsets.leftEdgeCenterInset
        leftEdgeBottomInset: parentToolInsets.leftEdgeBottomInset
        rightEdgeTopInset: parentToolInsets.rightEdgeTopInset
        rightEdgeCenterInset: Math.max(parentToolInsets.rightEdgeCenterInset, cameraWidgetContainer.visible ? cameraWidgetContainer.width + _margin : 0)
        rightEdgeBottomInset: parentToolInsets.rightEdgeBottomInset
        topEdgeLeftInset: parentToolInsets.topEdgeLeftInset
        topEdgeCenterInset: parentToolInsets.topEdgeCenterInset
        topEdgeRightInset: parentToolInsets.topEdgeRightInset
        bottomEdgeLeftInset: Math.max(parentToolInsets.bottomEdgeLeftInset, servoButtonsColumn.visible ? servoButtonsColumn.implicitHeight + (_margin * 2) : 0)
        bottomEdgeCenterInset: parentToolInsets.bottomEdgeCenterInset
        bottomEdgeRightInset: parentToolInsets.bottomEdgeRightInset
    }

    // Servo buttons: two rows at the bottom-left.
    //   - Bottom row: preset ("Main controls") buttons.
    //   - Row above: user-added buttons.
    // Left margin respects parentToolInsets.leftEdgeBottomInset so the columns
    // sit to the right of the PIP stack when it's visible.
    Column {
        id: servoButtonsColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: _margin
        anchors.rightMargin: _margin
        anchors.bottomMargin: _margin
        spacing: _margin / 2
        visible: _hasActiveLink && (userButtonRepeater.count > 0 || presetButtonRepeater.count > 0 || _rdcActive)

        readonly property var _activeButtons: _hasActiveLink ? _linksManager.activeServoButtons : []
        readonly property var _userButtons: _activeButtons.filter(function(b) { return !b.isPreset })
        readonly property var _presetButtons: _activeButtons.filter(function(b) { return b.isPreset && !b.isMode })
        readonly property var _modeOptions: _activeButtons.filter(function(b) { return b.isPreset && b.isMode })
        // String key: changes only when the option names change, so the combo
        // model is not reset each time activeServoButtons is re-emitted.
        readonly property string _modeNamesKey: _modeOptions.map(function(o) { return o.name }).join("\n")

        Flow {
            id: userButtonsFlow
            width: parent.width
            spacing: _margin / 2
            visible: userButtonRepeater.count > 0

            Repeater {
                id: userButtonRepeater
                model: servoButtonsColumn._userButtons

                QGCButton {
                    text: modelData.name
                    width: Math.max(ScreenTools.defaultFontPixelWidth * 4, implicitWidth)
                    height: ScreenTools.defaultFontPixelHeight * 2
                    enabled: _hasVehicle && _hasCorePlugin
                    onClicked: _triggerServo(modelData.channel, modelData.pulse)
                }
            }
        }

        Flow {
            id: presetButtonsFlow
            width: parent.width
            spacing: _margin / 2
            visible: presetButtonRepeater.count > 0 || _rdcActive

            Repeater {
                id: presetButtonRepeater
                model: servoButtonsColumn._presetButtons

                QGCButton {
                    text: modelData.name
                    width: Math.max(ScreenTools.defaultFontPixelWidth * 4, implicitWidth)
                    height: ScreenTools.defaultFontPixelHeight * 2
                    enabled: _hasVehicle && _hasCorePlugin
                    onClicked: _triggerServo(modelData.channel, modelData.pulse)
                }
            }

            QGCComboBox {
                id: modeCombo
                visible: _modeOptionCount > 0
                width: ScreenTools.defaultFontPixelWidth * 12
                height: ScreenTools.defaultFontPixelHeight * 2
                enabled: _modeUnlocked && _hasVehicle && _hasCorePlugin
                model: servoButtonsColumn._modeNamesKey.length > 0 ? servoButtonsColumn._modeNamesKey.split("\n") : []
                currentIndex: _modeIndex

                onActivated: (index) => {
                    _modeIndex = index
                    _sendCurrentMode()
                }
            }

            Rectangle {
                visible: _rdcActive && (presetButtonRepeater.count > 0 || _modeOptionCount > 0)
                width: 1
                height: ScreenTools.defaultFontPixelHeight * 2
                color: qgcPal.groupBorder
            }

            QGCButton {
                visible: _rdcActive
                text: _rdcLabels.txOn || ""
                width: Math.max(ScreenTools.defaultFontPixelWidth * 4, implicitWidth)
                height: ScreenTools.defaultFontPixelHeight * 2
                enabled: _hasVehicle && _hasCorePlugin
                onClicked: _triggerServo(_rdcPower, 2000)
            }

            QGCButton {
                visible: _rdcActive
                text: _rdcLabels.txOff || ""
                width: Math.max(ScreenTools.defaultFontPixelWidth * 4, implicitWidth)
                height: ScreenTools.defaultFontPixelHeight * 2
                enabled: _hasVehicle && _hasCorePlugin
                onClicked: _triggerServo(_rdcPower, 1000)
            }

            QGCComboBox {
                id: deviceCombo
                visible: _rdcActive
                width: ScreenTools.defaultFontPixelWidth * 12
                height: ScreenTools.defaultFontPixelHeight * 2
                enabled: _hasVehicle && _hasCorePlugin

                readonly property var _options: {
                    var opts = [_rdcNoDeviceLabel]
                    for (var i = 1; i <= _rdcN; i++) opts.push(String(i))
                    return opts
                }
                model: _options

                on_OptionsChanged: currentIndex = 0

                property int _pendingSelectionPulse: 0

                onActivated: {
                    var pulse
                    if (currentIndex <= 0) {
                        pulse = 0
                    } else if (_rdcN > 1) {
                        pulse = Math.round(1000 + (currentIndex - 1) * 1000 / (_rdcN - 1))
                    } else {
                        pulse = 1500
                    }
                    // Reset activation channel first so Init/Activate state doesn't
                    // leak across device switches, then send the selection pulse
                    // after a delay (the Vehicle command queue drops a second
                    // MAV_CMD_DO_SET_SERVO while the first ACK is still pending).
                    _pendingSelectionPulse = pulse
                    _triggerServo(_rdcAct, 0)
                    selectionSendTimer.restart()
                }

                Timer {
                    id: selectionSendTimer
                    interval: 500
                    repeat: false
                    onTriggered: _triggerServo(_rdcSelect, deviceCombo._pendingSelectionPulse)
                }
            }

            QGCButton {
                visible: _rdcActive
                text: _rdcLabels.init || ""
                width: Math.max(ScreenTools.defaultFontPixelWidth * 4, implicitWidth)
                height: ScreenTools.defaultFontPixelHeight * 2
                enabled: _hasVehicle && _hasCorePlugin
                onClicked: _triggerServo(_rdcAct, 1500)
            }

            QGCButton {
                visible: _rdcActive
                text: _rdcLabels.activate || ""
                width: Math.max(ScreenTools.defaultFontPixelWidth * 4, implicitWidth)
                height: ScreenTools.defaultFontPixelHeight * 2
                enabled: _hasVehicle && _hasCorePlugin
                onClicked: _triggerServo(_rdcAct, 2000)
            }
        }
    }

    // Camera Widget Container - holds both C12 and Topotek widgets
    Rectangle {
        id: cameraWidgetContainer
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: _margin

        visible: _hasC12Camera || _hasTopotekCamera
        width: widgetColumn.width
        height: widgetColumn.height
        color: "transparent"

        z: QGroundControl.zOrderWidgets

        Column {
            id: widgetColumn
            spacing: _margin

            // C12 Camera Widget
            Loader {
                id: c12WidgetLoader
                active: _hasC12Camera
                visible: _hasC12Camera
                source: _hasC12Camera ? "C12CameraWidget.qml" : ""

                onLoaded: {
                    if (item && _hasCorePlugin) {
                        item.c12Controller = QGroundControl.corePlugin.c12Controller
                    }
                }
            }

            // Topotek Camera Widget
            Loader {
                id: topotekWidgetLoader
                active: _hasTopotekCamera
                visible: _hasTopotekCamera
                source: _hasTopotekCamera ? "TopotekCameraWidget.qml" : ""

                onLoaded: {
                    if (item && _hasCorePlugin) {
                        item.topotekController = QGroundControl.corePlugin.topotekController
                    }
                }
            }
        }
    }
}
