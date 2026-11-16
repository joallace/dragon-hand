# JsRuntime GDExtension: quickjs-ng behind a small Godot class.
#   cmake -S native/js_runtime -B <build> -DCMAKE_BUILD_TYPE=Release \
#     -DGODOT_CPP_DIR=<godot-cpp checkout> -DQUICKJS_DIR=<quickjs-ng checkout>
#   cmake --build <build> -j
# The library lands in native/js_runtime/bin/.
cmake_minimum_required(VERSION 3.17)
project(js_runtime C CXX)

set(GODOT_CPP_DIR "" CACHE PATH "godot-cpp checkout (10.x)")
set(QUICKJS_DIR "" CACHE PATH "quickjs-ng checkout")
if(NOT GODOT_CPP_DIR OR NOT QUICKJS_DIR)
    message(FATAL_ERROR "Set GODOT_CPP_DIR and QUICKJS_DIR")
endif()

set(GODOTCPP_TARGET "template_release" CACHE STRING "")
# Oldest API with everything JsRuntime uses; newer engines load it as is.
set(GODOTCPP_API_VERSION "4.3" CACHE STRING "")
add_subdirectory(${GODOT_CPP_DIR} godot-cpp EXCLUDE_FROM_ALL)

add_library(quickjs STATIC
    ${QUICKJS_DIR}/quickjs.c
    ${QUICKJS_DIR}/libregexp.c
    ${QUICKJS_DIR}/libunicode.c
    ${QUICKJS_DIR}/dtoa.c
)
target_include_directories(quickjs PUBLIC ${QUICKJS_DIR})
target_compile_definitions(quickjs PRIVATE _GNU_SOURCE NDEBUG)
set_target_properties(quickjs PROPERTIES
    C_STANDARD 11
    POSITION_INDEPENDENT_CODE ON
    C_VISIBILITY_PRESET hidden
)
if(NOT MSVC)
    target_compile_options(quickjs PRIVATE -w)
endif()

add_library(js_runtime SHARED
    src/js_runtime.cpp
    src/register_types.cpp
)
target_link_libraries(js_runtime PRIVATE godot-cpp quickjs)
if(UNIX AND NOT APPLE)
    target_link_libraries(js_runtime PRIVATE m)
    target_link_options(js_runtime PRIVATE -Wl,--gc-sections -s)
endif()
if(WIN32)
    target_link_options(js_runtime PRIVATE -static -s)
endif()

string(TOLOWER "${CMAKE_SYSTEM_NAME}" JS_RUNTIME_PLATFORM)
set_target_properties(js_runtime PROPERTIES
    PREFIX "lib"
    OUTPUT_NAME "js_runtime.${JS_RUNTIME_PLATFORM}.x86_64"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/bin"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/bin"
)
