# C++ файли плагіна
list(APPEND CUSTOM_SOURCES
    ${CMAKE_SOURCE_DIR}/custom/src/CustomPlugin.cc
    ${CMAKE_SOURCE_DIR}/custom/src/CustomPlugin.h
    ${CMAKE_SOURCE_DIR}/custom/src/QGroundControlQmlGlobalCustom.cc
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