# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(zstandard_macos_library VERSION 0.0.1 LANGUAGES C)

# Zstd source: use ZSTD_SRC_DIR if set (canonical zstandard_macos/src), else ../../src
if(DEFINED ZSTD_SRC_DIR)
  set(ZSTD_ROOT "${ZSTD_SRC_DIR}")
else()
  set(ZSTD_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../src")
endif()
file(GLOB ZSTD_SRC_FILES
        "${ZSTD_ROOT}/common/*.c"
        "${ZSTD_ROOT}/compress/*.c"
        "${ZSTD_ROOT}/decompress/*.c"
)

add_library(zstandard_macos SHARED ${ZSTD_SRC_FILES})

target_include_directories(zstandard_macos PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${ZSTD_ROOT}"
    "${ZSTD_ROOT}/common"
    "${ZSTD_ROOT}/compress"
    "${ZSTD_ROOT}/decompress"
)

set_target_properties(zstandard_macos PROPERTIES
  PUBLIC_HEADER zstandard_macos.h
  OUTPUT_NAME "zstandard_macos"
)

target_compile_definitions(zstandard_macos PUBLIC
        DYNAMIC_BMI2=0
        HUF_NEED_BMI2_FUNCTION=0
        ZSTD_ENABLE_ASM_X86_64_BMI2=0
        DART_SHARED_LIB
)