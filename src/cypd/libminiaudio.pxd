# libminiaudio.pxd - Cython declarations for miniaudio
# Minimal subset needed for audio playback with libpd

cdef extern from "miniaudio.h" nogil:

    # Basic types
    ctypedef unsigned int ma_uint32
    ctypedef unsigned char ma_uint8
    ctypedef int ma_int32
    ctypedef char ma_bool8
    ctypedef char ma_bool32

    # Result type
    ctypedef int ma_result
    cdef ma_result MA_SUCCESS

    # Device types
    ctypedef enum ma_device_type:
        ma_device_type_playback
        ma_device_type_capture
        ma_device_type_duplex
        ma_device_type_loopback

    # Sample formats
    ctypedef enum ma_format:
        ma_format_unknown
        ma_format_u8
        ma_format_s16
        ma_format_s24
        ma_format_s32
        ma_format_f32

    # Performance profile
    ctypedef enum ma_performance_profile:
        ma_performance_profile_low_latency
        ma_performance_profile_conservative

    # Forward declarations
    ctypedef struct ma_device
    ctypedef struct ma_context
    ctypedef struct ma_device_info

    # Callback types
    ctypedef void (*ma_device_data_proc)(ma_device* pDevice, void* pOutput,
                                          const void* pInput, ma_uint32 frameCount)
    ctypedef void (*ma_device_notification_proc)(const void* pNotification)
    ctypedef void (*ma_stop_proc)(ma_device* pDevice)

    # Device ID
    ctypedef union ma_device_id:
        pass  # Opaque

    # Device configuration
    ctypedef struct ma_device_config:
        ma_device_type deviceType
        ma_uint32 sampleRate
        ma_uint32 periodSizeInFrames
        ma_uint32 periodSizeInMilliseconds
        ma_uint32 periods
        ma_performance_profile performanceProfile
        ma_bool8 noPreSilencedOutputBuffer
        ma_bool8 noClip
        ma_bool8 noDisableDenormals
        ma_bool8 noFixedSizedCallback
        ma_device_data_proc dataCallback
        ma_device_notification_proc notificationCallback
        ma_stop_proc stopCallback
        void* pUserData
        # Playback config (nested struct simplified)
        # We'll access these through helper functions

    # Device structure - we need pUserData for our callback
    ctypedef struct ma_device:
        void* pUserData

    # Context structure (opaque)
    ctypedef struct ma_context:
        pass

    # Device info
    ctypedef struct ma_device_info:
        char name[256]
        ma_bool32 isDefault

    # =========================================================================
    # Functions
    # =========================================================================

    # Version
    const char* ma_version_string()

    # Device config initialization
    ma_device_config ma_device_config_init(ma_device_type deviceType)

    # Device lifecycle
    ma_result ma_device_init(ma_context* pContext, const ma_device_config* pConfig,
                              ma_device* pDevice)
    void ma_device_uninit(ma_device* pDevice)
    ma_result ma_device_start(ma_device* pDevice)
    ma_result ma_device_stop(ma_device* pDevice)
    ma_bool32 ma_device_is_started(const ma_device* pDevice)

    # Device state
    ma_uint32 ma_device_get_state(const ma_device* pDevice)

    # Context (for device enumeration)
    ma_result ma_context_init(const void* pBackends, ma_uint32 backendCount,
                               const void* pConfig, ma_context* pContext)
    ma_result ma_context_uninit(ma_context* pContext)
    ma_result ma_context_enumerate_devices(ma_context* pContext,
                                            void* callback, void* pUserData)
    ma_result ma_context_get_devices(ma_context* pContext,
                                      ma_device_info** ppPlaybackDeviceInfos,
                                      ma_uint32* pPlaybackDeviceCount,
                                      ma_device_info** ppCaptureDeviceInfos,
                                      ma_uint32* pCaptureDeviceCount)



# Helper to set playback format in device config
# miniaudio uses nested structs which Cython doesn't handle well directly
cdef extern from *:
    """
    static void ma_device_config_set_playback(ma_device_config* config,
                                               ma_format format,
                                               ma_uint32 channels) {
        config->playback.format = format;
        config->playback.channels = channels;
    }

    static void ma_device_config_set_capture(ma_device_config* config,
                                              ma_format format,
                                              ma_uint32 channels) {
        config->capture.format = format;
        config->capture.channels = channels;
    }
    """
    void ma_device_config_set_playback(ma_device_config* config,
                                        ma_format format,
                                        ma_uint32 channels) nogil
    void ma_device_config_set_capture(ma_device_config* config,
                                       ma_format format,
                                       ma_uint32 channels) nogil
