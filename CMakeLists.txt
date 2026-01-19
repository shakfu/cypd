cmake_minimum_required(VERSION 3.15...3.30)
project(${SKBUILD_PROJECT_NAME} VERSION ${SKBUILD_PROJECT_VERSION} LANGUAGES C)

# Find Python
find_package(Python REQUIRED COMPONENTS Interpreter Development.Module)

# ============================================================================
# Paths
# ============================================================================

# libpd
set(LIBPD_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/pure-data")
set(LIBPD_INCLUDE_DIR "${LIBPD_ROOT}/include")
set(LIBPD_LIB_DIR "${LIBPD_ROOT}/lib")

# miniaudio
set(MINIAUDIO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/miniaudio")

# Cython sources
set(CYPD_SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/src/cypd")

# ============================================================================
# Check dependencies
# ============================================================================

if(NOT EXISTS "${LIBPD_LIB_DIR}/libpd.a")
    message(FATAL_ERROR "libpd not found. Run scripts/setup.sh first to build dependencies.")
endif()

if(NOT EXISTS "${MINIAUDIO_ROOT}/miniaudio.h")
    message(FATAL_ERROR "miniaudio.h not found in ${MINIAUDIO_ROOT}")
endif()

# ============================================================================
# _libpd module (core libpd wrapper)
# ============================================================================

set(LIBPD_CYTHON_SOURCE "${CYPD_SRC_DIR}/_libpd.pyx")
set(LIBPD_CYTHON_OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/_libpd.c")

add_custom_command(
    OUTPUT ${LIBPD_CYTHON_OUTPUT}
    COMMAND Python::Interpreter -m cython
        -I "${CYPD_SRC_DIR}"
        "${LIBPD_CYTHON_SOURCE}"
        -o ${LIBPD_CYTHON_OUTPUT}
    DEPENDS
        ${LIBPD_CYTHON_SOURCE}
        "${CYPD_SRC_DIR}/pd.pxd"
        "${CYPD_SRC_DIR}/libpd.pxd"
    COMMENT "Cython: _libpd.pyx -> _libpd.c"
)

python_add_library(_libpd MODULE ${LIBPD_CYTHON_OUTPUT} WITH_SOABI)

target_include_directories(_libpd PRIVATE
    ${LIBPD_INCLUDE_DIR}
    ${LIBPD_INCLUDE_DIR}/pd
)

target_link_libraries(_libpd PRIVATE
    "${LIBPD_LIB_DIR}/libpd.a"
)

# ============================================================================
# _audio module (miniaudio backend)
# ============================================================================

set(AUDIO_CYTHON_SOURCE "${CYPD_SRC_DIR}/_audio.pyx")
set(AUDIO_CYTHON_OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/_audio.c")

add_custom_command(
    OUTPUT ${AUDIO_CYTHON_OUTPUT}
    COMMAND Python::Interpreter -m cython
        -I "${CYPD_SRC_DIR}"
        "${AUDIO_CYTHON_SOURCE}"
        -o ${AUDIO_CYTHON_OUTPUT}
    DEPENDS
        ${AUDIO_CYTHON_SOURCE}
        "${CYPD_SRC_DIR}/libminiaudio.pxd"
        "${CYPD_SRC_DIR}/libpd.pxd"
        "${CYPD_SRC_DIR}/pd.pxd"
    COMMENT "Cython: _audio.pyx -> _audio.c"
)

# Compile miniaudio.c as a static library
add_library(miniaudio_static STATIC "${MINIAUDIO_ROOT}/miniaudio.c")
set_target_properties(miniaudio_static PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(miniaudio_static PUBLIC "${MINIAUDIO_ROOT}")

# Miniaudio needs certain defines and frameworks
if(APPLE)
    target_compile_definitions(miniaudio_static PRIVATE
        MA_NO_RUNTIME_LINKING
    )
    target_link_libraries(miniaudio_static PRIVATE
        "-framework CoreFoundation"
        "-framework CoreAudio"
        "-framework AudioToolbox"
    )
endif()

if(UNIX AND NOT APPLE)
    target_link_libraries(miniaudio_static PRIVATE
        pthread
        m
        dl
    )
endif()

# Build _audio extension
python_add_library(_audio MODULE ${AUDIO_CYTHON_OUTPUT} WITH_SOABI)

target_include_directories(_audio PRIVATE
    ${MINIAUDIO_ROOT}
    ${LIBPD_INCLUDE_DIR}
    ${LIBPD_INCLUDE_DIR}/pd
)

# Note: _audio does NOT link against libpd.a directly.
# Instead, it gets libpd_process_float function pointer from _libpd at runtime.
# This ensures both modules use the same libpd instance.
target_link_libraries(_audio PRIVATE
    miniaudio_static
)

# ============================================================================
# Platform-specific linking
# ============================================================================

if(APPLE)
    target_link_libraries(_libpd PRIVATE
        "-framework CoreAudio"
        "-framework CoreMIDI"
        "-framework CoreFoundation"
        "-framework CoreServices"
        "-framework AudioUnit"
        "-framework AudioToolbox"
    )
    target_link_libraries(_audio PRIVATE
        "-framework CoreAudio"
        "-framework CoreMIDI"
        "-framework CoreFoundation"
        "-framework CoreServices"
        "-framework AudioUnit"
        "-framework AudioToolbox"
    )
endif()

if(UNIX AND NOT APPLE)
    find_package(Threads REQUIRED)
    target_link_libraries(_libpd PRIVATE Threads::Threads m)
    target_link_libraries(_audio PRIVATE Threads::Threads m dl)
endif()

# ============================================================================
# Installation
# ============================================================================

install(TARGETS _libpd DESTINATION cypd)
install(TARGETS _audio DESTINATION cypd)
