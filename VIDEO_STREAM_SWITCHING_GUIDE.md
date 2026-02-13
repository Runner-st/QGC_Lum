# Video Stream Switching (HDMI1/HDMI2) — Implementation Guide

This document describes exactly how the custom QGC Herelink Lumiere build switches between HDMI1 and HDMI2 video inputs on the Herelink air unit. It is intended as a porting reference for reimplementing this feature in a different customized QGC build (e.g., a Windows version).

---

## 1. Architecture Overview

### Signal/Data Flow

```
 User clicks HDMI button (QML)
         |
         v
 toggleHerelinkHdmiSource()             [PhotoVideoControl.qml:147]
         |
         v
 Sets VideoSettings.cameraId = 0 or 1   [QML property write]
         |
         v
 Fact::rawValueChanged signal fires
         |
         v
 VideoStreamControl::_cameraIdChanged()  [VideoStreamControl.cc:45]
         |
         v
 _setCameraIdLockUi(true)               [VideoStreamControl.cc:87]
   |-- Reads new cameraId from settings
   |-- Calls _setCameraId()
   |      |
   |      v
   |   _startVideoStreaming()            [VideoStreamControl.cc:101]
   |      |-- Packs MAV_CMD_VIDEO_START_STREAMING with cameraId
   |      |-- Sends via MAVLink to air unit (MAV_COMP_ID_CAMERA)
   |      |-- Emits videoNeedsReset()
   |
   |-- Starts 15-second UI lock timer
         |
         v
 VideoManager::_restartAllVideos()       [VideoManager.cc:861]
   |-- _restartVideo(0)  (primary stream)
   |-- _restartVideo(1)  (secondary/thermal stream)
         |
         v
 _stopReceiver(id) then _startReceiver(id)
         |
         v
 GStreamer pipeline torn down and rebuilt with same URI
         |
         v
 Air unit now outputs the selected HDMI source on the RTSP stream
```

### Components

| Component | Role |
|---|---|
| **PhotoVideoControl.qml** | UI button, toggles `cameraId` setting |
| **VideoStreamControl** | Monitors camera heartbeats, sends MAVLink switch command, manages UI lock |
| **VideoSettings / cameraId** | Persistent setting (0 = HDMI1, 1 = HDMI2) |
| **VideoManager** | Owns VideoStreamControl, restarts GStreamer receivers on switch |
| **GstVideoReceiver** | GStreamer pipeline — stops and restarts to pick up new stream from air unit |
| **HerelinkCorePlugin** | Provides `isHerelink` property to guard Herelink-only UI |

---

## 2. Files Involved

| File | Purpose |
|---|---|
| `custom/herelink/VideoStreamControl.h` | Class declaration — properties, signals, private members |
| `custom/herelink/VideoStreamControl.cc` | Core logic — heartbeat parsing, MAVLink command, UI lock timer |
| `src/VideoManager/VideoManager.h` | Declares `videoStreamControl` Q_PROPERTY (line 61) |
| `src/VideoManager/VideoManager.cc` | Creates VideoStreamControl (line 112–114), connects `videoNeedsReset` to `_restartAllVideos` |
| `src/Settings/VideoSettings.h` | `DEFINE_SETTINGFACT(cameraId)` (line 40) |
| `src/Settings/Video.SettingsGroup.json` | JSON schema for `cameraId` setting (lines 142–148) |
| `src/FlightMap/Widgets/PhotoVideoControl.qml` | HDMI toggle button (lines 184–194) and toggle function (lines 147–154) |
| `custom/custom.pri` | Build system: includes VideoStreamControl sources (lines 89–94) |
| `custom/src/HerelinkCorePlugin.h` | `isHerelink` property, always returns `true` (line 27) |

---

## 3. Startup Procedure

### Step 1: VideoManager creates VideoStreamControl

During `VideoManager::setToolbox()` (called at app startup):

```cpp
// VideoManager.cc:112-114
_videoStreamControl = new VideoStreamControl();
connect(_videoStreamControl, &VideoStreamControl::videoNeedsReset,
        this, &VideoManager::_restartAllVideos);
```

### Step 2: VideoStreamControl constructor

The constructor wires up all connections:

```cpp
// VideoStreamControl.cc:9-25
VideoStreamControl::VideoStreamControl()
    : QObject()
    , _systemId(-1)
    , _linkInterface(NULL)
    , _cameraServiceUid(0)
    , _cameraCount(0)
    , _settingInProgress(false)
{
    _mavlinkProtocol = qgcApp()->toolbox()->mavlinkProtocol();
    connect(_mavlinkProtocol, &MAVLinkProtocol::messageReceived,
            this, &VideoStreamControl::_mavlinkMessageReceived);

    _videoSettings = qgcApp()->toolbox()->settingsManager()->videoSettings();
    _cameraIdSetting = _videoSettings->cameraId()->rawValue().toUInt();

    connect(_videoSettings->cameraId(), &Fact::rawValueChanged,
            this, &VideoStreamControl::_cameraIdChanged);
    connect(&_settingInProgressTimer, &QTimer::timeout,
            this, &VideoStreamControl::_settingInProgressTimeout);
}
```

What happens here:
- Subscribes to **all incoming MAVLink messages** (filters for camera heartbeats in the handler)
- Reads the **persisted `cameraId`** setting (defaults to 0 = HDMI1)
- Connects the `cameraId` setting change signal to the switch handler
- Sets up a 15-second timeout timer for the UI lock

### Step 3: First Camera Heartbeat

When the air unit's camera component sends its first heartbeat, `_handleHeartbeatInfo` runs:

```cpp
// VideoStreamControl.cc:50-77
void VideoStreamControl::_handleHeartbeatInfo(LinkInterface* link, mavlink_message_t& message)
{
    mavlink_heartbeat_t heartbeat;
    mavlink_msg_heartbeat_decode(&message, &heartbeat);

    // ... (skip if same system with same UID) ...

    _systemId = message.sysid;
    _cameraServiceUid = heartbeat.custom_mode;

    // custom_mode 32bits:
    //   bits 25-31: camera count
    //   bits 16-24: timestamp
    //   bits 0-15:  remote peer pid
    _cameraCount = _cameraServiceUid >> 24;

    _linkInterface = link;
    _startVideoStreaming();   // Send initial MAV_CMD with current cameraId
}
```

This means: **on first connection to the air unit, the currently selected HDMI source is sent automatically** — the user does not need to press any button for the initial stream to start.

If the camera heartbeat's `custom_mode` changes (indicating the air unit's camera service restarted), the video stream is also re-sent.

---

## 4. HDMI Switch Procedure (User Presses Button)

### Step 1: QML Button Click

The button is defined in `PhotoVideoControl.qml`:

```qml
// PhotoVideoControl.qml:184-194
QGCButton {
    id:                     hdmiToggleButton
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top:            parent.top
    visible:                QGroundControl.corePlugin.isHerelink && _videoStreamAvailable
    text:                   _currentHdmiLabel
    enabled:                !QGroundControl.videoManager.videoStreamControl.settingInProgress
    onClicked:              toggleHerelinkHdmiSource()
}
```

**Visibility**: Only shown when `isHerelink` is true and a video stream is available.
**Label**: Shows "HDMI1" when `cameraId == 0`, "HDMI2" when `cameraId == 1`:

```qml
// PhotoVideoControl.qml:53
property string _currentHdmiLabel:
    _videoStreamSettings && _videoStreamSettings.cameraId.rawValue === 0
    ? qsTr("HDMI1") : qsTr("HDMI2")
```

**Enabled state**: Disabled while `settingInProgress` is true (prevents rapid double-clicks).

### Step 2: Toggle Function

```qml
// PhotoVideoControl.qml:147-154
function toggleHerelinkHdmiSource() {
    if (!QGroundControl.corePlugin.isHerelink || !_videoStreamSettings) {
        return
    }
    var nextCameraId = _videoStreamSettings.cameraId.rawValue === 0 ? 1 : 0
    _videoStreamSettings.cameraId.rawValue = nextCameraId
}
```

This simply flips the `cameraId` setting between 0 and 1. The setting change triggers the C++ side via Qt signal.

### Step 3: C++ Handles Setting Change

```cpp
// VideoStreamControl.cc:45-48
void VideoStreamControl::_cameraIdChanged()
{
    _setCameraIdLockUi(true);
}
```

```cpp
// VideoStreamControl.cc:87-99
void VideoStreamControl::_setCameraIdLockUi(bool lockUi)
{
    if (_linkInterface == NULL) {
        return;    // No air unit connected, do nothing
    }
    _cameraIdSetting = _videoSettings->cameraId()->rawValue().toUInt();
    _setCameraId();    // Sends the MAVLink command
    if (lockUi) {
        _setSettingInProgress(true);   // Lock UI for 15 seconds
    }
}
```

### Step 4: MAVLink Command Sent

```cpp
// VideoStreamControl.cc:101-116
void VideoStreamControl::_startVideoStreaming() {
    if (_linkInterface == NULL) {
        return;
    }
    mavlink_message_t msg;
    mavlink_msg_command_long_pack(
        _mavlinkProtocol->getSystemId(),
        _mavlinkProtocol->getComponentId(),
        &msg,
        _systemId,                      // Target system (air unit)
        MAV_COMP_ID_CAMERA,             // Target component
        MAV_CMD_VIDEO_START_STREAMING,  // Command 2502
        0,                              // Confirmation
        _cameraIdSetting,              // Param1: camera ID (0 or 1)
        0, 0, 0, 0, 0, 0              // Params 2-7: unused
    );
    uint8_t buffer[MAVLINK_MAX_PACKET_LEN];
    int len = mavlink_msg_to_send_buffer(buffer, &msg);
    _linkInterface->writeBytesThreadSafe((const char*)buffer, len);

    emit videoNeedsReset();   // Tell VideoManager to restart receivers
}
```

### Step 5: Video Streams Restart

The `videoNeedsReset` signal is connected to `VideoManager::_restartAllVideos`:

```cpp
// VideoManager.cc:861-865
void VideoManager::_restartAllVideos()
{
    _restartVideo(0);   // Primary stream
    _restartVideo(1);   // Secondary/thermal stream
}
```

Each `_restartVideo` call stops the GStreamer receiver and starts it again with the same URI. The air unit's RTSP server now outputs the newly selected HDMI source on the same RTSP endpoint.

### Step 6: UI Unlocks

After 15 seconds (or when the timer is manually stopped), the UI lock releases:

```cpp
// VideoStreamControl.cc:118-134
void VideoStreamControl::_setSettingInProgress(bool inProgress)
{
    if (inProgress) {
        _settingInProgressTimer.setInterval(15000);
        _settingInProgressTimer.setSingleShot(true);
        _settingInProgressTimer.start();
    } else {
        if (_settingInProgressTimer.isActive()) {
            _settingInProgressTimer.stop();
        }
    }
    _settingInProgress = inProgress;
    emit settingInProgressChanged();
}
```

---

## 5. MAVLink Command Details

### Command: MAV_CMD_VIDEO_START_STREAMING

| Field | Value | Notes |
|---|---|---|
| Command ID | 2502 | `MAV_CMD_VIDEO_START_STREAMING` |
| Target System | Air unit's system ID | Learned from camera heartbeat `message.sysid` |
| Target Component | `MAV_COMP_ID_CAMERA` (100) | Camera component on the air unit |
| Param 1 | 0 or 1 | **Video Stream ID**: 0 = HDMI1, 1 = HDMI2 |
| Params 2–7 | 0 | Unused / reserved |

### Heartbeat Camera Detection

VideoStreamControl filters for heartbeat messages where `message.compid == MAV_COMP_ID_CAMERA`. The `custom_mode` field in the heartbeat is parsed as follows:

```
custom_mode (32 bits):
  Bits 25-31 (7 bits): Camera count
  Bits 16-24 (9 bits): Timestamp
  Bits 0-15  (16 bits): Remote peer PID
```

The camera count is extracted with: `_cameraCount = _cameraServiceUid >> 24;`

HDMI switching is only performed if `_cameraCount > 1` (checked in `_setCameraId()`). This means the air unit must report at least 2 cameras for the switching to work.

The `custom_mode` value also serves as a UID — if it changes between heartbeats from the same system, it means the camera service restarted, and the video stream command is re-sent.

---

## 6. Implementation Guide for a Windows QGC Build

This feature has **no Android-specific dependencies**. It is pure C++/Qt/QML communicating over MAVLink. The entire mechanism works on any platform that has MAVLink connectivity to the air unit.

### 6.1 Files to Copy

Copy these two files into your custom plugin directory:

- `custom/herelink/VideoStreamControl.h`
- `custom/herelink/VideoStreamControl.cc`

No modifications needed to these files — they are platform-independent.

### 6.2 Add the cameraId Setting

In `src/Settings/Video.SettingsGroup.json`, add this entry to the JSON array:

```json
{
    "name":             "cameraId",
    "shortDesc":        "Camera ID",
    "longDesc":         "Camera ID used for video streaming.",
    "type":             "uint32",
    "default":          0
}
```

In `src/Settings/VideoSettings.h`, add:

```cpp
DEFINE_SETTINGFACT(cameraId)
```

In `src/Settings/VideoSettings.cc`, add the corresponding `DECLARE_SETTINGSFACT` in the implementation (follow the pattern of existing settings in that file).

### 6.3 Integrate into VideoManager

In `src/VideoManager/VideoManager.h`:

1. Add the include:
   ```cpp
   #include "VideoStreamControl.h"
   ```

2. Add the Q_PROPERTY:
   ```cpp
   Q_PROPERTY(VideoStreamControl* videoStreamControl READ videoStreamControl CONSTANT)
   ```

3. Add the accessor and member:
   ```cpp
   VideoStreamControl* videoStreamControl() { return _videoStreamControl; }
   // ...
   VideoStreamControl* _videoStreamControl = nullptr;
   ```

In `src/VideoManager/VideoManager.cc`, in the `setToolbox()` method (after video settings are initialized):

```cpp
_videoStreamControl = new VideoStreamControl();
connect(_videoStreamControl, &VideoStreamControl::videoNeedsReset,
        this, &VideoManager::_restartAllVideos);
```

Also add the `_restartAllVideos` method if it doesn't exist:

```cpp
void VideoManager::_restartAllVideos()
{
    _restartVideo(0);
    _restartVideo(1);
}
```

### 6.4 Build System

In your `.pri` or `CMakeLists.txt`, add:

```qmake
SOURCES += $$PWD/path/to/VideoStreamControl.cc
HEADERS += $$PWD/path/to/VideoStreamControl.h
INCLUDEPATH += $$PWD/path/to/
```

### 6.5 Add the UI Button

In your QML fly view (wherever your photo/video controls are), add:

```qml
// Properties needed
property var _videoStreamSettings: QGroundControl.settingsManager.videoSettings
property string _currentHdmiLabel:
    _videoStreamSettings && _videoStreamSettings.cameraId.rawValue === 0
    ? qsTr("HDMI1") : qsTr("HDMI2")

// Toggle function
function toggleHdmiSource() {
    if (!_videoStreamSettings) return
    var nextCameraId = _videoStreamSettings.cameraId.rawValue === 0 ? 1 : 0
    _videoStreamSettings.cameraId.rawValue = nextCameraId
}

// Button
QGCButton {
    text:       _currentHdmiLabel
    visible:    _videoStreamAvailable   // adapt this guard to your needs
    enabled:    !QGroundControl.videoManager.videoStreamControl.settingInProgress
    onClicked:  toggleHdmiSource()
}
```

**Adapting the `isHerelink` guard**: The original code uses `QGroundControl.corePlugin.isHerelink` to control button visibility. For a non-Herelink Windows build, you have several options:

- **Always show the button** if you know your hardware always has multiple HDMI inputs — just remove the `isHerelink` check
- **Add your own property** to your custom core plugin (e.g., `isMultiHdmi`) and set it to `true`
- **Make it setting-driven** — add a boolean setting like `enableHdmiSwitching` and use that for visibility

### 6.6 Key Considerations for Windows

1. **MAVLink connectivity**: The switching command is sent over whichever MAVLink link the camera heartbeat arrived on. On Herelink this is typically the built-in radio link. On Windows, ensure you have a MAVLink connection to the air unit (e.g., via UDP, TCP, or serial).

2. **Video source URI**: The RTSP URI does not change when switching — the air unit changes which HDMI input it encodes on the same RTSP endpoint. The default Herelink air unit URI is `rtsp://192.168.0.10:8554/H264Video`. Configure this in your video settings.

3. **GStreamer**: The Windows build must have GStreamer support compiled in (`QGC_GST_STREAMING` define). The video restart mechanism tears down and rebuilds the GStreamer pipeline, which works identically on Windows.

4. **No Android dependencies**: `VideoStreamControl` uses only `QObject`, `MAVLinkProtocol`, `LinkInterface`, `VideoSettings`, and `QTimer` — all platform-independent Qt/QGC classes.

5. **15-second UI lock**: This timeout is a safety measure to prevent rapid switching. You may want to adjust the interval (line 121 in `VideoStreamControl.cc`) depending on your hardware's switching speed.

---

## 7. Quick Reference: What Happens at Each Stage

### On Application Start
1. `VideoManager::setToolbox()` creates `VideoStreamControl`
2. `VideoStreamControl` connects to MAVLink message stream and `cameraId` setting
3. Waits for camera heartbeat

### On First Camera Heartbeat
1. Air unit system ID and link are stored
2. Camera count extracted from heartbeat `custom_mode` (bits 25-31)
3. `MAV_CMD_VIDEO_START_STREAMING` sent with current `cameraId` value
4. `videoNeedsReset` emitted → VideoManager restarts GStreamer receivers

### On HDMI Button Press
1. QML toggles `cameraId` between 0 and 1
2. `VideoStreamControl::_cameraIdChanged()` fires
3. If `_cameraCount > 1` and link is available:
   - `MAV_CMD_VIDEO_START_STREAMING` sent with new `cameraId`
   - `videoNeedsReset` emitted → VideoManager restarts GStreamer
   - UI locked for 15 seconds
4. Button label updates automatically (QML property binding on `cameraId`)

### On Camera Service Restart (Air Unit Side)
1. Heartbeat `custom_mode` changes → detected as remote peer reset
2. `_systemId` reset to 0, then re-acquired from new heartbeat
3. `MAV_CMD_VIDEO_START_STREAMING` re-sent with current `cameraId`
4. Video receivers restarted
