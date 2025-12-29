message(STATUS "QGC: Adding Custom Plugin")

list(APPEND CUSTOM_RESOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/custom.qrc
)
set(QGC_RESOURCES ${QGC_RESOURCES} ${CUSTOM_RESOURCES} CACHE STRING "Paths to .qrc Resources" FORCE)

set(CUSTOM_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ServoControlPlugin.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ServoControlPlugin.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/LinksManager/LinksManagerController.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/LinksManager/LinksManagerController.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/LinksManager/ManagedLinkConfiguration.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/LinksManager/ManagedLinkConfiguration.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/LinksManager/CameraConfiguration.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/LinksManager/CameraConfiguration.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/LinksManager/CameraStreamConfiguration.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/LinksManager/CameraStreamConfiguration.h
    CACHE INTERNAL "" FORCE
)

set(CUSTOM_LIBRARIES
    Qt6::Core
    CACHE INTERNAL "" FORCE
)

set(CUSTOM_INCLUDE_DIRECTORIES
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/src/LinksManager
    CACHE INTERNAL "" FORCE
)

set(CUSTOM_DEFINITIONS
    QGC_CUSTOM_BUILD
    CUSTOMHEADER="ServoControlPlugin.h"
    CUSTOMCLASS=ServoControlPlugin
    CACHE INTERNAL "" FORCE
)

set(CUSTOM_QT_COMPONENTS
    Core
    CACHE INTERNAL "" FORCE
)