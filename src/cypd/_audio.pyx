# distutils: language = c
"""_audio.pyx - Miniaudio backend for cypd

This module provides audio I/O using miniaudio, integrated with libpd.

IMPORTANT: This module uses _libpd's libpd instance via function pointer,
rather than linking its own copy of libpd.a. This ensures both modules
share the same libpd state.
"""
cimport libminiaudio as ma

from libc.stdlib cimport malloc, free
from libc.string cimport memset, memcpy
from libc.stdint cimport uintptr_t

# Function pointer type for libpd_process_float
ctypedef int (*process_float_func)(int ticks, const float *inBuffer, float *outBuffer) noexcept nogil

# Global function pointer - set at module init from _libpd
cdef process_float_func g_process_float = NULL

# ----------------------------------------------------------------------------
# Constants

DEF DEFAULT_SAMPLE_RATE = 44100
DEF DEFAULT_CHANNELS_IN = 1
DEF DEFAULT_CHANNELS_OUT = 2
DEF DEFAULT_BLOCK_SIZE = 64  # pd's block size
DEF MAX_TICKS = 32  # Maximum ticks per callback (32 * 64 = 2048 frames)

# ----------------------------------------------------------------------------
# Audio engine state

ctypedef struct AudioState:
    int sample_rate
    int channels_in
    int channels_out
    int block_size
    int buffer_frames  # Total frames our buffers can hold
    bint is_running
    bint is_initialized
    # Buffers for libpd
    float* in_buffer
    float* out_buffer

cdef AudioState g_audio_state

# ----------------------------------------------------------------------------
# Audio callback - called by miniaudio from audio thread

cdef void audio_callback(ma.ma_device* pDevice, void* pOutput,
                         const void* pInput, ma.ma_uint32 frameCount) noexcept nogil:
    """Audio callback called by miniaudio.

    Processes audio through libpd and writes to output buffer.
    """
    cdef AudioState* state = <AudioState*>pDevice.pUserData
    cdef float* out = <float*>pOutput
    cdef const float* inp = <const float*>pInput
    cdef int ticks
    cdef int frames_to_process
    cdef int frames_remaining
    cdef int frames_processed
    cdef int in_offset, out_offset
    cdef int in_frame_size, out_frame_size
    cdef int total_frames = <int>frameCount

    # Safety checks
    if state == NULL:
        # Can't do much without state - just zero the output
        # Use a reasonable default for stereo
        memset(pOutput, 0, frameCount * 2 * sizeof(float))
        return

    if not state.is_running or not state.is_initialized:
        # Fill with silence if not running
        memset(pOutput, 0, frameCount * state.channels_out * sizeof(float))
        return

    if state.in_buffer == NULL or state.out_buffer == NULL:
        memset(pOutput, 0, frameCount * state.channels_out * sizeof(float))
        return

    if state.block_size <= 0:
        memset(pOutput, 0, frameCount * state.channels_out * sizeof(float))
        return

    # Frame sizes in floats
    in_frame_size = state.channels_in
    out_frame_size = state.channels_out

    # Process audio in chunks that are multiples of block_size
    frames_processed = 0
    while frames_processed < total_frames:
        frames_remaining = total_frames - frames_processed

        # Calculate how many complete ticks we can process
        ticks = frames_remaining // state.block_size
        if ticks < 1:
            # Not enough frames for a full tick - output silence for remainder
            break

        # Limit to our buffer capacity
        if ticks > MAX_TICKS:
            ticks = MAX_TICKS

        frames_to_process = ticks * state.block_size

        # Buffer offsets
        in_offset = frames_processed * in_frame_size
        out_offset = frames_processed * out_frame_size

        # Copy input to libpd input buffer (or zero if no input)
        if pInput != NULL:
            memcpy(state.in_buffer, (<const float*>pInput) + in_offset,
                   frames_to_process * in_frame_size * sizeof(float))
        else:
            memset(state.in_buffer, 0,
                   frames_to_process * in_frame_size * sizeof(float))

        # Process through libpd (via function pointer from _libpd module)
        if g_process_float != NULL:
            g_process_float(ticks, state.in_buffer, state.out_buffer)

        # Copy libpd output to miniaudio output
        memcpy((<float*>pOutput) + out_offset, state.out_buffer,
               frames_to_process * out_frame_size * sizeof(float))

        frames_processed = frames_processed + frames_to_process

    # Zero any remaining frames that couldn't form a complete tick
    if frames_processed < total_frames:
        out_offset = frames_processed * out_frame_size
        memset((<float*>pOutput) + out_offset, 0,
               (total_frames - frames_processed) * out_frame_size * sizeof(float))


# ----------------------------------------------------------------------------
# Audio device management

cdef ma.ma_device g_device
cdef bint g_device_initialized = False

def get_version() -> str:
    """Get miniaudio version string."""
    cdef const char* version = ma.ma_version_string()
    return version.decode('utf-8')


def init_audio(int sample_rate=DEFAULT_SAMPLE_RATE,
               int channels_in=DEFAULT_CHANNELS_IN,
               int channels_out=DEFAULT_CHANNELS_OUT,
               int block_size=DEFAULT_BLOCK_SIZE) -> bool:
    """Initialize the audio subsystem.

    Args:
        sample_rate: Audio sample rate (default 44100)
        channels_in: Number of input channels (default 1)
        channels_out: Number of output channels (default 2)
        block_size: Audio block size, should match pd's blocksize (default 64)

    Returns:
        True on success, False on failure.
    """
    global g_device, g_device_initialized, g_audio_state

    cdef ma.ma_device_config config
    cdef ma.ma_result result
    cdef int buffer_frames

    if g_device_initialized:
        return True  # Already initialized

    # Calculate buffer size - enough for MAX_TICKS worth of processing
    buffer_frames = MAX_TICKS * block_size

    # Initialize audio state
    g_audio_state.sample_rate = sample_rate
    g_audio_state.channels_in = channels_in
    g_audio_state.channels_out = channels_out
    g_audio_state.block_size = block_size
    g_audio_state.buffer_frames = buffer_frames
    g_audio_state.is_running = False
    g_audio_state.is_initialized = False
    g_audio_state.in_buffer = NULL
    g_audio_state.out_buffer = NULL

    # Allocate input buffer
    g_audio_state.in_buffer = <float*>malloc(buffer_frames * channels_in * sizeof(float))
    if g_audio_state.in_buffer == NULL:
        return False
    memset(g_audio_state.in_buffer, 0, buffer_frames * channels_in * sizeof(float))

    # Allocate output buffer
    g_audio_state.out_buffer = <float*>malloc(buffer_frames * channels_out * sizeof(float))
    if g_audio_state.out_buffer == NULL:
        free(g_audio_state.in_buffer)
        g_audio_state.in_buffer = NULL
        return False
    memset(g_audio_state.out_buffer, 0, buffer_frames * channels_out * sizeof(float))

    # Configure miniaudio device
    config = ma.ma_device_config_init(ma.ma_device_type_playback)
    config.sampleRate = sample_rate
    config.periodSizeInFrames = block_size
    config.dataCallback = audio_callback
    config.pUserData = &g_audio_state

    # Set playback format
    ma.ma_device_config_set_playback(&config, ma.ma_format_f32, channels_out)

    # Initialize device
    result = ma.ma_device_init(NULL, &config, &g_device)
    if result != ma.MA_SUCCESS:
        free(g_audio_state.in_buffer)
        free(g_audio_state.out_buffer)
        g_audio_state.in_buffer = NULL
        g_audio_state.out_buffer = NULL
        return False

    g_audio_state.is_initialized = True
    g_device_initialized = True
    return True


def start() -> bool:
    """Start audio playback.

    Returns:
        True on success, False on failure.
    """
    global g_device, g_device_initialized, g_audio_state

    if not g_device_initialized:
        return False

    cdef ma.ma_result result = ma.ma_device_start(&g_device)
    if result != ma.MA_SUCCESS:
        return False

    g_audio_state.is_running = True
    return True


def stop() -> bool:
    """Stop audio playback.

    Returns:
        True on success, False on failure.
    """
    global g_device, g_device_initialized, g_audio_state

    if not g_device_initialized:
        return False

    g_audio_state.is_running = False

    cdef ma.ma_result result = ma.ma_device_stop(&g_device)
    return result == ma.MA_SUCCESS


def is_running() -> bool:
    """Check if audio is currently running."""
    global g_device, g_device_initialized

    if not g_device_initialized:
        return False

    return ma.ma_device_is_started(&g_device) != 0


def terminate():
    """Shut down the audio subsystem and release resources."""
    global g_device, g_device_initialized, g_audio_state

    # Stop first
    g_audio_state.is_running = False

    if g_device_initialized:
        ma.ma_device_uninit(&g_device)
        g_device_initialized = False

    g_audio_state.is_initialized = False

    if g_audio_state.in_buffer != NULL:
        free(g_audio_state.in_buffer)
        g_audio_state.in_buffer = NULL

    if g_audio_state.out_buffer != NULL:
        free(g_audio_state.out_buffer)
        g_audio_state.out_buffer = NULL


def sleep(int milliseconds):
    """Sleep for the specified number of milliseconds.

    Uses Python's time.sleep for cross-platform compatibility.
    """
    import time
    time.sleep(milliseconds / 1000.0)


# ----------------------------------------------------------------------------
# High-level convenience function

def play(patch_name: str, patch_dir: str = ".", duration_ms: int = 4000,
         sample_rate: int = DEFAULT_SAMPLE_RATE,
         channels_in: int = DEFAULT_CHANNELS_IN,
         channels_out: int = DEFAULT_CHANNELS_OUT) -> bool:
    """Play a pd patch for a specified duration.

    This is a convenience function that:
    1. Initializes libpd and audio
    2. Opens the patch
    3. Turns on DSP
    4. Plays for the specified duration
    5. Cleans up

    Args:
        patch_name: Name of the patch file (e.g., "test.pd")
        patch_dir: Directory containing the patch (default ".")
        duration_ms: Duration to play in milliseconds (default 4000)
        sample_rate: Audio sample rate (default 44100)
        channels_in: Number of input channels (default 1)
        channels_out: Number of output channels (default 2)

    Returns:
        True on success, False on failure.
    """
    # Import cypd functions at runtime to avoid circular imports
    import cypd

    # Initialize libpd
    cypd.init()
    cypd.init_audio(channels_in, channels_out, sample_rate)

    # Initialize miniaudio
    if not init_audio(sample_rate, channels_in, channels_out):
        return False

    try:
        # Open patch
        patch_id = cypd.open_patch(patch_name, patch_dir)

        # Start audio
        if not start():
            cypd.close_patch(patch_id)
            return False

        # Turn on DSP
        cypd.dsp(True)

        # Play for duration
        sleep(duration_ms)

        # Turn off DSP
        cypd.dsp(False)

        # Stop audio
        stop()

        # Close patch
        cypd.close_patch(patch_id)

        return True

    finally:
        terminate()


# ----------------------------------------------------------------------------
# Module initialization and cleanup

import atexit

def _init_libpd_link():
    """Initialize the link to _libpd's libpd instance.

    This gets the function pointer to libpd_process_float from the _libpd
    module, ensuring we use the same libpd instance rather than a separate
    copy from static linking.
    """
    global g_process_float
    from cypd._libpd import _get_process_float_ptr
    cdef uintptr_t ptr = _get_process_float_ptr()
    g_process_float = <process_float_func>ptr

def _cleanup():
    """Clean up audio resources on module unload."""
    terminate()

# Initialize link to _libpd on module load
_init_libpd_link()
atexit.register(_cleanup)
