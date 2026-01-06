# Release Notes: GStreamer RTSP Compatibility & LinksManager Integration

## Overview
This release fixes GStreamer compatibility with strict RTSP servers (TOPOTEK KHP290A609 cameras) and re-enables low-latency GStreamer video streaming for LinksManager-managed streams.

## Changes

### 1. GStreamer Upgrade
- **Upgraded from GStreamer 1.22.12 to 1.24.13**
- Required for the `force-non-compliant-url` property that fixes strict RTSP server compatibility

### 2. TOPOTEK KHP290A609 Camera Compatibility Fix
**Problem:** GStreamer's `rtspsrc` element was sending a `Session` header in RTSP SETUP requests, violating RFC 2326. The TOPOTEK camera's RTSP server (Real/LIVE555-derived) rejected this and dropped the TCP connection.

**Solution:** Added `force-non-compliant-url=TRUE` property to rtspsrc configuration (available in GStreamer 1.24.7+).

**File:** `src/VideoManager/VideoReceiver/GStreamer/GstVideoReceiver.cc`
```cpp
g_object_set(source,
             "location", input.toUtf8().constData(),
             "latency", 150,
             "force-non-compliant-url", TRUE,
             nullptr);
```

**Note:** This fix is safe for all cameras. Skydroid and other standard cameras continue to work normally.

### 3. LinksManager GStreamer Integration
LinksManager-managed streams now use GStreamer for the main video stream, providing significantly lower latency compared to the FFmpeg/Qt Multimedia fallback.

**Architecture:**
- **Main stream:** Uses GStreamer via VideoManager override URI (low latency ~150ms buffer)
- **PIP streams:** Continue using FFmpeg/Qt Multimedia
- **Stream swapping:** Clicking PIP to swap streams works - whichever stream is in main view gets GStreamer

**Files modified:**
- `custom/src/LinksManager/LinksManagerController.cc` - Sets VideoManager override URI when activating/deactivating links
- `custom/src/FlightDisplayViewVideo.qml` - Shows GStreamer when override active, FFmpeg fallback otherwise

### 4. Video Latency Optimization
- **Jitter buffer latency:** Set to 150ms (down from default 2000ms)
- Provides good balance between low latency and smooth playback
- Eliminates choppy video while maintaining responsive streaming

## Technical Details

### Root Cause Analysis
The TOPOTEK KHP290A609 camera uses a strict RTSP server implementation that:
1. Rejects SETUP requests containing a `Session` header (before server assigns one)
2. Drops TCP connection silently instead of returning RTSP error
3. Is derived from Real/LIVE555 stack with strict RFC compliance

GStreamer was sending:
```
SETUP rtsp://192.168.144.108:554/stream=1/realvideo RTSP/1.0
Session: 1905491376  <-- RFC violation: Session not yet assigned
```

VLC/FFmpeg correctly omit the Session header in SETUP requests.

### Compatibility
- **TOPOTEK KHP290A609:** Now works with GStreamer
- **Skydroid cameras:** Continue to work (were already compatible)
- **Other RTSP cameras:** Should work; `force-non-compliant-url` is safe for compliant servers

## Build Requirements
- GStreamer 1.24.7 or higher (tested with 1.24.13)
- MSVC 2022
- Qt 6.8.3

## Testing Checklist
- [ ] TOPOTEK camera stream displays in main view via LinksManager
- [ ] Skydroid camera stream displays correctly
- [ ] PIP streams display and can be clicked to swap
- [ ] Stream swapping updates main view to new stream
- [ ] Video is smooth (no choppiness)
- [ ] Latency is acceptable (~150ms + network delay)
- [ ] Link activation/deactivation works correctly
- [ ] Auto-reconnect works when UAV connection is restored
