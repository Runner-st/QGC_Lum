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
