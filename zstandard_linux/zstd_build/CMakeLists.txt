# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(zstandard_linux_library VERSION 0.0.1 LANGUAGES C)

# Allow explicit override
if(DEFINED ENV{ZSTD_ROOT} AND EXISTS "$ENV{ZSTD_ROOT}/common")
  set(ZSTD_ROOT "$ENV{ZSTD_ROOT}")
  message(STATUS "Using ZSTD_ROOT: ${ZSTD_ROOT}")
else()
  # 1. Prefer repo local zstandard_native/src/zstd
  if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../../zstandard_native/src/zstd/common")
    set(ZSTD_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../zstandard_native/src/zstd")
    message(STATUS "Using local zstandard_native: ${ZSTD_ROOT}")
  else()
    # 2. Look for zstandard_native in pub-cache (versioned dirs only, e.g. zstandard_native-1.4.0)
    file(GLOB NATIVE_PARENT_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/../../zstandard_native-*")
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
      message(FATAL_ERROR "zstd source not found. Set ZSTD_ROOT or ensure zstandard_native is available (repo: ../../zstandard_native/src/zstd or pub-cache).")
    endif()
  endif()
endif()

file(GLOB ZSTD_SRC
    "${ZSTD_ROOT}/common/*.c"
    "${ZSTD_ROOT}/compress/*.c"
    "${ZSTD_ROOT}/decompress/*.c"
)

add_library(zstandard_linux SHARED ${ZSTD_SRC})

target_include_directories(zstandard_linux PUBLIC
    "${ZSTD_ROOT}"
    "${ZSTD_ROOT}/common"
    "${ZSTD_ROOT}/compress"
    "${ZSTD_ROOT}/decompress"
)

set_target_properties(zstandard_linux PROPERTIES
    OUTPUT_NAME "zstandard_linux"
)

# Disable zstd assembly to avoid linking .S files; C implementation is used instead.
target_compile_definitions(zstandard_linux PUBLIC DART_SHARED_LIB ZSTD_DISABLE_ASM)
