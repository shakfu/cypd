cimport pd
cimport libpd
cimport libportaudio

from cpython cimport array
from libc.stdlib cimport malloc, free
from libc.string cimport strcpy, strlen
from libc.stdio cimport printf, fprintf, stderr, FILE
from libc.stdint cimport uintptr_t
from posix.unistd cimport sleep

import array

# ----------------------------------------------------------------------------
# constants

DEF N_TICKS = 1
DEF SAMPLE_RATE = 44100
DEF CHANNELS_IN = 1
DEF CHANNELS_OUT = 2
DEF BLOCKSIZE = 64
DEF PRERUN_SLEEP = 2000
DEF MAX_ATOMS = 1024

# ----------------------------------------------------------------------------
# globals

cdef struct UserAudioData:
    # one input channel, two output channels
    double inbuf[N_TICKS * BLOCKSIZE * CHANNELS_IN]
    # block size 64, one tick per buffer
    double outbuf[N_TICKS * BLOCKSIZE * CHANNELS_OUT]
    # stereo outputs are interlaced, s[0] = RIGHT, s[1] = LEFT, etc..

cdef UserAudioData data


# ----------------------------------------------------------------------------
# pure python callbacks

def pd_print(str s):
    print("p>>", tuple([s]))

def pd_bang(str recv):
    print(f"b>> BANG {recv}")

def pd_float(str recv, float f):
    print(f"f>> float {f} {recv}")

def pd_symbol(str recv, str sym):
    print(f"s>> symbol {sym} {recv}")

def pd_list(*args):
    print(f"l>> list {args}")

def pd_message(*args):
    print(f"m>> msg {args}")

def pd_noteon(int channel, int pitch, int velocity):
    print(f"n>> noteon chan: {channel} pitch: {pitch} vel: {velocity}")

def init_hooks():
    """initialize all default hooks"""
    set_print_callback(pd_print)
    set_bang_callback(pd_bang)
    set_float_callback(pd_float)
    set_symbol_callback(pd_symbol)
    set_message_callback(pd_message)
    set_list_callback(pd_list)

# ----------------------------------------------------------------------------
# message and midi callback slots
# 
# note: these are set via a functional interface and not directly

__CALLBACKS = dict(
    # callbacks
    print_callback = None,
    bang_callback = None,
    float_callback = None,
    double_callback = None,
    symbol_callback = None,
    list_callback = None,
    message_callback = None,

    # midi callbacks
    noteon_callback = None,
    controlchange_callback = None,
    programchange_callback = None,
    pitchbend_callback = None,
    aftertouch_callback = None,
    polyaftertouch_callback = None,
    midibyte_callback = None,
)

__LIBPD_PATCHES = {}

__LIBPD_SUBSCRIPTIONS = {}

# ----------------------------------------------------------------------------
# callback hooks

# messaging
cdef void print_callback_hook(const char *s):
    if __CALLBACKS['print_callback']:
        __CALLBACKS['print_callback'](s.decode())

cdef void bang_callback_hook(const char *recv):
    if __CALLBACKS['bang_callback']:
        __CALLBACKS['bang_callback'](recv.decode())

cdef void float_callback_hook(const char *recv, float f):
    if __CALLBACKS['float_callback']:
        __CALLBACKS['float_callback'](recv.decode(), f)

cdef void double_callback_hook(const char *recv, double d):
    if __CALLBACKS['double_callback']:
        __CALLBACKS['double_callback'](recv.decode(), d)

cdef void symbol_callback_hook(const char *recv, const char *symbol):
    if __CALLBACKS['symbol_callback']:
        __CALLBACKS['symbol_callback'](recv.decode(), symbol.decode())

cdef void list_callback_hook(const char *recv, int argc, pd.t_atom *argv):
    cdef object args = None
    if __CALLBACKS['list_callback']:
        args = convert_args(recv, NULL, argc, argv)
        __CALLBACKS['list_callback'](*args)

cdef void message_callback_hook(const char *recv, const char *symbol, int argc, pd.t_atom *argv):
    cdef object args = None
    if __CALLBACKS['message_callback']:
        args = convert_args(recv, symbol, argc, argv)
        __CALLBACKS['message_callback'](*args)


# midi
cdef void noteon_callback_hook(int channel, int pitch, int velocity):
    if __CALLBACKS['noteon_callback']:
        __CALLBACKS['noteon_callback'](channel, pitch, velocity)

cdef void controlchange_callback_hook(int channel, int controller, int value):
    if __CALLBACKS['controlchange_callback']:
        __CALLBACKS['controlchange_callback'](channel, controller, value)

cdef void programchange_callback_hook(int channel, int value):
    if __CALLBACKS['programchange_callback']:
        __CALLBACKS['programchange_callback'](channel, value)

cdef void pitchbend_callback_hook(int channel, int value):
    if __CALLBACKS['pitchbend_callback']:
        __CALLBACKS['pitchbend_callback'](channel, value)

cdef void aftertouch_callback_hook(int channel, int value):
    if __CALLBACKS['aftertouch_callback']:
        __CALLBACKS['aftertouch_callback'](channel, value)

cdef void polyaftertouch_callback_hook(int channel, int pitch, int value):
    if __CALLBACKS['polyaftertouch_callback']:
        __CALLBACKS['polyaftertouch_callback'](channel, pitch, value)

cdef void midibyte_callback_hook(int port, int byte):
    if __CALLBACKS['midibyte_callback']:
        __CALLBACKS['midibyte_callback'](port, byte)



# ----------------------------------------------------------------------------
# helper functions

cdef convert_args(const char *recv, const char *symbol, int argc, pd.t_atom *argv):
    
    cdef list result = []
    cdef pd.t_atom* a
    cdef object pval = None

    result.append(recv.decode())
    if symbol:
        result.append(symbol.decode())

    if argc > 0:
        for i in range(argc):
            a = &argv[<int>i]
            if is_float(a):
                pval = <float>get_float(a)
            elif is_symbol(a):
                pval = get_symbol(a).decode()
            result.append(pval)
    return tuple(result)

def process_args(args):
    if libpd.libpd_start_message(len(args)):
        return -2
    for arg in args:
        if isinstance(arg, str):
            libpd.libpd_add_symbol(arg.encode('utf-8'))
        else:
            if isinstance(arg, int) or isinstance(arg, float):
                libpd.libpd_add_float(arg)
            else:
                return -1
    return 0


# ----------------------------------------------------------------------------
# functions

cdef int audio_callback(const void *inputBuffer, void *outputBuffer,
                        unsigned long framesPerBuffer,
                        const libportaudio.PaStreamCallbackTimeInfo* timeInfo,
                        libportaudio.PaStreamCallbackFlags statusFlags,
                        void *userData ) nogil:
    """Called by the PortAudio engine when audio is needed.
    
    May called at interrupt level on some machines so don't do anything
    that could mess up the system like calling malloc() or free().
    """
    # Cast data passed through stream to our structure.
    cdef UserAudioData *data = <UserAudioData*>userData
    cdef float *out = <float*>outputBuffer
    cdef unsigned int i;
    
    # libpd.libpd_process_double(N_TICKS, data.inbuf, data.outbuf)
    process_double(N_TICKS, data.inbuf, data.outbuf)
    
    # dsp perform routine
    for i in range(framesPerBuffer * CHANNELS_OUT):
        if (i % 2):
            out[i] = data.outbuf[i]
        else:
            out[i] = data.outbuf[i]
    return 0


# cdef void compute_audio(int switch) nogil:
#     libpd.libpd_start_message(1)
#     libpd.libpd_add_float(switch)
#     libpd.libpd_finish_message("pd", "dsp")


def dsp(on=True):
    """easy dsp switch"""
    if on:
        val = 1
    else:
        val = 0
    start_message(1)
    add_float(val)
    finish_message("pd", "dsp")


def play(str name, str dir='.', int sample_rate=SAMPLE_RATE, 
        int ticks=N_TICKS, int blocksize=BLOCKSIZE,
        int in_channels=CHANNELS_IN, int out_channels=CHANNELS_OUT):

    print("portaudio version: ", libportaudio.Pa_GetVersion())

    # init audio
    cdef libportaudio.PaStream *stream # opens the audio stream
    cdef libportaudio.PaError err
    
    # hooks
    set_print_callback(pd_print)

    # init
    init()
    init_audio(in_channels, out_channels, sample_rate) #one channel in, one channel out

    # open patch
    handle = libpd.libpd_openfile(name.encode('utf8'), dir.encode('utf8'))
    # handle is assigned here

    with nogil:
        
        # Initialize our data for use by callback.
        for i in range(blocksize):
            data.outbuf[i] = 0
        
        # Initialize library before making any other calls.
        err = libportaudio.Pa_Initialize()
        if err != libportaudio.paNoError:
            terminate(err, handle)


        # Open an audio I/O stream.
        err = libportaudio.Pa_OpenDefaultStream(
            &stream,
            in_channels,            # input channels
            out_channels,           # output channels
            libportaudio.paFloat32, # 32 bit floating point output
            sample_rate,            # sample rate
            <long>blocksize,        # frames per buffer
            audio_callback,
            &data)

        if (err != libportaudio.paNoError):
            terminate(err, handle)

        err = libportaudio.Pa_StartStream(stream)
        if (err != libportaudio.paNoError):
            terminate(err, handle)

    libportaudio.Pa_Sleep(PRERUN_SLEEP) # will crash if inside the 'nogil' block

    # pd dsp on
    dsp(1)
    sleep(4)
    dsp(0)

    err = libportaudio.Pa_StopStream(stream)
    if err != libportaudio.paNoError:
        terminate(err, handle)

    err = libportaudio.Pa_CloseStream(stream)
    if err != libportaudio.paNoError:
        terminate(err, handle)

    libportaudio.Pa_Terminate() 
    # print(f"Ending Patch session: {err}")

    libpd.libpd_closefile(handle)

    return err

#-------------------------------------------------------------------------
# Termination

cdef void terminate(libportaudio.PaError err, void *handle) nogil:
    libportaudio.Pa_Terminate()
    fprintf(stderr, "An error occured while using the portaudio stream\n")
    fprintf(stderr, "Error number: %d\n", err)
    fprintf(stderr, "Error message: %s\n", libportaudio.Pa_GetErrorText(err))
    libpd.libpd_closefile(handle)

#-------------------------------------------------------------------------
# Initialization


def init() -> bool:
    """initialize libpd

    It is safe to call this more than once
    returns 0 on success or -1 if libpd was already initialized
    note: sets SIGFPE handler to keep bad pd patches from crashing due to divide
    by 0, set any custom handling after calling this function
    """
    return libpd.libpd_init() == 0

def clear_search_path():
    """clear the libpd search path for abstractions and externals

    note: this is called by libpd_init()
    """
    libpd.libpd_clear_search_path()

def add_to_search_path(path):
    """add a path to the libpd search paths

    relative paths are relative to the current working directory
    unlike desktop pd, *no* search paths are set by default (ie. extra)
    """
    cdef bytes _path = path.encode()
    libpd.libpd_add_to_search_path(_path)

#-------------------------------------------------------------------------
# Opening patches

def open_patch(name, dir="."):
    """open a patch by filename and parent dir path

    returns a patch id
    """
    cdef void* ptr = libpd.libpd_openfile(name.encode('utf-8'), dir.encode('utf-8'))
    if not ptr:
        raise IOError("unable to open patch: %s/%s" % (dir, name))
    patch_id = libpd.libpd_getdollarzero(ptr)
    __LIBPD_PATCHES[patch_id] = <uintptr_t>ptr
    return patch_id

def close_patch(patch_id):
    """close the open patch givens its id"""
    cdef uintptr_t ptr = <uintptr_t>__LIBPD_PATCHES[patch_id]
    libpd.libpd_closefile(<void*>ptr)

#-------------------------------------------------------------------------
# Audio processing

def get_blocksize() -> int:
    """return pd's fixed block size

    the number of sample frames per 1 pd tick
    """
    return libpd.libpd_blocksize()

def init_audio(int in_channels, int out_channels, int sample_rate) -> bool:
    """initialize audio rendering

    returns 0 on success
    """
    return libpd.libpd_init_audio(
        in_channels,
        out_channels,
        sample_rate) == 0

cdef int process_float(const int ticks, const float *in_buffer, float *out_buffer) nogil:
    """process interleaved float samples from in_buffer -> libpd -> out_buffer

    buffer sizes are based on # of ticks and channels where:
        size = ticks * libpd_blocksize() * (in/out)channels
    returns 0 on success
    """
    return libpd.libpd_process_float(ticks, in_buffer, out_buffer)

cdef int process_short(const int ticks, const short *in_buffer, short *out_buffer) nogil:
    """process interleaved short samples from in_buffer -> libpd -> out_buffer

    buffer sizes are based on # of ticks and channels where:
        size = ticks * libpd_blocksize() * (in/out)channels
    float samples are converted to short by multiplying by 32767 and casting,
    so any values received from pd patches beyond -1 to 1 will result in garbage
    note: for efficiency, does *not* clip input
    returns 0 on success
    """
    return libpd.libpd_process_short(ticks, in_buffer, out_buffer)

cdef int process_double(const int ticks, const double *in_buffer, double *out_buffer) nogil:
    """process interleaved double samples from in_buffer -> libpd -> out_buffer

    buffer sizes are based on # of ticks and channels where:
        size = ticks * libpd_blocksize() * (in/out)channels
    returns 0 on success
    """
    return libpd.libpd_process_double(ticks, in_buffer, out_buffer)


cdef int process_raw(const float *in_buffer, float *out_buffer) nogil:
    """process non-interleaved float samples from in_buffer -> libpd -> out_buffer

    copies buffer contents to/from libpd without striping
    buffer sizes are based on a single tick and # of channels where:
        size = libpd_blocksize() * (in/out)channels
    returns 0 on success
    """
    return libpd.libpd_process_raw(in_buffer, out_buffer)


cdef int process_raw_short(const short *in_buffer, short *out_buffer) nogil:
    """process non-interleaved short samples from in_buffer -> libpd -> out_buffer

    copies buffer contents to/from libpd without striping
    buffer sizes are based on a single tick and # of channels where:
        size = libpd_blocksize() * (in/out)channels
    float samples are converted to short by multiplying by 32767 and casting,
    so any values received from pd patches beyond -1 to 1 will result in garbage
    note: for efficiency, does *not* clip input
    returns 0 on success
    """
    return libpd.libpd_process_raw_short(in_buffer, out_buffer)


cdef int process_raw_double(const double *in_buffer, double *out_buffer) nogil:
    """process non-interleaved double samples from in_buffer -> libpd -> out_buffer

    copies buffer contents to/from libpd without striping
    buffer sizes are based on a single tick and # of channels where:
        size = libpd_blocksize() * (in/out)channels
    returns 0 on success
    """
    return libpd.libpd_process_raw_double(in_buffer, out_buffer)

#-------------------------------------------------------------------------
# Atom operations

cdef bint is_float(pd.t_atom *a):
    """check if an atom is a float type: 0 or 1

    note: no NULL check is performed
    """
    return libpd.libpd_is_float(a)

cdef bint is_symbol(pd.t_atom *a):
    """check if an atom is a symbol type: 0 or 1

    note: no NULL check is performed
    """
    return libpd.libpd_is_symbol(a)

cdef void set_float(pd.t_atom *a, float x):
    """write a float value to the given atom"""
    libpd.libpd_set_float(a, x)

cdef float get_float(pd.t_atom *a):
    """get the float value of an atom

    note: no NULL or type checks are performed
    """
    return libpd.libpd_get_float(a)

cdef void set_symbol(pd.t_atom *a, const char *symbol):
    """write a symbol value to the given atom.

    requires that libpd_init has already been called.
    """
    libpd.libpd_set_symbol(a, symbol)

cdef const char *get_symbol(pd.t_atom *a):
    """get symbol value of an atom

    note: no NULL or type checks are performed
    """
    return libpd.libpd_get_symbol(a)

cdef pd.t_atom *next_atom(pd.t_atom *a):
    """increment to the next atom in an atom vector

    returns next atom or NULL, assuming the atom vector is NULL-terminated
    """
    return libpd.libpd_next_atom(a)


#-------------------------------------------------------------------------
# Array access


def array_size(name: str) -> int:
    """get the size of an array by name

    returns size or negative error code if non-existent
    """
    return libpd.libpd_arraysize(name.encode('utf-8'))

def resize_array(name: str, size: int) -> int:
    """(re)size an array by name sizes <= 0 are clipped to 1

    returns 0 on success or negative error code if non-existent
    """
    return libpd.libpd_resize_array(name.encode('utf-8'), <long>size)

cdef int read_array(float *dest, const char *name, int offset, int n):
    """read n values from named src array and write into dest starting at an offset

    note: performs no bounds checking on dest
    returns 0 on success or a negative error code if the array is non-existent
    or offset + n exceeds range of array
    """
    return libpd.libpd_read_array(dest, name, offset, n)

cdef int write_array(const char *name, int offset, const float *src, int n):
    """read n values from src and write into named dest array starting at an offset

    note: performs no bounds checking on src
    returns 0 on success or a negative error code if the array is non-existent
    or offset + n exceeds range of array
    """
    return libpd.libpd_write_array(name, offset, src, n)

#-------------------------------------------------------------------------
# Sending messages to pd

def send_bang(recv) -> bool:
    """send a bang to a destination receiver

    ex: send_bang("foo") will send a bang to [s foo] on the next tick
    returns 0 on success or -1 if receiver name is non-existent
    """
    cdef bytes _recv = recv.encode()
    return libpd.libpd_bang(_recv) == 0

def send_float(recv, float x) -> bool:
    """send a float to a destination receiver

    ex: send_float("foo", 1) will send a 1.0 to [s foo] on the next tick
    returns 0 on success or -1 if receiver name is non-existent
    """
    cdef bytes _recv = recv.encode()
    return libpd.libpd_float(_recv, x) == 0

def send_symbol(recv, symbol) -> bool:
    """send a symbol to a destination receiver

    ex: send_symbol("foo", "bar") will send "bar" to [s foo] on the next tick
    returns 0 on success or -1 if receiver name is non-existent
    """
    cdef bytes _recv = recv.encode()
    cdef bytes _symbol = symbol.encode()
    return libpd.libpd_symbol(_recv, _symbol) == 0

#-------------------------------------------------------------------------
# Sending compound messages: sequenced function calls

def start_message(int maxlen) -> bool:
    """start composition of a new list or typed message of up to max element length

    messages can be of a smaller length as max length is only an upper bound
    note: no cleanup is required for unfinished messages
    returns 0 on success or nonzero if the length is too large
    """
    return libpd.libpd_start_message(maxlen) == 0

def add_float(float x):
    """add a float to the current message in progress"""
    libpd.libpd_add_float(x)

def add_symbol(symbol):
    """add a symbol to the current message in progress"""
    cdef bytes _symbol = symbol.encode()
    libpd.libpd_add_symbol(_symbol)


#-------------------------------------------------------------------------
# Sending compound messages: atom array

def send_list(recv, *args):
    """send an atom array of a given length as a list to a destination receiver
    """
    return process_args(args) or finish_list(recv)


def send_message(recv, symbol, *args):
    """send an atom array of a given length as a typed message to a destination receiver
    """
    return process_args(args) or finish_message(recv, symbol)


def finish_list(recv: str) -> bool:
    """finish current message and send as a list to a destination receiver

    returns 0 on success or -1 if receiver name is non-existent
    ex: send [list 1 2 bar( to [s foo] on the next tick with:
        libpd_start_message(3)
        libpd_add_float(1)
        libpd_add_float(2)
        libpd_add_symbol("bar")
        libpd_finish_list("foo")
    """
    return libpd.libpd_finish_list(recv.encode('utf-8')) == 0

def finish_message(recv: str, msg: str) -> bool:
    """finish current message and send as a typed message to a destination receiver

    note: typed message handling currently only supports up to 4 elements
          internally, additional elements may be ignored
    returns 0 on success or -1 if receiver name is non-existent
    ex: send [ pd dsp 1( on the next tick with:
        libpd_start_message(1)
        libpd_add_float(1)
        libpd_finish_message("pd", "dsp")
    """
    return libpd.libpd_finish_message(
        recv.encode('utf-8'), msg.encode('utf-8')) == 0

#-------------------------------------------------------------------------
# Convenience messages methods



#-------------------------------------------------------------------------
# Receiving messages from pd

def subscribe(source: str):
    """subscribe to messages sent to a source receiver

    ex: libpd_bind("foo") adds a "virtual" [r foo] which forwards messages to
        the libpd message hooks
    returns an opaque receiver pointer or NULL on failure
    """
    cdef uintptr_t ptr = <uintptr_t>libpd.libpd_bind(source.encode('utf-8'))
    if source not in __LIBPD_SUBSCRIPTIONS:
        __LIBPD_SUBSCRIPTIONS[source] = ptr

def unsubscribe(source: str):
    """unsubscribe and free a source receiver object created by libpd_bind()"""
    cdef uintptr_t ptr = <uintptr_t>__LIBPD_SUBSCRIPTIONS[source]
    libpd.libpd_unbind(<void*>ptr)

def exists(recv: str) -> bool:
    """check if a source receiver object exists with a given name

    returns 1 if the receiver exists, otherwise 0
    """
    return bool(libpd.libpd_exists(recv.encode('utf-8')))

def release():
    """shutdown libpd and releases all resources

    close all open patches and unsubscribe to all subscriptions
    """
    for p in __LIBPD_PATCHES.keys():
        close_patch(p)
    __LIBPD_PATCHES.clear()

    for p in __LIBPD_SUBSCRIPTIONS.keys():
        unsubscribe(p)
    __LIBPD_SUBSCRIPTIONS.clear()

def set_print_callback(callback):
    """set the print receiver callback, prints to stdout by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['print_callback'] = callback
        libpd.libpd_set_printhook(print_callback_hook)
    else:
        __CALLBACKS['print_callback'] = None

def set_bang_callback(callback):
    """set the bang receiver callback, NULL by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['bang_callback'] = callback
        libpd.libpd_set_banghook(bang_callback_hook)
    else:
        __CALLBACKS['bang_callback'] = None

def set_float_callback(callback):
    """set the float receiver callback, NULL by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['float_callback'] = callback
        libpd.libpd_set_floathook(float_callback_hook)
    else:
        __CALLBACKS['float_callback'] = None

def set_double_callback(callback):
    """set the double receiver callback, NULL by default

    note: do not call this while DSP is running
    note: you can either have a double receiver hook, or a float receiver
          hook (see above), but not both.
          calling this, will automatically unset the float receiver hook
    note: only full-precision when compiled with PD_FLOATSIZE=64
    """
    if callable(callback):
        __CALLBACKS['double_callback'] = callback
        libpd.libpd_set_doublehook(double_callback_hook)
    else:
        __CALLBACKS['double_callback'] = None

def set_symbol_callback(callback):
    """set the symbol receiver callback, NULL by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['symbol_callback'] = callback
        libpd.libpd_set_symbolhook(symbol_callback_hook)
    else:
        __CALLBACKS['symbol_callback'] = None

def set_list_callback(callback):
    """set the list receiver callback, NULL by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['list_callback'] = callback
        libpd.libpd_set_listhook(list_callback_hook)
    else:
        __CALLBACKS['list_callback'] = None


def set_message_callback(callback):
    """set the message receiver callback, NULL by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['message_callback'] = callback
        libpd.libpd_set_messagehook(message_callback_hook)
    else:
        __CALLBACKS['message_callback'] = None

#-------------------------------------------------------------------------
# Sending MIDI messages to pd

def noteon(channel: int , pitch: int, velocity: int) -> bool:
    """send a MIDI note on message to [notein] objects

    channel is 0-indexed, pitch is 0-127, and velocity is 0-127
    channels encode MIDI ports via: libpd_channel = pd_channel + 16 * pd_port
    note: there is no note off message, send a note on with velocity = 0 instead
    returns 0 on success or -1 if an argument is out of range
    """
    return libpd.libpd_noteon(channel, pitch, velocity) == 0

def controlchange(channel: int, controller: int, value: int) -> bool:
    """send a MIDI control change message to [ctlin] objects

    channel is 0-indexed, controller is 0-127, and value is 0-127
    channels encode MIDI ports via: libpd_channel = pd_channel + 16 * pd_port
    returns 0 on success or -1 if an argument is out of range
    """
    return libpd.libpd_controlchange(channel, controller, value) == 0

def programchange(channel: int, value: int) -> bool:
    """send a MIDI program change message to [pgmin] objects

    channel is 0-indexed and value is 0-127
    channels encode MIDI ports via: libpd_channel = pd_channel + 16 * pd_port
    returns 0 on success or -1 if an argument is out of range
    """
    return libpd.libpd_programchange(channel, value) == 0

def pitchbend(channel: int, value: int) -> bool:
    """send a MIDI pitch bend message to [bendin] objects

    channel is 0-indexed and value is -8192-8192
    channels encode MIDI ports via: libpd_channel = pd_channel + 16 * pd_port
    note: [bendin] outputs 0-16383 while [bendout] accepts -8192-8192
    returns 0 on success or -1 if an argument is out of range
    """
    return libpd.libpd_pitchbend(channel, value) == 0

def aftertouch(channel: int, value: int) -> bool:
    """send a MIDI after touch message to [touchin] objects

    channel is 0-indexed and value is 0-127
    channels encode MIDI ports via: libpd_channel = pd_channel + 16 * pd_port
    returns 0 on success or -1 if an argument is out of range
    """
    return libpd.libpd_aftertouch(channel, value) == 0

def polyaftertouch(channel: int, pitch: int, value: int) -> bool:
    """send a MIDI poly after touch message to [polytouchin] objects

    channel is 0-indexed, pitch is 0-127, and value is 0-127
    channels encode MIDI ports via: libpd_channel = pd_channel + 16 * pd_port
    returns 0 on success or -1 if an argument is out of range
    """
    return libpd.libpd_polyaftertouch(channel, pitch, value)

def midibyte(port: int, byte: int) -> bool:
    """send a raw MIDI byte to [midiin] objects

    port is 0-indexed and byte is 0-256
    returns 0 on success or -1 if an argument is out of range
    """
    return libpd.libpd_midibyte(port, byte) == 0

def sysex(port: int, byte: int) -> bool:
    """send a raw MIDI byte to [sysexin] objects

    port is 0-indexed and byte is 0-256
    returns 0 on success or -1 if an argument is out of range
    """
    return libpd.libpd_sysex(port, byte) == 0

def sysrealtime(port: int, byte: int) -> bool:
    """send a raw MIDI byte to [realtimein] objects

    port is 0-indexed and byte is 0-256
    returns 0 on success or -1 if an argument is out of range
    """
    return libpd.libpd_sysrealtime(port, byte) == 0


#-------------------------------------------------------------------------
# Receiving MIDI messages from pd

def set_noteon_callback(callback):
    """set the MIDI note on callback to receive from [noteout] objects, 
    NULL by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['noteon_callback'] = callback
        libpd.libpd_set_noteonhook(noteon_callback_hook)
    else:
        __CALLBACKS['noteon_callback'] = None

def set_controlchange_callback(callback):
    """set the MIDI control change callback to receive from [ctlout] objects,
    NULL by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['controlchange_callback'] = callback
        libpd.libpd_set_controlchangehook(controlchange_callback_hook)
    else:
        __CALLBACKS['controlchange_callback'] = None

def set_programchange_callback(callback):
    """set the MIDI program change callback to receive from [pgmout] objects,
    NULL by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['programchange_callback'] = callback
        libpd.libpd_set_programchangehook(programchange_callback_hook)
    else:
        __CALLBACKS['programchange_callback'] = None

def set_pitchbend_callback(callback):
    """set the MIDI pitch bend hook to receive from [bendout] objects,
    NULL by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['pitchbend_callback'] = callback
        libpd.libpd_set_pitchbendhook(pitchbend_callback_hook)
    else:
        __CALLBACKS['pitchbend_callback'] = None

def set_aftertouch_callback(callback):
    """set the MIDI after touch hook to receive from [touchout] objects,
    NULL by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['aftertouch_callback'] = callback
        libpd.libpd_set_aftertouchhook(aftertouch_callback_hook)
    else:
        __CALLBACKS['aftertouch_callback'] = None

def set_polyaftertouch_callback(callback):
    """set the MIDI poly after touch hook to receive from [polytouchout] objects,
    NULL by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['polyaftertouch_callback'] = callback
        libpd.libpd_set_polyaftertouchhook(polyaftertouch_callback_hook)
    else:
        __CALLBACKS['polyaftertouch_callback'] = None

def set_midibyte_callback(callback):
    """set the raw MIDI byte hook to receive from [midiout] objects,
    NULL by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['midibyte_callback'] = callback
        libpd.libpd_set_midibytehook(midibyte_callback_hook)
    else:
        __CALLBACKS['midibyte_callback'] = None

#-------------------------------------------------------------------------
# Gui

def start_gui(str path):
    """open the current patches within a pd vanilla GUI

    requires the path to pd's main folder that contains bin/, tcl/, etc
    for a macOS .app bundle: /path/to/Pd-#.#-#.app/Contents/Resources
    returns 0 on success
    """
    return libpd.libpd_start_gui(path.encode('utf-8'))

def stop_gui():
    """stop the pd vanilla GUI"""

    libpd.libpd_stop_gui()

def poll_gui():
    """manually update and handle any GUI messages

    this is called automatically when using a libpd_process function,
    note: this also facilitates network message processing, etc so it can be
    useful to call repeatedly when idle for more throughput
    """
    libpd.libpd_poll_gui()


#-------------------------------------------------------------------------
# Multiple instances

cdef pd.t_pdinstance *new_instance():
    """create a new pd instance

    returns new instance or NULL when libpd is not compiled with PDINSTANCE
    """
    return libpd.libpd_new_instance()

cdef void set_instance(pd.t_pdinstance *p):
    """set the current pd instance

    subsequent libpd calls will affect this instance only
    does nothing when libpd is not compiled with PDINSTANCE
    """
    libpd.libpd_set_instance(p)

cdef void free_instance(pd.t_pdinstance *p):
    """free a pd instance

    does nothing when libpd is not compiled with PDINSTANCE
    """
    libpd.libpd_free_instance(p)

cdef pd.t_pdinstance *this_instance():
    """get the current pd instance"""

    return libpd.libpd_this_instance()

cdef pd.t_pdinstance *get_instance(int index):
    """get a pd instance by index

    returns NULL if index is out of bounds or "this" instance when libpd is not
    compiled with PDINSTANCE
    """
    return libpd.libpd_get_instance(index)

def num_instances() -> int:
    """get the number of pd instances

    returns number or 1 when libpd is not compiled with PDINSTANCE
    """
    return libpd.libpd_num_instances()


#-------------------------------------------------------------------------
# Log level


def get_verbose() -> int:
    """get verbose print state: 0 or 1"""
    return libpd.libpd_get_verbose()

def set_verbose(verbose: int):
    """set verbose print state: 0 or 1"""
    libpd.libpd_set_verbose(verbose)

def pd_version() -> str:
    """returns pd version"""
    cdef int major, minor, bugfix
    pd.sys_getversion(&major, &minor, &bugfix)
    return f'{major}.{minor}.{bugfix}'


#-------------------------------------------------------------------------
# extended api

def set_queued_print_callback(callback):
    """set the queued print receiver callback, NULL by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['print_callback'] = callback
        libpd.libpd_set_queued_printhook(print_callback_hook)
    else:
        __CALLBACKS['print_callback'] = None

def set_queued_bang_callback(callback):
    """set the queued bang receiver hook, NULL by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['bang_callback'] = callback
        libpd.libpd_set_queued_banghook(bang_callback_hook)
    else:
        __CALLBACKS['bang_callback'] = None

def set_queued_float_callback(callback):
    """set the queued float receiver hook, NULL by default

    note: avoid calling this while DSP is running
    note: you can either have a queued float receiver hook, or a queued
          double receiver hook (see below), but not both.
          calling this, will automatically unset the queued double receiver
          hook
    """
    if callable(callback):
        __CALLBACKS['float_callback'] = callback
        libpd.libpd_set_queued_floathook(float_callback_hook)
    else:
        __CALLBACKS['float_callback'] = None

def set_queued_double_callback(callback):
    """set the queued double receiver hook, NULL by default

    note: avoid calling this while DSP is running
    note: you can either have a queued double receiver hook, or a queued
          float receiver hook (see above), but not both.
          calling this, will automatically unset the queued float receiver
          hook
    """
    if callable(callback):
        __CALLBACKS['double_callback'] = callback
        libpd.libpd_set_queued_doublehook(double_callback_hook)
    else:
        __CALLBACKS['double_callback'] = None

def set_queued_symbol_callback(callback):
    """set the queued symbol receiver hook, NULL by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['symbol_callback'] = callback
        libpd.libpd_set_queued_symbolhook(symbol_callback_hook)
    else:
        __CALLBACKS['symbol_callback'] = None

def set_queued_list_callback(callback):
    """set the queued list receiver hook, NULL by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['list_callback'] = callback
        libpd.libpd_set_queued_listhook(list_callback_hook)
    else:
        __CALLBACKS['list_callback'] = None

def set_queued_message_callback(callback):
    """set the queued typed message receiver hook, NULL by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['message_callback'] = callback
        libpd.libpd_set_queued_messagehook(message_callback_hook)
    else:
        __CALLBACKS['message_callback'] = None

def set_queued_noteon_callback(callback):
    """set the queued MIDI note on hook, NULL by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['noteon_callback'] = callback
        libpd.libpd_set_queued_noteonhook(noteon_callback_hook)
    else:
        __CALLBACKS['noteon_callback'] = None

def set_queued_controlchange_callback(callback):
    """set the queued MIDI control change hook, NULL by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['controlchange_callback'] = callback
        libpd.libpd_set_queued_controlchangehook(controlchange_callback_hook)
    else:
        __CALLBACKS['controlchange_callback'] = None

def set_queued_programchange_callback(callback):
    """set the queued MIDI program change hook, NULL by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['programchange_callback'] = callback
        libpd.libpd_set_queued_programchangehook(programchange_callback_hook)
    else:
        __CALLBACKS['programchange_callback'] = None

def set_queued_pitchbend_callback(callback):
    """set the queued MIDI pitch bend hook, NULL by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['pitchbend_callback'] = callback
        libpd.libpd_set_queued_pitchbendhook(pitchbend_callback_hook)
    else:
        __CALLBACKS['pitchbend_callback'] = None

def set_queued_aftertouch_callback(callback):
    """set the queued MIDI aftertouch hook, NULL by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['aftertouch_callback'] = callback
        libpd.libpd_set_queued_aftertouchhook(aftertouch_callback_hook)
    else:
        __CALLBACKS['aftertouch_callback'] = None

def set_queued_polyaftertouch_callback(callback):
    """set the queued MIDI polyaftertouch hook, NULL by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['polyaftertouch_callback'] = callback
        libpd.libpd_set_queued_polyaftertouchhook(polyaftertouch_callback_hook)
    else:
        __CALLBACKS['polyaftertouch_callback'] = None

def set_queued_midibyte_callback(callback):
    """set the queued MIDI byte hook, NULL by default

    note: do not call this while DSP is running
    """
    if callable(callback):
        __CALLBACKS['midibyte_callback'] = callback
        libpd.libpd_set_queued_midibytehook(midibyte_callback_hook)
    else:
        __CALLBACKS['midibyte_callback'] = None

def queued_init() -> bool:
    """initialize libpd and the queued ringbuffers, use in place of libpd_init()
    
    this is safe to call more than once
    returns 0 on success, -1 if libpd was already initialized, or -2 if ring
    buffer allocation failed
    """
    return libpd.libpd_queued_init() == 0

def queued_release():
    """free the queued ringbuffers"""
    libpd.libpd_queued_release()

def queued_receive_pd_messages():
    """process and dispatch received messages in message ringbuffer"""
    libpd.libpd_queued_receive_pd_messages()

def queued_receive_midi_messages():
    """process and dispatch receive midi messages in MIDI message ringbuffer"""
    libpd.libpd_queued_receive_midi_messages()


#-------------------------------------------------------------------------
# class helper

# cdef class PdManager:
#     cdef const short* __out_bufffer

#     def __init__(self, int in_channels, int out_channels, int samplerate, int ticks):
#         self.__ticks = ticks
#         self.__out_bufffer = NULL
#         dsp(1)
#         init_audio(in_channels, out_channels, samplerate)

#     cdef process(self, short* in_buffer):
#         process_short(self.__ticks, in_buffer, self.__out_bufffer)
#         res = array.array('b', '\x00\x00'.encode() * CHANNELS_OUT * libpd_blocksize())
#         res.data = <int>self.__out_bufffer
#         return res

#         # process_double(self.__ticks, in_buffer, self.__out_bufffer)
#         # return self.__out_bufffer
