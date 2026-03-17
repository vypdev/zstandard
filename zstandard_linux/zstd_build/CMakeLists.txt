# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(zstandard_linux_library VERSION 0.0.1 LANGUAGES C)

# Find zstd: allow override, else search upward from plugin dir (works from repo and from example symlink)
if(DEFINED ENV{ZSTD_ROOT})
  set(ZSTD_ROOT "$ENV{ZSTD_ROOT}")
endif()
if(NOT ZSTD_ROOT OR NOT EXISTS "${ZSTD_ROOT}/common")
  set(ZSTD_ROOT "")
  get_filename_component(SEARCH_DIR "${CMAKE_CURRENT_SOURCE_DIR}" DIRECTORY)  # plugin root
  while(SEARCH_DIR)
    if(EXISTS "${SEARCH_DIR}/zstd/common")
      set(ZSTD_ROOT "${SEARCH_DIR}/zstd")
      break()
    endif()
    get_filename_component(SEARCH_DIR "${SEARCH_DIR}" DIRECTORY)
    if(SEARCH_DIR STREQUAL "")
      break()
    endif()
  endwhile()
endif()
if(NOT ZSTD_ROOT OR NOT EXISTS "${ZSTD_ROOT}/common")
  message(FATAL_ERROR "zstd source not found. Set ZSTD_ROOT or ensure zstd is a sibling of the repo (e.g. zstandard/zstd).")
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
