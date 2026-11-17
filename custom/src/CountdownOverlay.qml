/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick

// Countdown that the flight controller starts and cancels with STATUSTEXT
// messages (received through Vehicle::textMessageReceived, no dialog).
//   "Відлік 60секунд!" -> start (or restart) from durationSec
//   "Відмінено."        -> stop at once and hide
// At 0 the digit blinks for blinkDurationMs, then the counter hides.
// The item has no mouse areas, so clicks go through to the map and video.
Item {
    id: root

    property int durationSec:     60
    property int blinkDurationMs: 3000

    // Message texts with all white space removed (see handleMessage).
    readonly property string kStartText:  "Відлік60секунд!"
    readonly property string kCancelText: "Відмінено."

    property int    _remaining: durationSec
    property bool   _running:   false
    property bool   _blinking:  false
    property real   _endTimeMs: 0

    visible: _running || _blinking

    function handleMessage(text) {
        var key = String(text).replace(/\s+/g, "")
        if (key === kStartText) {
            start()
        } else if (key === kCancelText) {
            cancel()
        }
    }

    function start() {
        blinkToggleTimer.stop()
        blinkEndTimer.stop()
        _blinking = false
        countdownText.opacity = 1
        _endTimeMs = Date.now() + durationSec * 1000
        _remaining = durationSec
        _running = true
        tickTimer.restart()
    }

    function cancel() {
        tickTimer.stop()
        blinkToggleTimer.stop()
        blinkEndTimer.stop()
        _running = false
        _blinking = false
        countdownText.opacity = 1
    }

    // Remaining time comes from the wall clock, not from a count of timer
    // triggers: QML timers can trigger late when the GUI thread is busy.
    Timer {
        id: tickTimer
        interval: 200
        repeat: true
        onTriggered: {
            root._remaining = Math.max(0, Math.ceil((root._endTimeMs - Date.now()) / 1000))
            if (root._remaining === 0) {
                stop()
                root._running = false
                root._blinking = true
                blinkToggleTimer.restart()
                blinkEndTimer.restart()
            }
        }
    }

    Timer {
        id: blinkToggleTimer
        interval: 250
        repeat: true
        onTriggered: countdownText.opacity = countdownText.opacity > 0 ? 0 : 1
    }

    Timer {
        id: blinkEndTimer
        interval: root.blinkDurationMs
        repeat: false
        onTriggered: root.cancel()
    }

    Text {
        id: countdownText
        anchors.centerIn: parent
        text: root._remaining
        color: "red"
        font.pixelSize: Math.max(1, root.height * 0.2)
        font.bold: true
        style: Text.Outline
        styleColor: "black"
    }
}
