target_sources(${CMAKE_PROJECT_NAME}
    PRIVATE
        EventHandler.cc
        EventHandler.h
        HealthAndArmingCheckReport.cc
        HealthAndArmingCheckReport.h
        logging.cpp
)

target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

#===========================================================================#

# Pinned rather than tracking main: an upstream push can otherwise break the build at random.
#
# Held at 077677a (2026-09-14) because the next commit, 0ef305f ("protocol: support 32 bit
# system IDs"), calls mavlink_msg_target_field() and mavlink_msg_get_target_system(). Those exist
# only in a newer c_library_v2 than QGC_MAVLINK_GIT_TAG (cmake/CustomOptions.cmake). Bump this pin
# only together with the MAVLink tag.
CPMAddPackage(
    NAME libevents
    GITHUB_REPOSITORY mavlink/libevents
    GIT_TAG 077677a7d2f48f0af0eb8a4e4a7b6310956728bc
    SOURCE_SUBDIR libs/cpp
)

target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE libevents)
target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE ${libevents_SOURCE_DIR}/libs/cpp)
