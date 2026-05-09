# qt6d3d11 GStreamer plugin (qml6d3d11sink) — vendored from upstream
# gst-plugins-bad/ext/qt6d3d11/ for the QGC build. Mirrors the structure of
# the sibling gstqml6gl/ subproject. Windows-only (the plugin needs the
# GStreamer D3D11 library and Qt's D3D11 RHI).

if(NOT WIN32)
    return()
endif()

qt_add_library(gstqt6d3d11 STATIC)

set_target_properties(gstqt6d3d11 PROPERTIES
    AUTOMOC ON
    AUTOMOC_MACRO_NAMES "Q_OBJECT;QML_ELEMENT;QML_NAMED_ELEMENT"
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
)

target_link_libraries(gstqt6d3d11 PUBLIC GStreamer::GStreamer)

# gstreamer-d3d11-1.0 (libgstd3d11-1.0 + d3d11 + dxgi). Discovered via the
# pkg-config that already ships with the user's GStreamer install.
find_package(PkgConfig REQUIRED QUIET)
pkg_check_modules(PC_GSTREAMER_D3D11 REQUIRED IMPORTED_TARGET gstreamer-d3d11-1.0)
target_link_libraries(gstqt6d3d11 PUBLIC PkgConfig::PC_GSTREAMER_D3D11)

set(QGC_GST_QT6D3D11_PLUGIN_PATH "${CMAKE_CURRENT_SOURCE_DIR}/qt6")

target_sources(gstqt6d3d11 PRIVATE
    ${QGC_GST_QT6D3D11_PLUGIN_PATH}/gstqml6d3d11sink.cpp
    ${QGC_GST_QT6D3D11_PLUGIN_PATH}/gstqml6d3d11sink.h
    ${QGC_GST_QT6D3D11_PLUGIN_PATH}/gstqsg6d3d11node.cpp
    ${QGC_GST_QT6D3D11_PLUGIN_PATH}/gstqsg6d3d11node.h
    ${QGC_GST_QT6D3D11_PLUGIN_PATH}/gstqt6d3d11videoitem.cpp
    ${QGC_GST_QT6D3D11_PLUGIN_PATH}/gstqt6d3d11videoitem.h
    ${QGC_GST_QT6D3D11_PLUGIN_PATH}/plugin.cpp
)

target_link_libraries(gstqt6d3d11
    PRIVATE
        Qt6::GuiPrivate
        d3d11
        dxgi
    PUBLIC
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Quick
)

target_include_directories(gstqt6d3d11
    PUBLIC
        ${QGC_GST_QT6D3D11_PLUGIN_PATH}
    PRIVATE
        # Trimmed gst/d3d11/gstd3d11-private.h vendored locally; the SDK
        # does not ship private headers.
        ${CMAKE_CURRENT_SOURCE_DIR}/private_include
)

target_compile_definitions(gstqt6d3d11
    PRIVATE
        GST_USE_UNSTABLE_API
        # GST_PLUGIN_DEFINE expands to references both GST_PACKAGE_*/VERSION
        # (which the upstream meson build provides via config.h) and PACKAGE
        # (which the gst-plugins-bad meson sets globally). Provide all of
        # them here so plugin.cpp compiles standalone.
        GST_PACKAGE_NAME="QGroundControl qt6d3d11 plugin"
        GST_PACKAGE_ORIGIN="https://qgroundcontrol.com"
        VERSION="1.24.13"
        PACKAGE="qgc-qt6d3d11"
)
