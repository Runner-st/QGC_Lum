if(QGC_NO_SERIAL_LINK)
    return()
endif()

target_sources(${CMAKE_PROJECT_NAME}
    PRIVATE
        GPSManager.cc
        GPSManager.h
        GPSProvider.cc
        GPSProvider.h
        GPSRtk.cc
        GPSRtk.h
        GPSRTKFactGroup.cc
        GPSRTKFactGroup.h
        RTCMMavlink.cc
        RTCMMavlink.h
        satellite_info.h
        sensor_gnss_relative.h
        sensor_gps.h
)

target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE Qt6::Core)

target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

#===========================================================================#

# Pinned rather than tracking main: an upstream push can otherwise break the build at random.
#
# Held at 2b05a67 (2026-08-20) because the next commit, 1b27986 ("SEC-SIG jamming, RXM-COR
# correction status..."), renames sensor_gps_s::rtcm_crc_failed/rtcm_msg_used to corrections_*
# and adds CORRECTIONS_PROTOCOL_* constants. Our local src/GPS/sensor_gps.h still uses the rtcm_*
# names, so anything at or past 1b27986 fails to compile. Bump this pin only together with
# sensor_gps.h.
#
# ubx-msvc-packed.patch fixes commit 7206539, which introduced a GCC-only __attribute__((packed))
# into ubx.h. MSVC rejects it; the rest of that file already uses #pragma pack, so the patch just
# makes this struct match. Drop the patch once upstream fixes it.
CPMAddPackage(
    NAME px4-gpsdrivers
    GITHUB_REPOSITORY PX4/PX4-GPSDrivers
    GIT_TAG 2b05a673610e63f7db73dec7ef477f1275c96c8d
    SOURCE_SUBDIR src
    PATCHES ubx-msvc-packed.patch
)

file(GLOB GPS_DRIVERS_SOURCES "${px4-gpsdrivers_SOURCE_DIR}/src/*")
target_sources(${CMAKE_PROJECT_NAME}
    PRIVATE
        definitions.h
        ${GPS_DRIVERS_SOURCES}
)

# Add JSON files
qt_add_resources(${CMAKE_PROJECT_NAME} json_gps_drivers
    PREFIX "/json/Vehicle"
    FILES GPSRTKFact.json
)

target_compile_definitions(${CMAKE_PROJECT_NAME} PRIVATE GPS_DEFINITIONS_HEADER=<${CMAKE_CURRENT_SOURCE_DIR}/definitions.h>)

target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE ${px4-gpsdrivers_SOURCE_DIR}/src)
