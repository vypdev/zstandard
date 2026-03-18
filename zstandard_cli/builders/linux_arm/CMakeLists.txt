# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(zstandard_linux_library VERSION 0.0.1 LANGUAGES C)

set(ZSTD_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../zstandard_native/src/zstd")
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

target_compile_definitions(zstandard_linux PUBLIC
        DYNAMIC_BMI2=0
        DART_SHARED_LIB
)
