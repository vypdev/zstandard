# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(zstandard_android_library VERSION 0.0.1 LANGUAGES C)

# Gradle supplies the exact dependency selected by the consuming application.
# Direct CMake callers can provide the same override explicitly.
if(DEFINED ZSTD_ROOT AND NOT "${ZSTD_ROOT}" STREQUAL "")
  if(CMAKE_HOST_WIN32)
    file(TO_CMAKE_PATH "${ZSTD_ROOT}" ZSTD_ROOT)
  endif()
  get_filename_component(ZSTD_ROOT "${ZSTD_ROOT}" ABSOLUTE)
  message(STATUS "Using explicit zstandard_native source: ${ZSTD_ROOT}")
else()
  get_filename_component(_PLUGIN_PARENT "${CMAKE_CURRENT_SOURCE_DIR}/../.." ABSOLUTE)
  set(ZSTD_ROOT "${_PLUGIN_PARENT}/zstandard_native/src/zstd")
  message(STATUS "Using repository zstandard_native source: ${ZSTD_ROOT}")
endif()

if(NOT EXISTS "${ZSTD_ROOT}/zstd.h" OR NOT IS_DIRECTORY "${ZSTD_ROOT}/common"
   OR NOT IS_DIRECTORY "${ZSTD_ROOT}/compress" OR NOT IS_DIRECTORY "${ZSTD_ROOT}/decompress")
  message(FATAL_ERROR "zstd source not found at ${ZSTD_ROOT}. Set ZSTD_ROOT or run flutter pub get in the consuming application or workspace.")
endif()

add_definitions(-DZSTD_ENABLE_ASM_X86_64_BMI2=0)
add_definitions(-DDYNAMIC_BMI2=0)

file(GLOB ZSTD_SRC
    "${ZSTD_ROOT}/common/*.c"
    "${ZSTD_ROOT}/compress/*.c"
    "${ZSTD_ROOT}/decompress/*.c"
)

add_library(zstandard_android SHARED ${ZSTD_SRC})

# JNI entry points are compiled into the Debug shared object so instrumentation
# tests exercise the exact library that Dart FFI loads. Production Profile and
# Release binaries must not expose test-only JNI symbols.
if(ANDROID)
  target_sources(zstandard_android PRIVATE
      "$<$<CONFIG:Debug>:${CMAKE_CURRENT_SOURCE_DIR}/../android/src/main/cpp/zstandard_android_test_bridge.c>")
endif()

# The CI instrumentation suite also exercises the maximum compression level
# on a software-only emulator. Keep debug native builds optimized enough that
# this behavioral check does not spend minutes in the high-compression search.
target_compile_options(zstandard_android PRIVATE
    "$<$<CONFIG:Debug>:-O2>"
)

target_include_directories(zstandard_android PUBLIC
    "${ZSTD_ROOT}"
    "${ZSTD_ROOT}/common"
    "${ZSTD_ROOT}/compress"
    "${ZSTD_ROOT}/decompress"
)

set_target_properties(zstandard_android PROPERTIES
    OUTPUT_NAME "zstandard_android"
)

target_compile_definitions(zstandard_android PUBLIC DART_SHARED_LIB)

# Support for 16KB page size alignment (Android 15+)
if(ANDROID)
    target_link_options(zstandard_android PRIVATE "-Wl,-z,max-page-size=16384")
endif()
