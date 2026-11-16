# Configure-time checks for the servo preset JSON files in custom/res/.
# The files are compiled into the app through custom.qrc. A bad file stops the
# configure step, so it can not get into a build.

# Reads json_file into out_var. Stops if the file is missing, is not a JSON
# object, or has something that CMake accepts but Qt's QJsonDocument rejects.
function(_qgc_read_strict_json_object json_file tag out_var)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${json_file}")

    if(NOT EXISTS "${json_file}")
        message(FATAL_ERROR "${tag}: file not found: ${json_file}")
    endif()

    file(READ "${json_file}" _json)

    string(JSON _type ERROR_VARIABLE _err TYPE "${_json}")
    if(_err OR NOT _type STREQUAL "OBJECT")
        message(FATAL_ERROR "${tag}: ${json_file} is not a valid JSON object: ${_err}")
    endif()

    # CMake's JSON parser accepts trailing commas and comments, but Qt's
    # QJsonDocument rejects them (the app would then use built-in defaults).
    # Remove string contents first, so commas/slashes inside names are ignored.
    string(REGEX REPLACE "\"([^\"\\\\]|\\\\.)*\"" "\"\"" _nostr "${_json}")
    if(_nostr MATCHES ",[ \t\r\n]*[]}]")
        message(FATAL_ERROR "${tag}: ${json_file} has a trailing comma before ] or }. Qt can not read it.")
    endif()
    if(_nostr MATCHES "/[/*]")
        message(FATAL_ERROR "${tag}: ${json_file} has a comment. JSON does not allow comments.")
    endif()

    set(${out_var} "${_json}" PARENT_SCOPE)
endfunction()

# MainControlsPresets.json rules:
#   - Top-level object with arrays "buttons" and "mode".
#   - "mode" has at least one item. The first item is the default option.
#   - Each item has: "name" (non-empty string), "channel" (1-18), "pulse" (0-3000).
#   - No two items use the same channel + pulse pair.
function(qgc_validate_main_controls_presets json_file)
    _qgc_read_strict_json_object("${json_file}" MainControlsPresets _json)

    set(_seen_pairs "")
    foreach(_group IN ITEMS buttons mode)
        string(JSON _gtype ERROR_VARIABLE _err TYPE "${_json}" ${_group})
        if(_err OR NOT _gtype STREQUAL "ARRAY")
            message(FATAL_ERROR "MainControlsPresets: \"${_group}\" must be an array")
        endif()

        string(JSON _len LENGTH "${_json}" ${_group})
        if(_group STREQUAL "mode" AND _len EQUAL 0)
            message(FATAL_ERROR "MainControlsPresets: \"mode\" must have at least one item")
        endif()
        if(_len EQUAL 0)
            continue()
        endif()

        math(EXPR _last "${_len} - 1")
        foreach(_i RANGE ${_last})
            set(_where "${_group}[${_i}]")

            string(JSON _name ERROR_VARIABLE _err GET "${_json}" ${_group} ${_i} name)
            string(JSON _ntype ERROR_VARIABLE _err2 TYPE "${_json}" ${_group} ${_i} name)
            if(_err OR _err2 OR NOT _ntype STREQUAL "STRING" OR _name STREQUAL "")
                message(FATAL_ERROR "MainControlsPresets: ${_where}.name must be a non-empty string")
            endif()

            foreach(_field channel pulse)
                string(JSON _ftype ERROR_VARIABLE _err TYPE "${_json}" ${_group} ${_i} ${_field})
                if(_err OR NOT _ftype STREQUAL "NUMBER")
                    message(FATAL_ERROR "MainControlsPresets: ${_where}.${_field} must be a number")
                endif()
                string(JSON _val GET "${_json}" ${_group} ${_i} ${_field})
                if(NOT _val MATCHES "^[0-9]+$")
                    message(FATAL_ERROR "MainControlsPresets: ${_where}.${_field} must be an integer (got ${_val})")
                endif()
                set(_${_field} ${_val})
            endforeach()

            if(_channel LESS 1 OR _channel GREATER 18)
                message(FATAL_ERROR "MainControlsPresets: ${_where}.channel must be 1-18 (got ${_channel})")
            endif()
            if(_pulse GREATER 3000)
                message(FATAL_ERROR "MainControlsPresets: ${_where}.pulse must be 0-3000 (got ${_pulse})")
            endif()

            set(_pair "${_channel}/${_pulse}")
            list(FIND _seen_pairs "${_pair}" _found)
            if(NOT _found EQUAL -1)
                message(FATAL_ERROR "MainControlsPresets: ${_where} (\"${_name}\") uses channel ${_channel} / pulse ${_pulse}, which another item already uses")
            endif()
            list(APPEND _seen_pairs "${_pair}")
        endforeach()
    endforeach()

    message(STATUS "QGC: MainControlsPresets.json OK")
endfunction()

# RemoteDeviceControlPresets.json rules:
#   - Top-level object. Each key below must be a non-empty string.
#   - Unknown keys stop the build too (they are usually a typo of a known key).
function(qgc_validate_remote_device_control_presets json_file)
    _qgc_read_strict_json_object("${json_file}" RemoteDeviceControlPresets _json)

    set(_keys txOn txOff noDevice init activate)

    foreach(_key IN LISTS _keys)
        string(JSON _ktype ERROR_VARIABLE _err TYPE "${_json}" ${_key})
        if(_err OR NOT _ktype STREQUAL "STRING")
            message(FATAL_ERROR "RemoteDeviceControlPresets: \"${_key}\" must be a string")
        endif()
        string(JSON _val GET "${_json}" ${_key})
        if(_val STREQUAL "")
            message(FATAL_ERROR "RemoteDeviceControlPresets: \"${_key}\" must not be empty")
        endif()
    endforeach()

    string(JSON _len LENGTH "${_json}")
    if(_len GREATER 0)
        math(EXPR _last "${_len} - 1")
        foreach(_i RANGE ${_last})
            string(JSON _member MEMBER "${_json}" ${_i})
            list(FIND _keys "${_member}" _found)
            if(_found EQUAL -1)
                message(FATAL_ERROR "RemoteDeviceControlPresets: unknown key \"${_member}\". Allowed keys: ${_keys}")
            endif()
        endforeach()
    endif()

    message(STATUS "QGC: RemoteDeviceControlPresets.json OK")
endfunction()
