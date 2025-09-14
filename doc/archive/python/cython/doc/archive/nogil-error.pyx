# This doesn't work in a gilless a nogil


cdef int cplay(char* name, char* dir, int sample_rate, int blocksize,
               int in_channels, int out_channels) nogil:

    cdef libportaudio.PaStream *stream # opens the audio stream
    cdef libportaudio.PaError err


    #fprintf("portaudio version: ", libportaudio.Pa_GetVersion())

    # set callbacks
    # libpd.libpd_set_printhook(pd_cprint)
    handle = libpd.libpd_openfile(name, dir)
    # init
    libpd.libpd_init()
    libpd.libpd_init_audio(in_channels, out_channels, sample_rate)


    ##---------------------------------------------------------------
    ## APP-SPECIFIC START 

    # open patch
    handle = libpd.libpd_openfile(name, dir)

    ## APP-SPECIFIC END         
    ##---------------------------------------------------------------

    # Initialize our data for use by callback.
    for i in range(blocksize):
        data.outbuf[i] = 0
    
    # Initialize library before making any other calls.
    err = libportaudio.Pa_Initialize()
    if err != libportaudio.paNoError:
        libportaudio.Pa_Terminate()
        fprintf(stderr, "An error occured while using the portaudio stream\n")
        fprintf(stderr, "Error number: %d\n", err)
        fprintf(stderr, "Error message: %s\n", libportaudio.Pa_GetErrorText(err))
        libpd.libpd_closefile(handle)

    # Open an audio I/O stream.
    err = libportaudio.Pa_OpenDefaultStream(
        &stream,
        in_channels,        # input channels
        out_channels,       # output channels
        libportaudio.paFloat32,  # 32 bit floating point output
        sample_rate,
        <long>blocksize,    # frames per buffer
        audio_callback,
        &data)
    if (err != libportaudio.paNoError):
        libportaudio.Pa_Terminate()
        fprintf(stderr, "An error occured while using the portaudio stream\n")
        fprintf(stderr, "Error number: %d\n", err)
        fprintf(stderr, "Error message: %s\n", libportaudio.Pa_GetErrorText(err))
        libpd.libpd_closefile(handle)


    err = libportaudio.Pa_StartStream(stream)
    if (err != libportaudio.paNoError):
        libportaudio.Pa_Terminate()
        fprintf(stderr, "An error occured while using the portaudio stream\n")
        fprintf(stderr, "Error number: %d\n", err)
        fprintf(stderr, "Error message: %s\n", libportaudio.Pa_GetErrorText(err))
        libpd.libpd_closefile(handle)


    libportaudio.Pa_Sleep(PRERUN_SLEEP)

    # -----------------------------------------------------------------
    # RUN HERE

    # start
    libpd.libpd_start_message(1)
    libpd.libpd_add_float(1)
    libpd.libpd_finish_message("pd", "dsp")

    # CONTROL HERE!!!
    sleep(4)

    # stop
    libpd.libpd_start_message(1)
    libpd.libpd_add_float(0)
    libpd.libpd_finish_message("pd", "dsp")

    # -----------------------------------------------------------------

    err = libportaudio.Pa_StopStream(stream)
    if err != libportaudio.paNoError:
        libportaudio.Pa_Terminate()
        fprintf(stderr, "An error occured while using the portaudio stream\n")
        fprintf(stderr, "Error number: %d\n", err)
        fprintf(stderr, "Error message: %s\n", libportaudio.Pa_GetErrorText(err))
        libpd.libpd_closefile(handle)

    err = libportaudio.Pa_CloseStream(stream)
    if err != libportaudio.paNoError:
        libportaudio.Pa_Terminate()
        fprintf(stderr, "An error occured while using the portaudio stream\n")
        fprintf(stderr, "Error number: %d\n", err)
        fprintf(stderr, "Error message: %s\n", libportaudio.Pa_GetErrorText(err))
        libpd.libpd_closefile(handle)

    libportaudio.Pa_Terminate()
    # fprintf("Ending Patch session: %i", err)

    libpd.libpd_closefile(handle)

    return err
