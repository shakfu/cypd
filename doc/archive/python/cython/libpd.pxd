
cimport pd

cdef extern from "../../libpd_wrapper/z_libpd.h":

## initialization

    # initialize libpd it is safe to call this more than once
    # returns 0 on success or -1 if libpd was already initialized
    # note: sets SIGFPE handler to keep bad pd patches from crashing due to divide
    #       by 0, set any custom handling after calling this function
    int libpd_init()

    # clear the libpd search path for abstractions and externals
    # note: this is called by libpd_init()
    void libpd_clear_search_path()

    # add a path to the libpd search paths
    # relative paths are relative to the current working directory
    # unlike desktop pd, *no* search paths are set by default (ie. extra)
    void libpd_add_to_search_path(const char *path)

## opening patches

    # open a patch by filename and parent dir path
    # returns an opaque patch handle pointer or NULL on failure
    void *libpd_openfile(const char *name, const char *dir)

    # close a patch by patch handle pointer
    void libpd_closefile(void *p) nogil

    # get the $0 id of the patch handle pointer
    # returns $0 value or 0 if the patch is non-existent
    int libpd_getdollarzero(void *p)

## audio processing

    # return pd's fixed block size: the number of sample frames per 1 pd tick
    int libpd_blocksize()

    # initialize audio rendering
    # returns 0 on success
    int libpd_init_audio(int inChannels, int outChannels, int sampleRate)

    # process interleaved float samples from inBuffer -> libpd -> outBuffer
    # buffer sizes are based on # of ticks and channels where:
    #     size = ticks * libpd_blocksize() * (in/out)channels
    # returns 0 on success
    int libpd_process_float(const int ticks, const float *inBuffer, float *outBuffer) nogil

    # process interleaved short samples from inBuffer -> libpd -> outBuffer
    # buffer sizes are based on # of ticks and channels where:
    #     size = ticks * libpd_blocksize() * (in/out)channels
    # float samples are converted to short by multiplying by 32767 and casting,
    # so any values received from pd patches beyond -1 to 1 will result in garbage
    # note: for efficiency, does *not* clip input
    # returns 0 on success
    int libpd_process_short(const int ticks, const short *inBuffer, short *outBuffer) nogil

    # process interleaved double samples from inBuffer -> libpd -> outBuffer
    # buffer sizes are based on # of ticks and channels where:
    #     size = ticks * libpd_blocksize() * (in/out)channels
    # returns 0 on success
    int libpd_process_double(const int ticks, const double *inBuffer, double *outBuffer) nogil

    # process non-interleaved float samples from inBuffer -> libpd -> outBuffer
    # copies buffer contents to/from libpd without striping
    # buffer sizes are based on a single tick and # of channels where:
    #     size = libpd_blocksize() * (in/out)channels
    # returns 0 on success
    int libpd_process_raw(const float *inBuffer, float *outBuffer) nogil

    # process non-interleaved short samples from inBuffer -> libpd -> outBuffer
    # copies buffer contents to/from libpd without striping
    # buffer sizes are based on a single tick and # of channels where:
    #     size = libpd_blocksize() * (in/out)channels
    # float samples are converted to short by multiplying by 32767 and casting,
    # so any values received from pd patches beyond -1 to 1 will result in garbage
    # note: for efficiency, does *not* clip input
    # returns 0 on success
    int libpd_process_raw_short(const short *inBuffer, short *outBuffer) nogil

    # process non-interleaved double samples from inBuffer -> libpd -> outBuffer
    # copies buffer contents to/from libpd without striping
    # buffer sizes are based on a single tick and # of channels where:
    #     size = libpd_blocksize() * (in/out)channels
    # returns 0 on success
    int libpd_process_raw_double(const double *inBuffer, double *outBuffer) nogil


## array access

    # get the size of an array by name
    # returns size or negative error code if non-existent
    int libpd_arraysize(const char *name)

    # (re)size an array by name sizes <= 0 are clipped to 1
    # returns 0 on success or negative error code if non-existent
    int libpd_resize_array(const char *name, long size)

    # read n values from named src array and write into dest starting at an offset
    # note: performs no bounds checking on dest
    # returns 0 on success or a negative error code if the array is non-existent
    # or offset + n exceeds range of array
    int libpd_read_array(float *dest, const char *name, int offset, int n)

    # read n values from src and write into named dest array starting at an offset
    # note: performs no bounds checking on src
    # returns 0 on success or a negative error code if the array is non-existent
    # or offset + n exceeds range of array
    int libpd_write_array(const char *name, int offset, const float *src, int n)

    # read n values from named src array and write into dest starting at an offset
    # note: performs no bounds checking on dest
    # note: only full-precision when compiled with PD_FLOATSIZE=64
    # returns 0 on success or a negative error code if the array is non-existent
    # or offset + n exceeds range of array
    # double-precision variant of libpd_read_array()
    int libpd_read_array_double(double *dest, const char *src, int offset, int n)

    # read n values from src and write into named dest array starting at an offset
    # note: performs no bounds checking on src
    # note: only full-precision when compiled with PD_FLOATSIZE=64
    # returns 0 on success or a negative error code if the array is non-existent
    # or offset + n exceeds range of array
    # double-precision variant of libpd_write_array()
    int libpd_write_array_double(const char *dest, int offset, const double *src, int n)

## sending messages to pd

    # send a bang to a destination receiver
    # ex: libpd_bang("foo") will send a bang to [s foo] on the next tick
    # returns 0 on success or -1 if receiver name is non-existent
    int libpd_bang(const char *recv)

    # send a float to a destination receiver
    # ex: libpd_float("foo", 1) will send a 1.0 to [s foo] on the next tick
    # returns 0 on success or -1 if receiver name is non-existent
    int libpd_float(const char *recv, float x)
    
    # send a double to a destination receiver
    # ex: libpd_double("foo", 1.1) will send a 1.1 to [s foo] on the next tick
    # note: only full-precision when compiled with PD_FLOATSIZE=64
    # returns 0 on success or -1 if receiver name is non-existent
    int libpd_double(const char *recv, double x)

    # send a symbol to a destination receiver
    # ex: libpd_symbol("foo", "bar") will send "bar" to [s foo] on the next tick
    # returns 0 on success or -1 if receiver name is non-existent
    int libpd_symbol(const char *recv, const char *symbol)

## sending compound messages: sequenced function calls

    # start composition of a new list or typed message of up to max element length
    # messages can be of a smaller length as max length is only an upper bound
    # note: no cleanup is required for unfinished messages
    # returns 0 on success or nonzero if the length is too large
    int libpd_start_message(int maxlen)

    # add a float to the current message in progress
    void libpd_add_float(float x)

    # add a double to the current message in progress
    # note: only full-precision when compiled with PD_FLOATSIZE=64
    void libpd_add_double(double x)

    # add a symbol to the current message in progress
    void libpd_add_symbol(const char *symbol)

    # finish current message and send as a list to a destination receiver
    # returns 0 on success or -1 if receiver name is non-existent
    # ex: send [list 1 2 bar( to [s foo] on the next tick with:
    #     libpd_start_message(3)
    #     libpd_add_float(1)
    #     libpd_add_float(2)
    #     libpd_add_symbol("bar")
    #     libpd_finish_list("foo")
    int libpd_finish_list(const char *recv)

    # finish current message and send as a typed message to a destination receiver
    # note: typed message handling currently only supports up to 4 elements
    #       internally, additional elements may be ignored
    # returns 0 on success or -1 if receiver name is non-existent
    # ex: send [ pd dsp 1( on the next tick with:
    #     libpd_start_message(1)
    #     libpd_add_float(1)
    #     libpd_finish_message("pd", "dsp")
    int libpd_finish_message(const char *recv, const char *msg)


## sending compound messages: atom array

    # write a float value to the given atom
    void libpd_set_float(pd.t_atom *a, float x)

    # write a double value to the given atom
    # note: only full-precision when compiled with PD_FLOATSIZE=64
    void libpd_set_double(pd.t_atom *v, double x)

    # write a symbol value to the given atom
    void libpd_set_symbol(pd.t_atom *a, const char *symbol)

    # send an atom array of a given length as a list to a destination receiver
    # returns 0 on success or -1 if receiver name is non-existent
    # ex: send [list 1 2 bar( to [r foo] on the next tick with:
    #     pd.t_atom v[3]
    #     libpd_set_float(v, 1)
    #     libpd_set_float(v + 1, 2)
    #     libpd_set_symbol(v + 2, "bar")
    #     libpd_list("foo", 3, v)
    int libpd_list(const char *recv, int argc, pd.t_atom *argv)

    # send a atom array of a given length as a typed message to a destination
    # receiver, returns 0 on success or -1 if receiver name is non-existent
    # ex: send [ pd dsp 1( on the next tick with:
    #     pd.t_atom v[1]
    #     libpd_set_float(v, 1)
    #     libpd_message("pd", "dsp", 1, v)
    int libpd_message(const char *recv, const char *msg, int argc, pd.t_atom *argv)

## receiving messages from pd

    # subscribe to messages sent to a source receiver
    # ex: libpd_bind("foo") adds a "virtual" [r foo] which forwards messages to
    #     the libpd message hooks
    # returns an opaque receiver pointer or NULL on failure
    void *libpd_bind(const char *recv)

    # unsubscribe and free a source receiver object created by libpd_bind()
    void libpd_unbind(void *p)

    # check if a source receiver object exists with a given name
    # returns 1 if the receiver exists, otherwise 0
    int libpd_exists(const char *recv)

    # print receive hook signature, s is the string to be printed
    # note: default behavior returns individual words and spaces:
    #     line "hello 123" is received in 4 parts -> "hello", " ", "123\n"
    ctypedef void (*t_libpd_printhook)(const char *s)

    # bang receive hook signature, recv is the source receiver name
    ctypedef void (*t_libpd_banghook)(const char *recv)

    # float receive hook signature, recv is the source receiver name
    ctypedef void (*t_libpd_floathook)(const char *recv, float x)

    # double receive hook signature, recv is the source receiver name
    # note: only full-precision when compiled with PD_FLOATSIZE=64
    ctypedef void (*t_libpd_doublehook)(const char *recv, double x)

    # symbol receive hook signature, recv is the source receiver name
    ctypedef void (*t_libpd_symbolhook)(const char *recv, const char *symbol)

    # list receive hook signature, recv is the source receiver name
    # argc is the list length and vector argv contains the list elements
    # which can be accessed using the atom accessor functions, ex:
    #     int i
    #     for (i = 0 i < argc i++) {
    #       pd.t_atom *a = &argv[n]
    #       if (libpd_is_float(a)) {
    #         float x = libpd_get_float(a)
    #         // do something with float x
    #       } else if (libpd_is_symbol(a)) {
    #         char *s = libpd_get_symbol(a)
    #         // do something with c string s
    #       }
    #     }
    # note: check for both float and symbol types as atom may also be a pointer
    ctypedef void (*t_libpd_listhook)(const char *recv, int argc, pd.t_atom *argv)

    # typed message hook signature, recv is the source receiver name and msg is
    # the typed message name: a message like [ foo bar 1 2 a b( will trigger a
    # function call like libpd_messagehook("foo", "bar", 4, argv)
    # argc is the list length and vector argv contains the
    # list elements which can be accessed using the atom accessor functions, ex:
    #     int i
    #     for (i = 0 i < argc i++) {
    #       pd.t_atom *a = &argv[n]
    #       if (libpd_is_float(a)) {
    #         float x = libpd_get_float(a)
    #         // do something with float x
    #       } else if (libpd_is_symbol(a)) {
    #         char *s = libpd_get_symbol(a)
    #         // do something with c string s
    #       }
    #     }
    # note: check for both float and symbol types as atom may also be a pointer
    ctypedef void (*t_libpd_messagehook)(const char *recv, const char *msg,
        int argc, pd.t_atom *argv)

    # set the print receiver hook, prints to stdout by default
    # note: do not call this while DSP is running
    void libpd_set_printhook(const t_libpd_printhook hook)

    # set the bang receiver hook, NULL by default
    # note: do not call this while DSP is running
    void libpd_set_banghook(const t_libpd_banghook hook)

    # set the float receiver hook, NULL by default
    # note: do not call this while DSP is running
    void libpd_set_floathook(const t_libpd_floathook hook)

    # set the double receiver hook, NULL by default
    # note: avoid calling this while DSP is running
    # note: you can either have a double receiver hook, or a float receiver
    #       hook (see above), but not both.
    #       calling this, will automatically unset the float receiver hook
    # note: only full-precision when compiled with PD_FLOATSIZE=64
    void libpd_set_doublehook(const t_libpd_doublehook hook)

    # set the symbol receiver hook, NULL by default
    # note: do not call this while DSP is running
    void libpd_set_symbolhook(const t_libpd_symbolhook hook)

    # set the list receiver hook, NULL by default
    # note: do not call this while DSP is running
    void libpd_set_listhook(const t_libpd_listhook hook)

    # set the message receiver hook, NULL by default
    # note: do not call this while DSP is running
    void libpd_set_messagehook(const t_libpd_messagehook hook)

    # check if an atom is a float type: 0 or 1
    # note: no NULL check is performed
    int libpd_is_float(pd.t_atom *a)

    # check if an atom is a symbol type: 0 or 1
    # note: no NULL check is performed
    int libpd_is_symbol(pd.t_atom *a)

    # get the float value of an atom
    # note: no NULL or type checks are performed
    float libpd_get_float(pd.t_atom *a)

    # returns the double value of an atom
    # note: no NULL or type checks are performed
    # note: only full-precision when compiled with PD_FLOATSIZE=64
    double libpd_get_double(pd.t_atom *a)

    # note: no NULL or type checks are performed
    # get symbol value of an atom
    const char *libpd_get_symbol(pd.t_atom *a)

    # increment to the next atom in an atom vector
    # returns next atom or NULL, assuming the atom vector is NULL-terminated
    pd.t_atom *libpd_next_atom(pd.t_atom *a)

## sending MIDI messages to pd

    # send a MIDI note on message to [notein] objects
    # channel is 0-indexed, pitch is 0-127, and velocity is 0-127
    # channels encode MIDI ports via: libpd_channel = pd_channel + 16 * pd_port
    # note: there is no note off message, send a note on with velocity = 0 instead
    # returns 0 on success or -1 if an argument is out of range
    int libpd_noteon(int channel, int pitch, int velocity)

    # send a MIDI control change message to [ctlin] objects
    # channel is 0-indexed, controller is 0-127, and value is 0-127
    # channels encode MIDI ports via: libpd_channel = pd_channel + 16 * pd_port
    # returns 0 on success or -1 if an argument is out of range
    int libpd_controlchange(int channel, int controller, int value)

    # send a MIDI program change message to [pgmin] objects
    # channel is 0-indexed and value is 0-127
    # channels encode MIDI ports via: libpd_channel = pd_channel + 16 * pd_port
    # returns 0 on success or -1 if an argument is out of range
    int libpd_programchange(int channel, int value)

    # send a MIDI pitch bend message to [bendin] objects
    # channel is 0-indexed and value is -8192-8192
    # channels encode MIDI ports via: libpd_channel = pd_channel + 16 * pd_port
    # note: [bendin] outputs 0-16383 while [bendout] accepts -8192-8192
    # returns 0 on success or -1 if an argument is out of range
    int libpd_pitchbend(int channel, int value)

    # send a MIDI after touch message to [touchin] objects
    # channel is 0-indexed and value is 0-127
    # channels encode MIDI ports via: libpd_channel = pd_channel + 16 * pd_port
    # returns 0 on success or -1 if an argument is out of range
    int libpd_aftertouch(int channel, int value)

    # send a MIDI poly after touch message to [polytouchin] objects
    # channel is 0-indexed, pitch is 0-127, and value is 0-127
    # channels encode MIDI ports via: libpd_channel = pd_channel + 16 * pd_port
    # returns 0 on success or -1 if an argument is out of range
    int libpd_polyaftertouch(int channel, int pitch, int value)

    # send a raw MIDI byte to [midiin] objects
    # port is 0-indexed and byte is 0-256
    # returns 0 on success or -1 if an argument is out of range
    int libpd_midibyte(int port, int byte)

    # send a raw MIDI byte to [sysexin] objects
    # port is 0-indexed and byte is 0-256
    # returns 0 on success or -1 if an argument is out of range
    int libpd_sysex(int port, int byte)

    # send a raw MIDI byte to [realtimein] objects
    # port is 0-indexed and byte is 0-256
    # returns 0 on success or -1 if an argument is out of range
    int libpd_sysrealtime(int port, int byte)

## receiving MIDI messages from pd

    # MIDI note on receive hook signature
    # channel is 0-indexed, pitch is 0-127, and value is 0-127
    # channels encode MIDI ports via: libpd_channel = pd_channel + 16 * pd_port
    # note: there is no note off message, note on w/ velocity = 0 is used instead
    # note: out of range values from pd are clamped
    ctypedef void (*t_libpd_noteonhook)(int channel, int pitch, int velocity)

    # MIDI control change receive hook signature
    # channel is 0-indexed, controller is 0-127, and value is 0-127
    # channels encode MIDI ports via: libpd_channel = pd_channel + 16 * pd_port
    # note: out of range values from pd are clamped
    ctypedef void (*t_libpd_controlchangehook)(int channel, int controller, int value)

    # MIDI program change receive hook signature
    # channel is 0-indexed and value is 0-127
    # channels encode MIDI ports via: libpd_channel = pd_channel + 16 * pd_port
    # note: out of range values from pd are clamped
    ctypedef void (*t_libpd_programchangehook)(int channel, int value)

    # MIDI pitch bend receive hook signature
    # channel is 0-indexed and value is -8192-8192
    # channels encode MIDI ports via: libpd_channel = pd_channel + 16 * pd_port
    # note: [bendin] outputs 0-16383 while [bendout] accepts -8192-8192
    # note: out of range values from pd are clamped
    ctypedef void (*t_libpd_pitchbendhook)(int channel, int value)

    # MIDI after touch receive hook signature
    # channel is 0-indexed and value is 0-127
    # channels encode MIDI ports via: libpd_channel = pd_channel + 16 * pd_port
    # note: out of range values from pd are clamped
    ctypedef void (*t_libpd_aftertouchhook)(int channel, int value)

    # MIDI poly after touch receive hook signature
    # channel is 0-indexed, pitch is 0-127, and value is 0-127
    # channels encode MIDI ports via: libpd_channel = pd_channel + 16 * pd_port
    # note: out of range values from pd are clamped
    ctypedef void (*t_libpd_polyaftertouchhook)(int channel, int pitch, int value)

    # raw MIDI byte receive hook signature
    # port is 0-indexed and byte is 0-256
    # note: out of range values from pd are clamped
    ctypedef void (*t_libpd_midibytehook)(int port, int byte)

    # set the MIDI note on hook to receive from [noteout] objects, NULL by default
    # note: do not call this while DSP is running
    void libpd_set_noteonhook(const t_libpd_noteonhook hook)

    # set the MIDI control change hook to receive from [ctlout] objects,
    # NULL by default
    # note: do not call this while DSP is running
    void libpd_set_controlchangehook(const t_libpd_controlchangehook hook)

    # set the MIDI program change hook to receive from [pgmout] objects,
    # NULL by default
    # note: do not call this while DSP is running
    void libpd_set_programchangehook(const t_libpd_programchangehook hook)

    # set the MIDI pitch bend hook to receive from [bendout] objects,
    # NULL by default
    # note: do not call this while DSP is running
    void libpd_set_pitchbendhook(const t_libpd_pitchbendhook hook)

    # set the MIDI after touch hook to receive from [touchout] objects,
    # NULL by default
    # note: do not call this while DSP is running
    void libpd_set_aftertouchhook(const t_libpd_aftertouchhook hook)

    # set the MIDI poly after touch hook to receive from [polytouchout] objects,
    # NULL by default
    # note: do not call this while DSP is running
    void libpd_set_polyaftertouchhook(const t_libpd_polyaftertouchhook hook)

    # set the raw MIDI byte hook to receive from [midiout] objects,
    # NULL by default
    # note: do not call this while DSP is running
    void libpd_set_midibytehook(const t_libpd_midibytehook hook)

## GUI

    # open the current patches within a pd vanilla GUI
    # requires the path to pd's main folder that contains bin/, tcl/, etc
    # for a macOS .app bundle: /path/to/Pd-#.#-#.app/Contents/Resources
    # returns 0 on success
    int libpd_start_gui(char *path)

    # stop the pd vanilla GUI
    void libpd_stop_gui()

    # manually update and handle any GUI messages
    # this is called automatically when using a libpd_process function,
    # note: this also facilitates network message processing, etc so it can be
    #       useful to call repeatedly when idle for more throughput
    void libpd_poll_gui()

## multiple instances

    # create a new pd instance
    # returns new instance or NULL when libpd is not compiled with PDINSTANCE
    pd.t_pdinstance *libpd_new_instance()

    # set the current pd instance
    # subsequent libpd calls will affect this instance only
    # does nothing when libpd is not compiled with PDINSTANCE
    void libpd_set_instance(pd.t_pdinstance *p)

    # free a pd instance
    # does nothing when libpd is not compiled with PDINSTANCE
    void libpd_free_instance(pd.t_pdinstance *p)

    # get the current pd instance
    pd.t_pdinstance *libpd_this_instance()

    # get a pd instance by index
    # returns NULL if index is out of bounds or "this" instance when libpd is not
    # compiled with PDINSTANCE
    pd.t_pdinstance *libpd_get_instance(int index)

    # get the number of pd instances
    # returns number or 1 when libpd is not compiled with PDINSTANCE
    int libpd_num_instances()

## log level

    # set verbose print state: 0 or 1
    void libpd_set_verbose(int verbose)

    # get the verbose print state: 0 or 1
    int libpd_get_verbose()


cdef extern from "../../libpd_wrapper/util/z_queued.h":

    # set the queued print receiver hook, NULL by default
    # note: do not call this while DSP is running
    cdef void libpd_set_queued_printhook(const t_libpd_printhook hook)

    # set the queued bang receiver hook, NULL by default
    # note: do not call this while DSP is running
    cdef void libpd_set_queued_banghook(const t_libpd_banghook hook)

    # set the queued float receiver hook, NULL by default
    # note: avoid calling this while DSP is running
    # note: you can either have a queued float receiver hook, or a queued
    #       double receiver hook (see below), but not both.
    #       calling this, will automatically unset the queued double receiver
    #       hook
    cdef void libpd_set_queued_floathook(const t_libpd_floathook hook)

    # set the queued double receiver hook, NULL by default
    # note: avoid calling this while DSP is running
    # note: you can either have a queued double receiver hook, or a queued
    #       float receiver hook (see above), but not both.
    #       calling this, will automatically unset the queued float receiver
    #       hook
    cdef void libpd_set_queued_doublehook(const t_libpd_doublehook hook)

    # set the queued symbol receiver hook, NULL by default
    # note: do not call this while DSP is running
    cdef void libpd_set_queued_symbolhook(const t_libpd_symbolhook hook)

    # set the queued list receiver hook, NULL by default
    # note: do not call this while DSP is running
    cdef void libpd_set_queued_listhook(const t_libpd_listhook hook)

    # set the queued typed message receiver hook, NULL by default
    # note: do not call this while DSP is running
    cdef void libpd_set_queued_messagehook(const t_libpd_messagehook hook)

    # set the queued MIDI note on hook, NULL by default
    # note: do not call this while DSP is running
    cdef void libpd_set_queued_noteonhook(const t_libpd_noteonhook hook)

    # set the queued MIDI control change hook, NULL by default
    # note: do not call this while DSP is running
    cdef void libpd_set_queued_controlchangehook(const t_libpd_controlchangehook hook)

    # set the queued MIDI program change hook, NULL by default
    # note: do not call this while DSP is running
    cdef void libpd_set_queued_programchangehook(const t_libpd_programchangehook hook)

    # set the queued MIDI pitch bend hook, NULL by default
    # note: do not call this while DSP is running
    cdef void libpd_set_queued_pitchbendhook(const t_libpd_pitchbendhook hook)

    # set the queued MIDI after touch hook, NULL by default
    # note: do not call this while DSP is running
    cdef void libpd_set_queued_aftertouchhook(const t_libpd_aftertouchhook hook)

    # set the queued MIDI poly after touch hook, NULL by default
    # note: do not call this while DSP is running
    cdef void libpd_set_queued_polyaftertouchhook(const t_libpd_polyaftertouchhook hook)

    # set the queued raw MIDI byte hook, NULL by default
    # note: do not call this while DSP is running
    cdef void libpd_set_queued_midibytehook(const t_libpd_midibytehook hook)

    # initialize libpd and the queued ringbuffers, use in place of libpd_init()
    # this is safe to call more than once
    # returns 0 on success, -1 if libpd was already initialized, or -2 if ring
    # buffer allocation failed
    cdef int libpd_queued_init()

    # free the queued ringbuffers
    cdef void libpd_queued_release()

    # process and dispatch received messages in message ringbuffer
    cdef void libpd_queued_receive_pd_messages()

    # process and dispatch receive midi messages in MIDI message ringbuffer
    cdef void libpd_queued_receive_midi_messages()


cdef extern from "../../libpd_wrapper/util/z_print_util.h":

    # concatenate print messages into single lines before returning them to the
    # print hook:
    #    ie. line "hello 123\n" is received in 1 part -> "hello 123"
    # for comparison, the default behavior receives individual words and spaces:
    #
    # ie. line "hello 123" is sent in 3 parts -> "hello", " ", "123\n"

    # assign the pointer to your print handler
    cdef void libpd_set_concatenated_printhook(const t_libpd_printhook hook)

    # assign this function pointer to libpd_printhook or libpd_queued_printhook,
    # depending on whether you're using queued messages, to intercept and
    # concatenate print messages:
    #     libpd_set_printhook(libpd_print_concatenator);
    #     or
    #     libpd_set_concatenated_printhook(your_print_handler);
    # note: the char pointer argument is only good for the duration of the print
    #       callback; if you intend to use the argument after the callback has
    #       returned, you need to make a defensive copy
    cdef void libpd_print_concatenator(const char *s)
