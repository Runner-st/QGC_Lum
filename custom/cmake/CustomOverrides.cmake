# C++ файли плагіна
list(APPEND CUSTOM_SOURCES
    ${CMAKE_SOURCE_DIR}/custom/src/ServoControlPlugin.cc
    ${CMAKE_SOURCE_DIR}/custom/src/ServoControlPlugin.h
)

# QML файл плагіна
set(QGC_CUSTOM_QML
    ${CMAKE_SOURCE_DIR}/custom/src/FlyViewCustomLayer.qml
    CACHE INTERNAL "Custom QML files"
)

# Include для заголовків
list(APPEND CUSTOM_INCLUDE_DIRECTORIES
    ${CMAKE_SOURCE_DIR}/custom/src
)

# Stable build (removes "Daily" suffix from app name and window title)
set(QGC_STABLE_BUILD ON CACHE BOOL "Stable Build" FORCE)

# App name (affects window title and other places)
set(QGC_APP_NAME "LumiereQGC" CACHE STRING "App Name" FORCE)

# Organization name (affects settings storage path: %APPDATA%\<ORG_NAME>\)
set(QGC_ORG_NAME "Lumiere" CACHE STRING "Org Name" FORCE)

# Package name (affects registry keys and identifiers)
set(QGC_PACKAGE_NAME "org.lumiere.qgroundcontrol" CACHE STRING "Package Name" FORCE)

# Windows icon and resource file
set(QGC_WINDOWS_ICON_PATH "${CMAKE_SOURCE_DIR}/custom/deploy/windows/WindowsQGC.ico" CACHE FILEPATH "Windows Icon Path" FORCE)
set(QGC_WINDOWS_RESOURCE_FILE_PATH "${CMAKE_SOURCE_DIR}/custom/deploy/windows/QGroundControl.rc" CACHE FILEPATH "Windows Resource File Path" FORCE)
