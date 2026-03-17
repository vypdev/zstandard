# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

project(zstandard_windows_library VERSION 0.0.1 LANGUAGES C)

# Allow explicit override
if(DEFINED ENV{ZSTD_ROOT} AND EXISTS "$ENV{ZSTD_ROOT}/common")
  set(ZSTD_ROOT "$ENV{ZSTD_ROOT}")
  message(STATUS "Using ZSTD_ROOT: ${ZSTD_ROOT}")
else()
  # 1a. When built via .plugin_symlinks, resolve repo root by walking up (avoids broken symlink path)
  string(FIND "${CMAKE_CURRENT_SOURCE_DIR}" ".plugin_symlinks" _IN_SYMLINKS)
  if(NOT _IN_SYMLINKS EQUAL -1)
    set(_SEARCH "${CMAKE_CURRENT_SOURCE_DIR}")
    foreach(_IGNORE RANGE 12)
      get_filename_component(_SEARCH_NEXT "${_SEARCH}/.." ABSOLUTE)
      if(NOT _SEARCH_NEXT OR _SEARCH_NEXT STREQUAL _SEARCH OR _SEARCH_NEXT STREQUAL "/")
        break()
      endif()
      set(_SEARCH "${_SEARCH_NEXT}")
      if(EXISTS "${_SEARCH}/zstandard_native/src/zstd/common" AND EXISTS "${_SEARCH}/zstandard_windows")
        set(ZSTD_ROOT "${_SEARCH}/zstandard_native/src/zstd")
        message(STATUS "Using repo-local zstandard_native: ${ZSTD_ROOT}")
        break()
      endif()
    endforeach()
  endif()
  # 1b. Prefer repo local ../../zstandard_native when not under .plugin_symlinks
  if(NOT ZSTD_ROOT AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../../zstandard_native/src/zstd/common")
    set(ZSTD_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../zstandard_native/src/zstd")
    message(STATUS "Using local zstandard_native: ${ZSTD_ROOT}")
  endif()
  if(NOT ZSTD_ROOT OR NOT EXISTS "${ZSTD_ROOT}/common")
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

add_library(zstandard_windows SHARED ${ZSTD_SRC})

target_include_directories(zstandard_windows PUBLIC
    "${ZSTD_ROOT}"
    "${ZSTD_ROOT}/common"
    "${ZSTD_ROOT}/compress"
    "${ZSTD_ROOT}/decompress"
)

set_target_properties(zstandard_windows PROPERTIES
    OUTPUT_NAME "zstandard_windows"
)

target_compile_definitions(zstandard_windows PUBLIC
    ZSTD_DLL_EXPORT=1
    DART_SHARED_LIB
)
