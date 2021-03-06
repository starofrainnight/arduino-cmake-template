
function(string_escape ASTRING OUT_VAR)
    string(REPLACE "\\" "\\\\" REPLACED_STR "${ASTRING}")
    string(REPLACE ";" "\\x" REPLACED_STR "${REPLACED_STR}")
    set(${OUT_VAR} "${REPLACED_STR}" PARENT_SCOPE)
endfunction()

function(string_unescape ASTRING OUT_VAR)
    string(LENGTH "${ASTRING}" ASTRING_LENGTH)

    set(I 0)
    set(UNESCAPED_STRING "")
    while(${I} LESS ${ASTRING_LENGTH})
        string(SUBSTRING "${ASTRING}" ${I} 1 ACHAR)
        if(ACHAR STREQUAL "\\")
            math(EXPR NEXT_I "${I} + 1")
            string(SUBSTRING "${ASTRING}" ${NEXT_I} 1 ANEXT_CHAR)
            if(ANEXT_CHAR STREQUAL "\\")
                set(UNESCAPED_STRING "${UNESCAPED_STRING}\\")
                math(EXPR I "${I} + 1")
            elseif(ANEXT_CHAR STREQUAL "x")
                set(UNESCAPED_STRING "${UNESCAPED_STRING};")
                math(EXPR I "${I} + 1")
            else()
                set(UNESCAPED_STRING "${UNESCAPED_STRING}${ACHAR}")
            endif()
        else()
            set(UNESCAPED_STRING "${UNESCAPED_STRING}${ACHAR}")
        endif()
        math(EXPR I "${I} + 1")
    endwhile()

    set(${OUT_VAR} "${UNESCAPED_STRING}" PARENT_SCOPE)
endfunction()

function(string_split ASTRING SEPARATOR OUT_VAR)
    set(LAST_INDEX -1)
    string(LENGTH "${SEPARATOR}" SEPARATOR_LENGTH)
    set(CURRENT_STRING "${ASTRING}")
    set(LINES "")

    while(TRUE)
        string(FIND "${CURRENT_STRING}" "${SEPARATOR}" FOUND_INDEX)
        string(LENGTH "${CURRENT_STRING}" CURRENT_STRING_LENGTH)
        math(EXPR AFTER_LAST_INDEX "${SEPARATOR_LENGTH} + 0${LAST_INDEX}")

        if(FOUND_INDEX LESS 0)
            math(EXPR REST_LENGTH "${CURRENT_STRING_LENGTH} - ${AFTER_LAST_INDEX}")
            string_escape("${CURRENT_STRING}" EXTRACTED_STRING)
            list(APPEND LINES "${EXTRACTED_STRING}" )
            break()
        else()
            math(EXPR AFTER_FOUND_INDEX "${FOUND_INDEX} + ${SEPARATOR_LENGTH}")
            math(EXPR REST_LENGTH "${CURRENT_STRING_LENGTH} - (${FOUND_INDEX} + ${SEPARATOR_LENGTH})")

            string(SUBSTRING "${CURRENT_STRING}" 0 ${FOUND_INDEX} EXTRACTED_STRING)
            string_escape("${EXTRACTED_STRING}" EXTRACTED_STRING)
            list(APPEND LINES "${EXTRACTED_STRING}")

            string(SUBSTRING "${CURRENT_STRING}" ${AFTER_FOUND_INDEX} ${REST_LENGTH} CURRENT_STRING)
        endif()

        set(LAST_INDEX FOUND_INDEX)
    endwhile()

    set(${OUT_VAR} ${LINES} PARENT_SCOPE)
endfunction()

function(string_splitlines ASTRING OUT_VAR)
    string_escape("${ASTRING}" ASTRING)
    string(FIND "${ASTRING}" "\r\n" FOUND_INDEX)
    if(FOUND_INDEX GREATER -1)
        string(REPLACE "\r\n" ";" ASTRING "${ASTRING}")
    endif()
    string(REPLACE "\r" ";" ASTRING "${ASTRING}")
    string(REPLACE "\n" ";" ASTRING "${ASTRING}")

    set(${OUT_VAR} "${ASTRING}" PARENT_SCOPE)
endfunction()

function(arduino_split_preference_key ASTRING OUT_KEY)
    set(${OUT_KEY} "" PARENT_SCOPE)
    string(FIND "${ASTRING}" "=" FOUND_INDEX)
    if(FOUND_INDEX LESS 0)
        return()
    endif()

    string(SUBSTRING "${ASTRING}" 0 ${FOUND_INDEX} EXTRACTED_STRING)
    string_unescape("${EXTRACTED_STRING}" EXTRACTED_STRING)
    set(${OUT_KEY} "${EXTRACTED_STRING}" PARENT_SCOPE)
endfunction()

function(arduino_split_preference_value ASTRING OUT_VALUE)
    set(${OUT_VALUE} "" PARENT_SCOPE)
    string(FIND "${ASTRING}" "=" FOUND_INDEX)
    if(FOUND_INDEX LESS 0)
        return()
    endif()

    string(LENGTH "${ASTRING}" ASTRING_LENGTH)
    math(EXPR AFTER_FOUND_INDEX "${FOUND_INDEX} + 1")
    math(EXPR REST_LENGTH "${ASTRING_LENGTH} - ${AFTER_FOUND_INDEX}")
    string(SUBSTRING "${ASTRING}" ${AFTER_FOUND_INDEX} ${REST_LENGTH} EXTRACTED_STRING)
    string_unescape("${EXTRACTED_STRING}" EXTRACTED_STRING)
    set(${OUT_VALUE} "${EXTRACTED_STRING}" PARENT_SCOPE)
endfunction()

function(arduino_split_preference ASTRING OUT_KEY OUT_VALUE)
    arduino_split_preference_key("${ASTRING}" GOT_KEY)
    arduino_split_preference_value("${ASTRING}" GOT_VALUE)

    set(${OUT_KEY} "${GOT_KEY}" PARENT_SCOPE)
    set(${OUT_VALUE} "${GOT_VALUE}" PARENT_SCOPE)
endfunction()

function(_arduino_get_preference ALIST KEY OUT_VALUE)
    set(${OUT_VALUE} "" PARENT_SCOPE)
    foreach(PREFERENCE ${${ALIST}})
        arduino_split_preference("${PREFERENCE}" GOT_KEY GOT_VALUE)
        if(GOT_KEY STREQUAL KEY)
            set(${OUT_VALUE} "${GOT_VALUE}" PARENT_SCOPE)
            return()
        endif()
    endforeach()
endfunction()

function(arduino_generate_prefix_key PARENT_KEY SUFFIX_KEY OUT_VALUE)
    string(REPLACE "." ";" SUFFIX_KEY_PARTIES "${SUFFIX_KEY}")
    list(LENGTH SUFFIX_KEY_PARTIES SUFFIX_KEY_PARTIES_LENGTH)

    string(REPLACE "." ";" PARENT_KEY_PARTIES "${PARENT_KEY}")
    list(LENGTH PARENT_KEY_PARTIES PARENT_KEY_PARTIES_LENGTH)

    if(PARENT_KEY_PARTIES_LENGTH GREATER SUFFIX_KEY_PARTIES_LENGTH)
        set(COUNTER ${SUFFIX_KEY_PARTIES_LENGTH})
        while(${COUNTER} GREATER 0)
            math(EXPR I "${PARENT_KEY_PARTIES_LENGTH} - 1 - (${SUFFIX_KEY_PARTIES_LENGTH} - ${COUNTER})")
            list(REMOVE_AT PARENT_KEY_PARTIES ${I})
            math(EXPR COUNTER "${COUNTER} - 1")
        endwhile()

        string(REPLACE ";" "." GENERATED_KEY "${PARENT_KEY_PARTIES}.${SUFFIX_KEY}")

        if("${PARENT_KEY}" STREQUAL "${GENERATED_KEY}")
            string(REPLACE "." ";" PARENT_KEY_PARTIES "${PARENT_KEY}")
            list(LENGTH PARENT_KEY_PARTIES PARENT_KEY_PARTIES_LENGTH)
            math(EXPR I "${PARENT_KEY_PARTIES_LENGTH} - 1")
            list(REMOVE_AT PARENT_KEY_PARTIES ${I})

            arduino_generate_prefix_key("${PARENT_KEY_PARTIES}" "${SUFFIX_KEY}" GENERATED_KEY)
        endif()
    else()
        set(GENERATED_KEY "${SUFFIX_KEY}")
    endif()

    set(${OUT_VALUE} "${GENERATED_KEY}" PARENT_SCOPE)
endfunction()

function(arduino_get_preference KEY OUT_VALUE)
    _arduino_get_preference(ARDUINO_PREFERENCES "${KEY}" PREFERENCE)
    set(${OUT_VALUE} "${PREFERENCE}" PARENT_SCOPE)
endfunction()

function(arduino_get_expanded_preference KEY OUT_VALUE)
    arduino_get_preference("${KEY}" PREFERENCE)

    string(REGEX MATCHALL "\\{[^\\}]+\\}" MATCHED_RESULTS "${PREFERENCE}")
    foreach(ARESULT ${MATCHED_RESULTS})
        string(LENGTH "${ARESULT}" ARESULT_LENGTH)
        math(EXPR ARESULT_LENGTH "${ARESULT_LENGTH} - 2")
        string(SUBSTRING "${ARESULT}" 1 ${ARESULT_LENGTH} ARESULT)

        arduino_get_expanded_preference("${ARESULT}" GOT_VALUE)
        if("${GOT_VALUE}" STREQUAL "")
            arduino_generate_prefix_key("${KEY}" "${ARESULT}" PREFIXED_KEY)
            if(NOT "${PREFIXED_KEY}" STREQUAL "${KEY}")
                arduino_get_expanded_preference("${PREFIXED_KEY}" GOT_VALUE)
            endif()
        endif()
        if("${GOT_VALUE}" STREQUAL "")
            message(
                FATAL_ERROR
                "Failed to expand arduino environment variant \"${ARESULT}\" for \"${KEY}=${PREFERENCE}\"")
        endif()

        string(REPLACE "{${ARESULT}}" "${GOT_VALUE}" PREFERENCE "${PREFERENCE}")
    endforeach()

    set(${OUT_VALUE} "${PREFERENCE}" PARENT_SCOPE)
endfunction()

function(arduino_get_expanded_preference2 KEY OUT_VALUE)
    execute_process(
        COMMAND "${PYTHON_EXECUTABLE}" cmake/ArduinoGetPref.py ${KEY}
        OUTPUT_VARIABLE PREFERENCE)

    string(STRIP "${PREFERENCE}" PREFERENCE)

    set(${OUT_VALUE} "${PREFERENCE}" PARENT_SCOPE)
endfunction()

function(arduino_generate_preferences)
    execute_process(
        COMMAND "${ARDUINO_EXECUTABLE}" --get-pref
        OUTPUT_VARIABLE ARDUINO_PREFERENCES_CONTENT)

    string_splitlines("${ARDUINO_PREFERENCES_CONTENT}" ARDUINO_PREFERENCES)
    _arduino_get_preference(ARDUINO_PREFERENCES "runtime.ide.path" ARDUINO_IDE_PATH)
    _arduino_get_preference(ARDUINO_PREFERENCES "runtime.platform.path" ARDUINO_PLATFORM_PATH)

    # Parse boards.txt, platform.txt, programmers.txt
    file(READ "${ARDUINO_PLATFORM_PATH}/boards.txt" ARDUINO_BOARDS_CONTENT)
    file(READ "${ARDUINO_PLATFORM_PATH}/platform.txt" ARDUINO_PLATFORM_CONTENT)
    file(READ "${ARDUINO_PLATFORM_PATH}/programmers.txt" ARDUINO_PROGRAMMERS_CONTENT)


    string_splitlines("${ARDUINO_BOARDS_CONTENT}" TEMP_PREFERENCES)
    list(APPEND ARDUINO_PREFERENCES ${TEMP_PREFERENCES})

    string_splitlines("${ARDUINO_PLATFORM_CONTENT}" TEMP_PREFERENCES)
    list(APPEND ARDUINO_PREFERENCES ${TEMP_PREFERENCES})

    string_splitlines("${ARDUINO_PROGRAMMERS_CONTENT}" TEMP_PREFERENCES)
    list(APPEND ARDUINO_PREFERENCES ${TEMP_PREFERENCES})

    # Only real preference item could be place into list
    set(NEW_PREFERENCES "")
    foreach(PREFERENCE ${ARDUINO_PREFERENCES})
        if(PREFERENCE MATCHES ".*=.*")
            list(APPEND NEW_PREFERENCES "${PREFERENCE}")
        endif()
    endforeach()
    set(ARDUINO_PREFERENCES "${NEW_PREFERENCES}" PARENT_SCOPE)
endfunction()

find_package(PythonInterp REQUIRED)
find_program(ARDUINO_EXECUTABLE NAMES arduino)

arduino_get_expanded_preference2("runtime.tools.avr-gcc.path" ARDUINO_AVR_GCC_ROOT_PATH)
arduino_get_expanded_preference2("compiler.path" ARDUINO_COMPILER_BASE_PATH)
arduino_get_expanded_preference2("compiler.c.cmd" ARDUINO_C_COMPILER_CMD)
arduino_get_expanded_preference2("compiler.cpp.cmd" ARDUINO_CXX_COMPILER_CMD)
arduino_get_expanded_preference2("compiler.c.flags" ARDUINO_C_FLAGS)
arduino_get_expanded_preference2("compiler.cpp.flags" ARDUINO_CXX_FLAGS)

set(CMAKE_TOOLCHAIN_FILE cmake/ArduinoToolchain.cmake)
