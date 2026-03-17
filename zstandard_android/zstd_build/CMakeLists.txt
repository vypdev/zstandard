# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(zstandard_android_library VERSION 0.0.1 LANGUAGES C)

# Resolve parent of plugin (repo root or pub-cache hosted dir) for consistent paths
get_filename_component(_PLUGIN_PARENT "${CMAKE_CURRENT_SOURCE_DIR}/../.." ABSOLUTE)
# 1. Prefer repo local zstandard_native/src/zstd
set(_LOCAL_ZSTD "${_PLUGIN_PARENT}/zstandard_native/src/zstd")
if(EXISTS "${_LOCAL_ZSTD}/common")
  set(ZSTD_ROOT "${_LOCAL_ZSTD}")
  message(STATUS "Using local zstandard_native: ${ZSTD_ROOT}")
else()
  # 2. Look for zstandard_native in pub-cache (versioned dirs only, e.g. zstandard_native-1.4.0; do not match zstandard_native2 etc.)
  file(GLOB NATIVE_PARENT_DIRS "${_PLUGIN_PARENT}/zstandard_native-*")
  if(NATIVE_PARENT_DIRS)
    list(GET NATIVE_PARENT_DIRS 0 NATIVE_PKG_DIR)
    set(ZSTD_CANDIDATE "${NATIVE_PKG_DIR}/src/zstd")
    if(EXISTS "${ZSTD_CANDIDATE}/common")
      set(ZSTD_ROOT "${ZSTD_CANDIDATE}")
      message(STATUS "Using zstandard_native from pub-cache: ${ZSTD_ROOT}")
    endif()
  endif()
  if(NOT ZSTD_ROOT AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../.dart_tool/package_config.json")
    file(READ "${CMAKE_CURRENT_SOURCE_DIR}/../.dart_tool/package_config.json" PACKAGE_CONFIG_CONTENT)
    string(REGEX MATCH "\"name\": \"zstandard_native\"[^}]*\"rootUri\": \"([^\"]+)\"" _ "${PACKAGE_CONFIG_CONTENT}")
    set(NATIVE_ROOT_URI "${CMAKE_MATCH_1}")
    if(NATIVE_ROOT_URI)
      string(REGEX REPLACE "^file://" "" NATIVE_ROOT "${NATIVE_ROOT_URI}")
      set(ZSTD_CANDIDATE "${NATIVE_ROOT}/src/zstd")
      if(EXISTS "${ZSTD_CANDIDATE}/common")
        set(ZSTD_ROOT "${ZSTD_CANDIDATE}")
        message(STATUS "Using zstandard_native from package_config: ${ZSTD_ROOT}")
      endif()
    endif()
  endif()
  if(NOT ZSTD_ROOT OR NOT EXISTS "${ZSTD_ROOT}/common")
    message(FATAL_ERROR "zstd source not found. Ensure zstandard_native dependency is available (repo: ../../zstandard_native/src/zstd or pub-cache).")
  endif()
endif()

add_definitions(-DZSTD_ENABLE_ASM_X86_64_BMI2=0)
add_definitions(-DDYNAMIC_BMI2=0)

file(GLOB ZSTD_SRC
    "${ZSTD_ROOT}/common/*.c"
    "${ZSTD_ROOT}/compress/*.c"
    "${ZSTD_ROOT}/decompress/*.c"
)

add_library(zstandard_android SHARED ${ZSTD_SRC})

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
