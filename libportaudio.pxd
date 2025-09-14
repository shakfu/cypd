## ----------------------------------------------------------
## Portaudio

cdef extern from "portaudio.h" nogil:
    int Pa_GetVersion()

    ctypedef unsigned long PaStreamCallbackFlags
    
    cdef struct PaStreamCallbackTimeInfo
    
    #ctypedef PaStreamCallbackTimeInfo PaStreamCallbackTimeInfo
    
    ctypedef void PaStream
    
    ctypedef int PaError
    
    PaError Pa_Initialize()
    
    PaError Pa_Terminate()
    
    ctypedef enum PaErrorCode:
        paNoError = 0
    
    cdef const char *Pa_GetErrorText(PaError errorCode)
    
    ctypedef unsigned long PaSampleFormat
    
    ctypedef int PaStreamCallback(
        const void *input, 
        void *output,
        unsigned long frameCount,
        const PaStreamCallbackTimeInfo* timeInfo,
        PaStreamCallbackFlags statusFlags,
        void *userData)
    
    cdef PaSampleFormat paFloat32 = 0x00000001
    
    cdef PaError Pa_OpenDefaultStream( 
        PaStream** stream,
        int numInputChannels,
        int numOutputChannels,
        PaSampleFormat sampleFormat,
        double sampleRate,
        unsigned long framesPerBuffer,
        PaStreamCallback *streamCallback,
        void *userData)
    
    # Commences audio processing.
    cdef PaError Pa_StartStream(PaStream *stream)

    # Terminates audio processing. It waits until all pending
    # audio buffers have been played before it returns.
    cdef PaError Pa_StopStream(PaStream *stream)

    # Terminates audio processing immediately without waiting for pending
    # buffers to complete.
    cdef PaError Pa_AbortStream(PaStream *stream)

    # Closes an audio stream. If the audio stream is active it
    # discards any pending buffers as if Pa_AbortStream() had been called.

    cdef PaError Pa_CloseStream( PaStream *stream )


    # Put the caller to sleep for at least 'msec' milliseconds. This function is
    # provided only as a convenience for authors of portable code (such as the tests
    # and examples in the PortAudio distribution.)

    # The function may sleep longer than requested so don't rely on this for accurate
    # musical timing.
    cdef void Pa_Sleep(long msec)
