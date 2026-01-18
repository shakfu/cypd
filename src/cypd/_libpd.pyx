"""_libpd.pyx

Core Cython wrapper for libpd - Pure Data as an embeddable audio library.

This module provides a functional API to libpd without any audio backend.
Users can integrate their own audio I/O (miniaudio, portaudio, etc.) and
call the process_* functions from their audio callback.
"""
cimport pd
cimport libpd

from libc.stdlib cimport malloc, free
from libc.stdint cimport uintptr_t

# ----------------------------------------------------------------------------
# pure python callbacks (default handlers for testing/debugging)

def pd_print(str s):
    print("pd>>", s.strip())

def pd_bang(str recv):
    print(f"pd>> BANG {recv}")

def pd_float(str recv, float f):
    print(f"pd>> float {f} {recv}")

def pd_symbol(str recv, str sym):
    print(f"pd>> symbol {sym} {recv}")

def pd_list(*args):
    print(f"pd>> list {args}")

def pd_message(*args):
    print(f"pd>> msg {args}")

def pd_noteon(int channel, int pitch, int velocity):
    print(f"pd>> noteon chan: {channel} pitch: {pitch} vel: {velocity}")

def init_hooks():
    """Initialize all default hooks with debug print callbacks."""
    set_print_callback(pd_print)
    set_bang_callback(pd_bang)
    set_float_callback(pd_float)
    set_symbol_callback(pd_symbol)
    set_message_callback(pd_message)
    set_list_callback(pd_list)

# ----------------------------------------------------------------------------
# message and midi callback slots

CALLBACKS = dict(
    # message callbacks
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
# callback hooks (C-level trampolines to Python callbacks)
#
# These callbacks can be triggered from the audio thread (via libpd_process_*)
# which runs without the GIL. We must explicitly acquire the GIL before
# accessing any Python objects.

# messaging
cdef void print_callback_hook(const char *s) noexcept nogil:
    with gil:
        if CALLBACKS['print_callback']:
            CALLBACKS['print_callback'](s.decode())

cdef void bang_callback_hook(const char *recv) noexcept nogil:
    with gil:
        if CALLBACKS['bang_callback']:
            CALLBACKS['bang_callback'](recv.decode())

cdef void float_callback_hook(const char *recv, float f) noexcept nogil:
    with gil:
        if CALLBACKS['float_callback']:
            CALLBACKS['float_callback'](recv.decode(), f)

cdef void double_callback_hook(const char *recv, double d) noexcept nogil:
    with gil:
        if CALLBACKS['double_callback']:
            CALLBACKS['double_callback'](recv.decode(), d)

cdef void symbol_callback_hook(const char *recv, const char *symbol) noexcept nogil:
    with gil:
        if CALLBACKS['symbol_callback']:
            CALLBACKS['symbol_callback'](recv.decode(), symbol.decode())

cdef void list_callback_hook(const char *recv, int argc, pd.t_atom *argv) noexcept nogil:
    with gil:
        if CALLBACKS['list_callback']:
            args = convert_args(recv, NULL, argc, argv)
            CALLBACKS['list_callback'](*args)

cdef void message_callback_hook(const char *recv, const char *symbol, int argc, pd.t_atom *argv) noexcept nogil:
    with gil:
        if CALLBACKS['message_callback']:
            args = convert_args(recv, symbol, argc, argv)
            CALLBACKS['message_callback'](*args)

# midi
cdef void noteon_callback_hook(int channel, int pitch, int velocity) noexcept nogil:
    with gil:
        if CALLBACKS['noteon_callback']:
            CALLBACKS['noteon_callback'](channel, pitch, velocity)

cdef void controlchange_callback_hook(int channel, int controller, int value) noexcept nogil:
    with gil:
        if CALLBACKS['controlchange_callback']:
            CALLBACKS['controlchange_callback'](channel, controller, value)

cdef void programchange_callback_hook(int channel, int value) noexcept nogil:
    with gil:
        if CALLBACKS['programchange_callback']:
            CALLBACKS['programchange_callback'](channel, value)

cdef void pitchbend_callback_hook(int channel, int value) noexcept nogil:
    with gil:
        if CALLBACKS['pitchbend_callback']:
            CALLBACKS['pitchbend_callback'](channel, value)

cdef void aftertouch_callback_hook(int channel, int value) noexcept nogil:
    with gil:
        if CALLBACKS['aftertouch_callback']:
            CALLBACKS['aftertouch_callback'](channel, value)

cdef void polyaftertouch_callback_hook(int channel, int pitch, int value) noexcept nogil:
    with gil:
        if CALLBACKS['polyaftertouch_callback']:
            CALLBACKS['polyaftertouch_callback'](channel, pitch, value)

cdef void midibyte_callback_hook(int port, int byte) noexcept nogil:
    with gil:
        if CALLBACKS['midibyte_callback']:
            CALLBACKS['midibyte_callback'](port, byte)

# ----------------------------------------------------------------------------
# helper functions

cdef convert_args(const char *recv, const char *symbol, int argc, pd.t_atom *argv):
    """Convert libpd atom array to Python tuple."""
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
    """Process Python args into libpd message atoms."""
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
# Initialization

def init() -> bool:
    """Initialize libpd.

    It is safe to call this more than once.
    Returns True on success, False if libpd was already initialized.

    Note: sets SIGFPE handler to keep bad pd patches from crashing due to
    divide by 0. Set any custom handling after calling this function.
    """
    return libpd.libpd_init() == 0

def clear_search_path():
    """Clear the libpd search path for abstractions and externals.

    Note: this is called by init().
    """
    libpd.libpd_clear_search_path()

def add_to_search_path(path):
    """Add a path to the libpd search paths.

    Relative paths are relative to the current working directory.
    Unlike desktop pd, *no* search paths are set by default (ie. extra).
    """
    cdef bytes _path = path.encode()
    libpd.libpd_add_to_search_path(_path)

# ----------------------------------------------------------------------------
# Opening patches

def open_patch(name, dir="."):
    """Open a patch by filename and parent dir path.

    Returns a patch id that can be used with close_patch().
    Raises IOError if the patch cannot be opened.
    """
    cdef void* ptr = libpd.libpd_openfile(name.encode('utf-8'), dir.encode('utf-8'))
    if not ptr:
        raise IOError("unable to open patch: %s/%s" % (dir, name))
    patch_id = libpd.libpd_getdollarzero(ptr)
    __LIBPD_PATCHES[patch_id] = <uintptr_t>ptr
    return patch_id

def close_patch(patch_id):
    """Close an open patch given its id."""
    cdef uintptr_t ptr = <uintptr_t>__LIBPD_PATCHES[patch_id]
    libpd.libpd_closefile(<void*>ptr)
    del __LIBPD_PATCHES[patch_id]

# ----------------------------------------------------------------------------
# Audio processing

def get_blocksize() -> int:
    """Return pd's fixed block size.

    The number of sample frames per 1 pd tick (always 64).
    """
    return libpd.libpd_blocksize()

def init_audio(int in_channels, int out_channels, int sample_rate) -> bool:
    """Initialize audio rendering.

    Args:
        in_channels: Number of input channels
        out_channels: Number of output channels
        sample_rate: Sample rate in Hz

    Returns True on success.
    """
    return libpd.libpd_init_audio(in_channels, out_channels, sample_rate) == 0

def dsp(on=True):
    """Turn DSP processing on or off."""
    cdef int val = 1 if on else 0
    start_message(1)
    add_float(val)
    finish_message("pd", "dsp")

# Low-level process functions (for use in audio callbacks)
# These are cdef functions - call from Cython code in your audio backend

cdef int process_float(const int ticks, const float *in_buffer, float *out_buffer) noexcept nogil:
    """Process interleaved float samples from in_buffer -> libpd -> out_buffer.

    Buffer sizes are based on # of ticks and channels where:
        size = ticks * libpd_blocksize() * (in/out)channels
    Returns 0 on success.
    """
    return libpd.libpd_process_float(ticks, in_buffer, out_buffer)

# Exported function for _audio module to use (ensures same libpd instance)
cdef int process_float_ticks(int ticks, float *in_buffer, float *out_buffer) noexcept nogil:
    """Process audio - exported for _audio module.

    This ensures _audio uses the same libpd instance as _libpd.
    """
    return libpd.libpd_process_float(ticks, in_buffer, out_buffer)

def _get_process_float_ptr() -> int:
    """Get the address of libpd_process_float for use by _audio module.

    This allows _audio to call libpd_process_float from the same libpd
    instance that _libpd uses, avoiding duplicate static library linking issues.

    Returns the function pointer as an integer (for ctypes/Cython interop).
    """
    return <uintptr_t>&libpd.libpd_process_float

cdef int process_short(const int ticks, const short *in_buffer, short *out_buffer) noexcept nogil:
    """Process interleaved short samples from in_buffer -> libpd -> out_buffer.

    Buffer sizes are based on # of ticks and channels where:
        size = ticks * libpd_blocksize() * (in/out)channels
    Float samples are converted to short by multiplying by 32767 and casting.
    Note: for efficiency, does *not* clip input.
    Returns 0 on success.
    """
    return libpd.libpd_process_short(ticks, in_buffer, out_buffer)

cdef int process_double(const int ticks, const double *in_buffer, double *out_buffer) noexcept nogil:
    """Process interleaved double samples from in_buffer -> libpd -> out_buffer.

    Buffer sizes are based on # of ticks and channels where:
        size = ticks * libpd_blocksize() * (in/out)channels
    Returns 0 on success.
    """
    return libpd.libpd_process_double(ticks, in_buffer, out_buffer)

cdef int process_raw(const float *in_buffer, float *out_buffer) noexcept nogil:
    """Process non-interleaved float samples from in_buffer -> libpd -> out_buffer.

    Copies buffer contents to/from libpd without striping.
    Buffer sizes are based on a single tick and # of channels where:
        size = libpd_blocksize() * (in/out)channels
    Returns 0 on success.
    """
    return libpd.libpd_process_raw(in_buffer, out_buffer)

cdef int process_raw_short(const short *in_buffer, short *out_buffer) noexcept nogil:
    """Process non-interleaved short samples."""
    return libpd.libpd_process_raw_short(in_buffer, out_buffer)

cdef int process_raw_double(const double *in_buffer, double *out_buffer) noexcept nogil:
    """Process non-interleaved double samples."""
    return libpd.libpd_process_raw_double(in_buffer, out_buffer)

# ----------------------------------------------------------------------------
# Atom operations (cdef - for Cython code)

cdef bint is_float(pd.t_atom *a):
    """Check if an atom is a float type."""
    return libpd.libpd_is_float(a)

cdef bint is_symbol(pd.t_atom *a):
    """Check if an atom is a symbol type."""
    return libpd.libpd_is_symbol(a)

cdef void set_float(pd.t_atom *a, float x):
    """Write a float value to the given atom."""
    libpd.libpd_set_float(a, x)

cdef float get_float(pd.t_atom *a):
    """Get the float value of an atom."""
    return libpd.libpd_get_float(a)

cdef void set_symbol(pd.t_atom *a, const char *symbol):
    """Write a symbol value to the given atom."""
    libpd.libpd_set_symbol(a, symbol)

cdef const char *get_symbol(pd.t_atom *a):
    """Get symbol value of an atom."""
    return libpd.libpd_get_symbol(a)

cdef pd.t_atom *next_atom(pd.t_atom *a):
    """Increment to the next atom in an atom vector."""
    return libpd.libpd_next_atom(a)

# ----------------------------------------------------------------------------
# Array access

def array_size(name: str) -> int:
    """Get the size of an array by name.

    Returns size or negative error code if non-existent.
    """
    return libpd.libpd_arraysize(name.encode('utf-8'))

def resize_array(name: str, size: int) -> int:
    """Resize an array by name. Sizes <= 0 are clipped to 1.

    Returns 0 on success or negative error code if non-existent.
    """
    return libpd.libpd_resize_array(name.encode('utf-8'), <long>size)

cdef int read_array(float *dest, const char *name, int offset, int n):
    """Read n values from named array into dest starting at offset."""
    return libpd.libpd_read_array(dest, name, offset, n)

cdef int write_array(const char *name, int offset, const float *src, int n):
    """Write n values from src into named array starting at offset."""
    return libpd.libpd_write_array(name, offset, src, n)

# ----------------------------------------------------------------------------
# Sending messages to pd

def send_bang(recv) -> bool:
    """Send a bang to a destination receiver.

    Ex: send_bang("foo") will send a bang to [s foo] on the next tick.
    Returns True on success, False if receiver name is non-existent.
    """
    cdef bytes _recv = recv.encode()
    return libpd.libpd_bang(_recv) == 0

def send_float(recv, float x) -> bool:
    """Send a float to a destination receiver.

    Ex: send_float("foo", 1.0) will send 1.0 to [s foo] on the next tick.
    Returns True on success, False if receiver name is non-existent.
    """
    cdef bytes _recv = recv.encode()
    return libpd.libpd_float(_recv, x) == 0

def send_symbol(recv, symbol) -> bool:
    """Send a symbol to a destination receiver.

    Ex: send_symbol("foo", "bar") will send "bar" to [s foo] on the next tick.
    Returns True on success, False if receiver name is non-existent.
    """
    cdef bytes _recv = recv.encode()
    cdef bytes _symbol = symbol.encode()
    return libpd.libpd_symbol(_recv, _symbol) == 0

# ----------------------------------------------------------------------------
# Sending compound messages

def start_message(int maxlen) -> bool:
    """Start composition of a new list or typed message.

    Messages can be shorter than maxlen (it's an upper bound).
    No cleanup is required for unfinished messages.
    Returns True on success, False if length is too large.
    """
    return libpd.libpd_start_message(maxlen) == 0

def add_float(float x):
    """Add a float to the current message in progress."""
    libpd.libpd_add_float(x)

def add_symbol(symbol):
    """Add a symbol to the current message in progress."""
    cdef bytes _symbol = symbol.encode()
    libpd.libpd_add_symbol(_symbol)

def send_list(recv, *args):
    """Send an atom array as a list to a destination receiver."""
    return process_args(args) or finish_list(recv)

def send_message(recv, symbol, *args):
    """Send an atom array as a typed message to a destination receiver."""
    return process_args(args) or finish_message(recv, symbol)

def finish_list(recv: str) -> bool:
    """Finish current message and send as a list to a destination receiver.

    Returns True on success, False if receiver name is non-existent.
    """
    return libpd.libpd_finish_list(recv.encode('utf-8')) == 0

def finish_message(recv: str, msg: str) -> bool:
    """Finish current message and send as a typed message.

    Note: typed message handling currently only supports up to 4 elements.
    Returns True on success, False if receiver name is non-existent.
    """
    return libpd.libpd_finish_message(recv.encode('utf-8'), msg.encode('utf-8')) == 0

# ----------------------------------------------------------------------------
# Receiving messages from pd

def subscribe(source: str):
    """Subscribe to messages sent to a source receiver.

    Ex: subscribe("foo") adds a "virtual" [r foo] which forwards messages
    to the libpd message hooks.
    """
    cdef uintptr_t ptr = <uintptr_t>libpd.libpd_bind(source.encode('utf-8'))
    if source not in __LIBPD_SUBSCRIPTIONS:
        __LIBPD_SUBSCRIPTIONS[source] = ptr

def unsubscribe(source: str):
    """Unsubscribe from a source receiver."""
    cdef uintptr_t ptr = <uintptr_t>__LIBPD_SUBSCRIPTIONS[source]
    libpd.libpd_unbind(<void*>ptr)
    del __LIBPD_SUBSCRIPTIONS[source]

def exists(recv: str) -> bool:
    """Check if a source receiver object exists with a given name."""
    return bool(libpd.libpd_exists(recv.encode('utf-8')))

def release():
    """Shutdown libpd and release all resources.

    Closes all open patches and unsubscribes from all subscriptions.
    """
    for p in list(__LIBPD_PATCHES.keys()):
        close_patch(p)
    __LIBPD_PATCHES.clear()

    for p in list(__LIBPD_SUBSCRIPTIONS.keys()):
        unsubscribe(p)
    __LIBPD_SUBSCRIPTIONS.clear()

# ----------------------------------------------------------------------------
# Message callbacks

def set_print_callback(callback):
    """Set the print receiver callback. Prints to stdout by default.

    Note: do not call this while DSP is running.
    """
    if callable(callback):
        CALLBACKS['print_callback'] = callback
        libpd.libpd_set_printhook(print_callback_hook)
    else:
        CALLBACKS['print_callback'] = None

def set_bang_callback(callback):
    """Set the bang receiver callback, NULL by default.

    Note: do not call this while DSP is running.
    """
    if callable(callback):
        CALLBACKS['bang_callback'] = callback
        libpd.libpd_set_banghook(bang_callback_hook)
    else:
        CALLBACKS['bang_callback'] = None

def set_float_callback(callback):
    """Set the float receiver callback, NULL by default.

    Note: do not call this while DSP is running.
    """
    if callable(callback):
        CALLBACKS['float_callback'] = callback
        libpd.libpd_set_floathook(float_callback_hook)
    else:
        CALLBACKS['float_callback'] = None

def set_double_callback(callback):
    """Set the double receiver callback, NULL by default.

    Note: do not call this while DSP is running.
    Note: you can have either a double or float receiver hook, not both.
    """
    if callable(callback):
        CALLBACKS['double_callback'] = callback
        libpd.libpd_set_doublehook(double_callback_hook)
    else:
        CALLBACKS['double_callback'] = None

def set_symbol_callback(callback):
    """Set the symbol receiver callback, NULL by default.

    Note: do not call this while DSP is running.
    """
    if callable(callback):
        CALLBACKS['symbol_callback'] = callback
        libpd.libpd_set_symbolhook(symbol_callback_hook)
    else:
        CALLBACKS['symbol_callback'] = None

def set_list_callback(callback):
    """Set the list receiver callback, NULL by default.

    Note: do not call this while DSP is running.
    """
    if callable(callback):
        CALLBACKS['list_callback'] = callback
        libpd.libpd_set_listhook(list_callback_hook)
    else:
        CALLBACKS['list_callback'] = None

def set_message_callback(callback):
    """Set the message receiver callback, NULL by default.

    Note: do not call this while DSP is running.
    """
    if callable(callback):
        CALLBACKS['message_callback'] = callback
        libpd.libpd_set_messagehook(message_callback_hook)
    else:
        CALLBACKS['message_callback'] = None

# ----------------------------------------------------------------------------
# Sending MIDI messages to pd

def noteon(channel: int, pitch: int, velocity: int) -> bool:
    """Send a MIDI note on message to [notein] objects.

    channel is 0-indexed, pitch is 0-127, velocity is 0-127.
    Channels encode MIDI ports: libpd_channel = pd_channel + 16 * pd_port.
    Note: there is no note off, send note on with velocity=0 instead.
    """
    return libpd.libpd_noteon(channel, pitch, velocity) == 0

def controlchange(channel: int, controller: int, value: int) -> bool:
    """Send a MIDI control change message to [ctlin] objects."""
    return libpd.libpd_controlchange(channel, controller, value) == 0

def programchange(channel: int, value: int) -> bool:
    """Send a MIDI program change message to [pgmin] objects."""
    return libpd.libpd_programchange(channel, value) == 0

def pitchbend(channel: int, value: int) -> bool:
    """Send a MIDI pitch bend message to [bendin] objects.

    Value is -8192 to 8192.
    """
    return libpd.libpd_pitchbend(channel, value) == 0

def aftertouch(channel: int, value: int) -> bool:
    """Send a MIDI after touch message to [touchin] objects."""
    return libpd.libpd_aftertouch(channel, value) == 0

def polyaftertouch(channel: int, pitch: int, value: int) -> bool:
    """Send a MIDI poly after touch message to [polytouchin] objects."""
    return libpd.libpd_polyaftertouch(channel, pitch, value) == 0

def midibyte(port: int, byte: int) -> bool:
    """Send a raw MIDI byte to [midiin] objects."""
    return libpd.libpd_midibyte(port, byte) == 0

def sysex(port: int, byte: int) -> bool:
    """Send a raw MIDI byte to [sysexin] objects."""
    return libpd.libpd_sysex(port, byte) == 0

def sysrealtime(port: int, byte: int) -> bool:
    """Send a raw MIDI byte to [realtimein] objects."""
    return libpd.libpd_sysrealtime(port, byte) == 0

# ----------------------------------------------------------------------------
# Receiving MIDI messages from pd

def set_noteon_callback(callback):
    """Set the MIDI note on callback to receive from [noteout] objects."""
    if callable(callback):
        CALLBACKS['noteon_callback'] = callback
        libpd.libpd_set_noteonhook(noteon_callback_hook)
    else:
        CALLBACKS['noteon_callback'] = None

def set_controlchange_callback(callback):
    """Set the MIDI control change callback to receive from [ctlout] objects."""
    if callable(callback):
        CALLBACKS['controlchange_callback'] = callback
        libpd.libpd_set_controlchangehook(controlchange_callback_hook)
    else:
        CALLBACKS['controlchange_callback'] = None

def set_programchange_callback(callback):
    """Set the MIDI program change callback to receive from [pgmout] objects."""
    if callable(callback):
        CALLBACKS['programchange_callback'] = callback
        libpd.libpd_set_programchangehook(programchange_callback_hook)
    else:
        CALLBACKS['programchange_callback'] = None

def set_pitchbend_callback(callback):
    """Set the MIDI pitch bend callback to receive from [bendout] objects."""
    if callable(callback):
        CALLBACKS['pitchbend_callback'] = callback
        libpd.libpd_set_pitchbendhook(pitchbend_callback_hook)
    else:
        CALLBACKS['pitchbend_callback'] = None

def set_aftertouch_callback(callback):
    """Set the MIDI after touch callback to receive from [touchout] objects."""
    if callable(callback):
        CALLBACKS['aftertouch_callback'] = callback
        libpd.libpd_set_aftertouchhook(aftertouch_callback_hook)
    else:
        CALLBACKS['aftertouch_callback'] = None

def set_polyaftertouch_callback(callback):
    """Set the MIDI poly after touch callback to receive from [polytouchout]."""
    if callable(callback):
        CALLBACKS['polyaftertouch_callback'] = callback
        libpd.libpd_set_polyaftertouchhook(polyaftertouch_callback_hook)
    else:
        CALLBACKS['polyaftertouch_callback'] = None

def set_midibyte_callback(callback):
    """Set the raw MIDI byte callback to receive from [midiout] objects."""
    if callable(callback):
        CALLBACKS['midibyte_callback'] = callback
        libpd.libpd_set_midibytehook(midibyte_callback_hook)
    else:
        CALLBACKS['midibyte_callback'] = None

# ----------------------------------------------------------------------------
# GUI

def start_gui(str path):
    """Open the current patches within a pd vanilla GUI.

    Requires the path to pd's main folder that contains bin/, tcl/, etc.
    For a macOS .app bundle: /path/to/Pd-#.#-#.app/Contents/Resources
    Returns 0 on success.
    """
    return libpd.libpd_start_gui(path.encode('utf-8'))

def stop_gui():
    """Stop the pd vanilla GUI."""
    libpd.libpd_stop_gui()

def poll_gui() -> int:
    """Manually update and handle any GUI messages.

    This is called automatically when using a process function.
    Returns 1 if the poll found something (suggesting another poll might help).
    """
    return libpd.libpd_poll_gui()

# ----------------------------------------------------------------------------
# Multiple instances

cdef pd.t_pdinstance *new_instance():
    """Create a new pd instance."""
    return libpd.libpd_new_instance()

cdef void set_instance(pd.t_pdinstance *p):
    """Set the current pd instance."""
    libpd.libpd_set_instance(p)

cdef void free_instance(pd.t_pdinstance *p):
    """Free a pd instance."""
    libpd.libpd_free_instance(p)

cdef pd.t_pdinstance *this_instance():
    """Get the current pd instance."""
    return libpd.libpd_this_instance()

def num_instances() -> int:
    """Get the number of pd instances.

    Returns 1 when libpd is not compiled with PDINSTANCE.
    """
    return libpd.libpd_num_instances()

# ----------------------------------------------------------------------------
# Logging

def get_verbose() -> int:
    """Get verbose print state: 0 or 1."""
    return libpd.libpd_get_verbose()

def set_verbose(verbose: int):
    """Set verbose print state: 0 or 1."""
    libpd.libpd_set_verbose(verbose)

def pd_version() -> str:
    """Returns pd version string (e.g., "0.54.1")."""
    cdef int major, minor, bugfix
    pd.sys_getversion(&major, &minor, &bugfix)
    return f'{major}.{minor}.{bugfix}'

# ----------------------------------------------------------------------------
# Queued API (thread-safe message passing)

def set_queued_print_callback(callback):
    """Set the queued print receiver callback."""
    if callable(callback):
        CALLBACKS['print_callback'] = callback
        libpd.libpd_set_queued_printhook(print_callback_hook)
    else:
        CALLBACKS['print_callback'] = None

def set_queued_bang_callback(callback):
    """Set the queued bang receiver callback."""
    if callable(callback):
        CALLBACKS['bang_callback'] = callback
        libpd.libpd_set_queued_banghook(bang_callback_hook)
    else:
        CALLBACKS['bang_callback'] = None

def set_queued_float_callback(callback):
    """Set the queued float receiver callback."""
    if callable(callback):
        CALLBACKS['float_callback'] = callback
        libpd.libpd_set_queued_floathook(float_callback_hook)
    else:
        CALLBACKS['float_callback'] = None

def set_queued_double_callback(callback):
    """Set the queued double receiver callback."""
    if callable(callback):
        CALLBACKS['double_callback'] = callback
        libpd.libpd_set_queued_doublehook(double_callback_hook)
    else:
        CALLBACKS['double_callback'] = None

def set_queued_symbol_callback(callback):
    """Set the queued symbol receiver callback."""
    if callable(callback):
        CALLBACKS['symbol_callback'] = callback
        libpd.libpd_set_queued_symbolhook(symbol_callback_hook)
    else:
        CALLBACKS['symbol_callback'] = None

def set_queued_list_callback(callback):
    """Set the queued list receiver callback."""
    if callable(callback):
        CALLBACKS['list_callback'] = callback
        libpd.libpd_set_queued_listhook(list_callback_hook)
    else:
        CALLBACKS['list_callback'] = None

def set_queued_message_callback(callback):
    """Set the queued typed message receiver callback."""
    if callable(callback):
        CALLBACKS['message_callback'] = callback
        libpd.libpd_set_queued_messagehook(message_callback_hook)
    else:
        CALLBACKS['message_callback'] = None

def set_queued_noteon_callback(callback):
    """Set the queued MIDI note on callback."""
    if callable(callback):
        CALLBACKS['noteon_callback'] = callback
        libpd.libpd_set_queued_noteonhook(noteon_callback_hook)
    else:
        CALLBACKS['noteon_callback'] = None

def set_queued_controlchange_callback(callback):
    """Set the queued MIDI control change callback."""
    if callable(callback):
        CALLBACKS['controlchange_callback'] = callback
        libpd.libpd_set_queued_controlchangehook(controlchange_callback_hook)
    else:
        CALLBACKS['controlchange_callback'] = None

def set_queued_programchange_callback(callback):
    """Set the queued MIDI program change callback."""
    if callable(callback):
        CALLBACKS['programchange_callback'] = callback
        libpd.libpd_set_queued_programchangehook(programchange_callback_hook)
    else:
        CALLBACKS['programchange_callback'] = None

def set_queued_pitchbend_callback(callback):
    """Set the queued MIDI pitch bend callback."""
    if callable(callback):
        CALLBACKS['pitchbend_callback'] = callback
        libpd.libpd_set_queued_pitchbendhook(pitchbend_callback_hook)
    else:
        CALLBACKS['pitchbend_callback'] = None

def set_queued_aftertouch_callback(callback):
    """Set the queued MIDI aftertouch callback."""
    if callable(callback):
        CALLBACKS['aftertouch_callback'] = callback
        libpd.libpd_set_queued_aftertouchhook(aftertouch_callback_hook)
    else:
        CALLBACKS['aftertouch_callback'] = None

def set_queued_polyaftertouch_callback(callback):
    """Set the queued MIDI poly aftertouch callback."""
    if callable(callback):
        CALLBACKS['polyaftertouch_callback'] = callback
        libpd.libpd_set_queued_polyaftertouchhook(polyaftertouch_callback_hook)
    else:
        CALLBACKS['polyaftertouch_callback'] = None

def set_queued_midibyte_callback(callback):
    """Set the queued MIDI byte callback."""
    if callable(callback):
        CALLBACKS['midibyte_callback'] = callback
        libpd.libpd_set_queued_midibytehook(midibyte_callback_hook)
    else:
        CALLBACKS['midibyte_callback'] = None

def queued_init() -> bool:
    """Initialize libpd and the queued ringbuffers.

    Use in place of init() for thread-safe message passing.
    Returns True on success.
    """
    return libpd.libpd_queued_init() == 0

def queued_release():
    """Free the queued ringbuffers."""
    libpd.libpd_queued_release()

def queued_receive_pd_messages():
    """Process and dispatch received messages in message ringbuffer."""
    libpd.libpd_queued_receive_pd_messages()

def queued_receive_midi_messages():
    """Process and dispatch received MIDI messages in MIDI ringbuffer."""
    libpd.libpd_queued_receive_midi_messages()
