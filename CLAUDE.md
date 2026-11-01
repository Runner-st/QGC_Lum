# Project Rules and Guidelines

## Qt/C++ Rules

### Q_PROPERTY Access from C++

When accessing Qt Q_PROPERTY values from C++ code:

- **Do NOT** assume a public getter exists matching the property name
- **Check** the header file for the actual READ function - it may be private (e.g., `_getPropertyName`)
- **Use** the Qt property system for private getters:
  ```cpp
  // Wrong - getter may be private:
  instance->propertyName()

  // Correct - use property system:
  instance->property("propertyName").toBool()
  instance->property("propertyName").toInt()
  instance->property("propertyName").toString()
  ```

Example from MultiVehicleManager:
```cpp
// The Q_PROPERTY declaration:
// Q_PROPERTY(bool parameterReadyVehicleAvailable READ _getParameterReadyVehicleAvailable NOTIFY ...)
// Note: _getParameterReadyVehicleAvailable is PRIVATE

// Wrong:
MultiVehicleManager::instance()->parameterReadyVehicleAvailable()

// Correct:
MultiVehicleManager::instance()->property("parameterReadyVehicleAvailable").toBool()
```

## QGroundControl Specific

- This is a custom fork of QGroundControl for Lumineer
- Custom code lives in `custom/src/`
- Video streaming uses GStreamer
- LinksManager handles managed link configurations with video streams

## Pinned CPM Dependencies

All `CPMAddPackage` calls use a fixed commit SHA in `GIT_TAG`. Do not use `main` or `master`.

**Why:** CI starts from an empty `build/` folder, so it downloads the newest commit of a branch. The local build keeps its old copy in `build/.../cpm_modules`. When upstream changed, CI failed and the local build did not. This occurred with px4-gpsdrivers and libevents (2026-11-01).

| Package | File | Pinned commit | Bump condition |
|---|---|---|---|
| px4-gpsdrivers | `src/GPS/CMakeLists.txt` | `2b05a67` + `ubx-msvc-packed.patch` | Update `src/GPS/sensor_gps.h` at the same time (commit `1b27986` renames `rtcm_*` fields) |
| libevents | `src/MAVLink/LibEvents/CMakeLists.txt` | `077677a` | Update `QGC_MAVLINK_GIT_TAG` in `cmake/CustomOptions.cmake` at the same time (commit `0ef305f` needs newer MAVLink) |
| MAVLink c_library_v2 | `cmake/CustomOptions.cmake` (`QGC_MAVLINK_GIT_TAG`) | `19f9955` | Check libevents |
| ulog_cpp | `src/AnalyzeView/CMakeLists.txt` | `af366a9` | No known limit |
| ArduPilotParams | `src/FirmwarePlugin/APM/CMakeLists.txt` | `da34877` | Bump to get parameter metadata for new ArduPilot versions |
| SDL_GameControllerDB | `src/Joystick/CMakeLists.txt` | `22a98f6` | Bump to get new joystick mappings. Upstream rewrites `master` history (2026-09: old pin `8cf7555` was removed). Before you pin, make sure that the SHA is on `master` (`git merge-base --is-ancestor <sha> origin/master` in a full clone) |
| qmdnsengine | `src/Comms/CMakeLists.txt` | `9de38df` | No known limit (used only with `QGC_ZEROCONF_ENABLED`) |
| create-dmg | `cmake/install/Install.cmake` | `a2b71d0` | No known limit (macOS only) |

To bump a pin:
1. Read the upstream commits between the old SHA and the new SHA.
2. Change `GIT_TAG` to the new full SHA. Update the comment and this table.
3. Delete the package folder in local `cpm_modules`, or do a clean build. If you do not, the local build uses the old copy.

On the Windows CI runner, CPM must use `C:/Program Files/Git/usr/bin/patch.exe` (set by `-DPATCH_EXECUTABLE` in `.github/workflows/build-windows.yml`). The Strawberry `patch.exe` 2.5.9 fails on LF patches.
