# Release Notes: Servo Buttons Integration into Links

## Overview
This release moves servo button configuration from a standalone settings page into the LinksManager, allowing per-link servo button definitions.

## Changes

### 1. Per-Link Servo Button Configuration
Servo buttons are now configured per-link instead of globally. Each managed link can have its own set of servo buttons that appear in the Fly View when that link is active.

**Benefits:**
- Different UAVs can have different servo button configurations
- Servo buttons are contextually relevant to the active link
- No need to reconfigure when switching between vehicles

### 2. New ServoButtonConfiguration Class
Added a dedicated configuration class for servo buttons with:
- Button name (display label)
- MAVLink channel (1-18)
- Pulse width (500-3000 PWM, default 1500)
- JSON serialization for persistence

**Files added:**
- `custom/src/LinksManager/ServoButtonConfiguration.cc`
- `custom/src/LinksManager/ServoButtonConfiguration.h`

### 3. LinksManager Integration
`ManagedLinkConfiguration` now includes a `servoButtons` property containing a list of `ServoButtonConfiguration` objects.

**New methods:**
- `addServoButton(name, channel, pulseWidth)` - Add a new servo button
- `removeServoButton(index)` - Remove a servo button by index
- `updateServoButton(index, name, channel, pulseWidth)` - Update existing button

### 4. UI Changes
- **Added:** `ServoButtonConfigEditor.qml` - Editor component for servo buttons within link edit dialog
- **Removed:** `ServoControlSettings.qml` - Standalone settings page (no longer needed)
- **Removed:** Servo Control entry from `SettingsPagesModel.qml`

### 5. CMake Consolidation
- `CUSTOM_SOURCES` and `CUSTOM_INCLUDE_DIRECTORIES` are now defined only in `custom/CMakeLists.txt`
- Removed duplicate definitions from `custom/cmake/CustomOverrides.cmake`
- Single source of truth for custom source files

## Migration
Existing global servo button configurations will need to be reconfigured per-link in the LinksManager edit dialog.

## Testing Checklist
- [ ] Create a new link with servo buttons configured
- [ ] Verify servo buttons appear in Fly View when link is active
- [ ] Verify servo buttons send correct MAVLink commands on click
- [ ] Edit existing link to add/remove/modify servo buttons
- [ ] Verify servo button configuration persists across app restarts
- [ ] Verify different links can have different servo button configurations
