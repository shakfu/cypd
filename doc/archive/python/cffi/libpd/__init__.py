import array

from ._libpd import lib, ffi

#-------------------------------------------------------------------------
# Globals

__LIBPD_PATCHES = {}

__LIBPD_SUBSCRIPTIONS = {}

#-------------------------------------------------------------------------
# Initialization


def init() -> bool:
    """initialize libpd

    It is safe to call this more than once
    returns 0 on success or -1 if libpd was already initialized
    note: sets SIGFPE handler to keep bad pd patches from crashing due to divide
    by 0, set any custom handling after calling this function
    """
    return lib.libpd_init() == 0

def clear_search_path():
    """clear the libpd search path for abstractions and externals

    note: this is called by libpd_init()
    """
    lib.libpd_clear_search_path()

def add_to_search_path(path: str):
    """add a path to the libpd search paths

    relative paths are relative to the current working directory
    unlike desktop pd, *no* search paths are set by default (ie. extra)
    """
    lib.libpd_add_to_search_path(path.encode('utf-8'))

#-------------------------------------------------------------------------
# Opening patches

def open_patch(name: str, dir: str = "."):
    """open a patch by filename and parent dir path

    returns a patch id
    """
    ptr = lib.libpd_openfile(name.encode('utf-8'), dir.encode('utf-8'))
    if not ptr:
        raise IOError("unable to open patch: %s/%s" % (dir, name))
    patch_id = lib.libpd_getdollarzero(ptr)
    __LIBPD_PATCHES[patch_id] = ptr
    return patch_id

def close_patch(patch_id):
    """close the open patch givens its id"""
    ptr = __LIBPD_PATCHES[patch_id]
    lib.libpd_closefile(ptr)

#-------------------------------------------------------------------------
# Audio processing

def get_blocksize() -> int:
    """return pd's fixed block size

    the number of sample frames per 1 pd tick
    """
    return lib.libpd_blocksize()

def init_audio(in_channels: int, out_channels: int, sample_rate: int) -> bool:
    """initialize audio rendering

    returns 0 on success
    """
    return lib.libpd_init_audio(in_channels, out_channels, sample_rate) == 0

# def process_float(ticks: int, in_buffer: list[float], out_buffer: list[float]) -> int:
#     """process interleaved float samples from in_buffer -> libpd -> out_buffer

#     buffer sizes are based on # of ticks and channels where:
#         size = ticks * libpd_blocksize() * (in/out)channels
#     returns 0 on success
#     """
#     return lib.libpd_process_float(ticks, in_buffer, out_buffer)


# cdef int process_short(const int ticks, const short *in_buffer, short *out_buffer) nogil:
#     """process interleaved short samples from in_buffer -> libpd -> out_buffer

#     buffer sizes are based on # of ticks and channels where:
#         size = ticks * libpd_blocksize() * (in/out)channels
#     float samples are converted to short by multiplying by 32767 and casting,
#     so any values received from pd patches beyond -1 to 1 will result in garbage
#     note: for efficiency, does *not* clip input
#     returns 0 on success
#     """
#     return lib.libpd_process_short(ticks, in_buffer, out_buffer)

# cdef int process_double(const int ticks, const double *in_buffer, double *out_buffer) nogil:
#     """process interleaved double samples from in_buffer -> libpd -> out_buffer

#     buffer sizes are based on # of ticks and channels where:
#         size = ticks * libpd_blocksize() * (in/out)channels
#     returns 0 on success
#     """
#     return lib.libpd_process_double(ticks, in_buffer, out_buffer)


# cdef int process_raw(const float *in_buffer, float *out_buffer) nogil:
#     """process non-interleaved float samples from in_buffer -> libpd -> out_buffer

#     copies buffer contents to/from libpd without striping
#     buffer sizes are based on a single tick and # of channels where:
#         size = libpd_blocksize() * (in/out)channels
#     returns 0 on success
#     """
#     return lib.libpd_process_raw(in_buffer, out_buffer)


# cdef int process_raw_short(const short *in_buffer, short *out_buffer) nogil:
#     """process non-interleaved short samples from in_buffer -> libpd -> out_buffer

#     copies buffer contents to/from libpd without striping
#     buffer sizes are based on a single tick and # of channels where:
#         size = libpd_blocksize() * (in/out)channels
#     float samples are converted to short by multiplying by 32767 and casting,
#     so any values received from pd patches beyond -1 to 1 will result in garbage
#     note: for efficiency, does *not* clip input
#     returns 0 on success
#     """
#     return lib.libpd_process_raw_short(in_buffer, out_buffer)


# cdef int process_raw_double(const double *in_buffer, double *out_buffer) nogil:
#     """process non-interleaved double samples from in_buffer -> libpd -> out_buffer

#     copies buffer contents to/from libpd without striping
#     buffer sizes are based on a single tick and # of channels where:
#         size = libpd_blocksize() * (in/out)channels
#     returns 0 on success
#     """
#     return lib.libpd_process_raw_double(in_buffer, out_buffer)

# #-------------------------------------------------------------------------
# # Atom operations

def is_float(atom) -> bool:
    """check if an atom is a float type: 0 or 1

    note: no NULL check is performed
    """
    return lib.libpd_is_float(atom) == 1

def is_symbol(atom) -> bool:
    """check if an atom is a symbol type: 0 or 1

    note: no NULL check is performed
    """
    return lib.libpd_is_symbol(atom) == 1

def set_float(atom, f: float):
    """write a float value to the given atom"""
    lib.libpd_set_float(atom, f)

def get_float(atom) -> float:
    """get the float value of an atom

    note: no NULL or type checks are performed
    """
    return lib.libpd_get_float(atom)

def set_symbol(atom, symbol: str):
    """write a symbol value to the given atom.

    requires that libpd_init has already been called.
    """
    lib.libpd_set_symbol(atom, symbol.encode('utf-8'))

def get_symbol(atom):
    """get symbol value of an atom

    note: no NULL or type checks are performed
    """
    return lib.libpd_get_symbol(atom).decode()

def next_atom(atom):
    """increment to the next atom in an atom vector

    returns next atom or NULL, assuming the atom vector is NULL-terminated
    """
    return lib.libpd_next_atom(a)


# #-------------------------------------------------------------------------
# # Array access


def array_size(name: str) -> int:
    """get the size of an array by name

    returns size or negative error code if non-existent
    """
    return lib.libpd_arraysize(name.encode('utf-8'))

def resize_array(name: str, size: int) -> bool:
    """(re)size an array by name sizes <= 0 are clipped to 1

    returns 0 on success or negative error code if non-existent
    """
    return lib.libpd_resize_array(name.encode('utf-8'), size) == 0

def read_array(dest: array.array, name: str, offset: int, n: str) -> bool:
    """read n values from named src array and write into dest starting at an offset

    note: performs no bounds checking on dest
    returns 0 on success or a negative error code if the array is non-existent
    or offset + n exceeds range of array
    """
    return lib.libpd_read_array(dest, name.encode('utf-8'), offset, n) == 0

def write_array(name: str, offset: int, src: array.array, n: int) -> bool:
    """read n values from src and write into named dest array starting at an offset

    note: performs no bounds checking on src
    returns 0 on success or a negative error code if the array is non-existent
    or offset + n exceeds range of array
    """
    return lib.libpd_write_array(name.encode('utf-8'), offset, src, int) == 0

# #-------------------------------------------------------------------------
# # Sending messages to pd

def send_bang(recv: str) -> bool:
    """send a bang to a destination receiver

    ex: send_bang("foo") will send a bang to [s foo] on the next tick
    returns 0 on success or -1 if receiver name is non-existent
    """
    return lib.libpd_bang(recv.encode('utf-8')) == 0

def send_float(recv: str, x: float) -> bool:
    """send a float to a destination receiver

    ex: send_float("foo", 1) will send a 1.0 to [s foo] on the next tick
    returns 0 on success or -1 if receiver name is non-existent
    """
    return lib.libpd_float(recv.encode('utf-8'), x) == 0

def send_symbol(recv: str, symbol: str) -> bool:
    """send a symbol to a destination receiver

    ex: send_symbol("foo", "bar") will send "bar" to [s foo] on the next tick
    returns 0 on success or -1 if receiver name is non-existent
    """
    return lib.libpd_symbol(recv.encode('utf-8'), symbol.encode('utf-8')) == 0

#-------------------------------------------------------------------------
# Sending compound messages: sequenced function calls

def start_message(maxlen: int) -> bool:
    """start composition of a new list or typed message of up to max element length

    messages can be of a smaller length as max length is only an upper bound
    note: no cleanup is required for unfinished messages
    returns 0 on success or nonzero if the length is too large
    """
    return lib.libpd_start_message(maxlen) == 0

def add_float(x: float):
    """add a float to the current message in progress"""
    lib.libpd_add_float(x)

def add_symbol(symbol: str):
    """add a symbol to the current message in progress"""
    lib.libpd_add_symbol(symbol.encode('utf-8'))


#-------------------------------------------------------------------------
# Sending compound messages: atom array

def process_args(args):
    if lib.libpd_start_message(len(args)):
        return -2
    for arg in args:
        if isinstance(arg, str):
            lib.libpd_add_symbol(arg.encode('utf-8'))
        else:
            if isinstance(arg, int) or isinstance(arg, float):
                lib.libpd_add_float(arg)
            else:
                return -1
    return 0

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
    return lib.libpd_finish_list(recv.encode('utf-8')) == 0

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
    return lib.libpd_finish_message(recv.encode('utf-8'), msg.encode('utf-8')) == 0

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
    ptr = lib.libpd_bind(source.encode('utf-8'))
    if source not in __LIBPD_SUBSCRIPTIONS:
        __LIBPD_SUBSCRIPTIONS[source] = ptr

def unsubscribe(source: str):
    """unsubscribe and free a source receiver object created by libpd_bind()"""
    ptr = __LIBPD_SUBSCRIPTIONS[source]
    lib.libpd_unbind(ptr)

def exists(recv: str) -> bool:
    """check if a source receiver object exists with a given name

    returns 1 if the receiver exists, otherwise 0
    """
    return bool(lib.libpd_exists(recv.encode('utf-8')))

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
    lib.libpd_set_printhook(callback)

def set_bang_callback(callback):
    """set the bang receiver callback, NULL by default

    note: do not call this while DSP is running
    """
    lib.libpd_set_banghook(callback)

def set_float_callback(callback):
    """set the float receiver callback, NULL by default

    note: do not call this while DSP is running
    """
    lib.libpd_set_floathook(callback)

def set_double_callback(callback):
    """set the double receiver callback, NULL by default

    note: do not call this while DSP is running
    note: you can either have a double receiver hook, or a float receiver
          hook (see above), but not both.
          calling this, will automatically unset the float receiver hook
    note: only full-precision when compiled with PD_FLOATSIZE=64
    """
    lib.libpd_set_doublehook(callback)

def set_symbol_callback(callback):
    """set the symbol receiver callback, NULL by default

    note: do not call this while DSP is running
    """
    lib.libpd_set_symbolhook(callback)

def set_list_callback(callback):
    """set the list receiver callback, NULL by default

    note: do not call this while DSP is running
    """
    lib.libpd_set_listhook(callback)

def set_message_callback(callback):
    """set the message receiver callback, NULL by default

    note: do not call this while DSP is running
    """
    lib.libpd_set_messagehook(callback)

#-------------------------------------------------------------------------
# Sending MIDI messages to pd

def noteon(channel: int, pitch: int, velocity: int) -> bool:
    """send a MIDI note on message to [notein] objects

    channel is 0-indexed, pitch is 0-127, and velocity is 0-127
    channels encode MIDI ports via: libpd_channel = pd_channel + 16 * pd_port
    note: there is no note off message, send a note on with velocity = 0 instead
    returns 0 on success or -1 if an argument is out of range
    """
    return lib.libpd_noteon(channel, pitch, velocity) == 0

def controlchange(channel: int, controller: int, value: int) -> bool:
    """send a MIDI control change message to [ctlin] objects

    channel is 0-indexed, controller is 0-127, and value is 0-127
    channels encode MIDI ports via: libpd_channel = pd_channel + 16 * pd_port
    returns 0 on success or -1 if an argument is out of range
    """
    return lib.libpd_controlchange(channel, controller, value) == 0

def programchange(channel: int, value: int) -> bool:
    """send a MIDI program change message to [pgmin] objects

    channel is 0-indexed and value is 0-127
    channels encode MIDI ports via: libpd_channel = pd_channel + 16 * pd_port
    returns 0 on success or -1 if an argument is out of range
    """
    return lib.libpd_programchange(channel, value) == 0

def pitchbend(channel: int, value: int) -> bool:
    """send a MIDI pitch bend message to [bendin] objects

    channel is 0-indexed and value is -8192-8192
    channels encode MIDI ports via: libpd_channel = pd_channel + 16 * pd_port
    note: [bendin] outputs 0-16383 while [bendout] accepts -8192-8192
    returns 0 on success or -1 if an argument is out of range
    """
    return lib.libpd_pitchbend(channel, value) == 0

def aftertouch(channel: int, value: int) -> bool:
    """send a MIDI after touch message to [touchin] objects

    channel is 0-indexed and value is 0-127
    channels encode MIDI ports via: libpd_channel = pd_channel + 16 * pd_port
    returns 0 on success or -1 if an argument is out of range
    """
    return lib.libpd_aftertouch(channel, value) == 0

def polyaftertouch(channel: int, pitch: int, value: int) -> bool:
    """send a MIDI poly after touch message to [polytouchin] objects

    channel is 0-indexed, pitch is 0-127, and value is 0-127
    channels encode MIDI ports via: libpd_channel = pd_channel + 16 * pd_port
    returns 0 on success or -1 if an argument is out of range
    """
    return lib.libpd_polyaftertouch(channel, pitch, value) == 0

def midibyte(port: int, byte: int) -> bool:
    """send a raw MIDI byte to [midiin] objects

    port is 0-indexed and byte is 0-256
    returns 0 on success or -1 if an argument is out of range
    """
    return lib.libpd_midibyte(port, byte) == 0

def sysex(port: int, byte: int) -> bool:
    """send a raw MIDI byte to [sysexin] objects

    port is 0-indexed and byte is 0-256
    returns 0 on success or -1 if an argument is out of range
    """
    return lib.libpd_sysex(port, byte) == 0

def sysrealtime(port: int, byte: int) -> bool:
    """send a raw MIDI byte to [realtimein] objects

    port is 0-indexed and byte is 0-256
    returns 0 on success or -1 if an argument is out of range
    """
    return lib.libpd_sysrealtime(port, byte) == 0


#-------------------------------------------------------------------------
# Receiving MIDI messages from pd

def set_noteon_callback(callback):
    """set the MIDI note on callback to receive from [noteout] objects, 
    NULL by default

    note: do not call this while DSP is running
    """
    lib.libpd_set_noteonhook(callback)

def set_controlchange_callback(callback):
    """set the MIDI control change callback to receive from [ctlout] objects,
    NULL by default

    note: do not call this while DSP is running
    """
    lib.libpd_set_controlchangehook(callback)

def set_programchange_callback(callback):
    """set the MIDI program change callback to receive from [pgmout] objects,
    NULL by default

    note: do not call this while DSP is running
    """
    lib.libpd_set_programchangehook(callback)

def set_pitchbend_callback(callback):
    """set the MIDI pitch bend hook to receive from [bendout] objects,
    NULL by default

    note: do not call this while DSP is running
    """
    lib.libpd_set_pitchbendhook(callback)

def set_aftertouch_callback(callback):
    """set the MIDI after touch hook to receive from [touchout] objects,
    NULL by default

    note: do not call this while DSP is running
    """
    lib.libpd_set_aftertouchhook(callback)

def set_polyaftertouch_callback(callback):
    """set the MIDI poly after touch hook to receive from [polytouchout] objects,
    NULL by default

    note: do not call this while DSP is running
    """
    lib.libpd_set_polyaftertouchhook(callback)

def set_midibyte_callback(callback):
    """set the raw MIDI byte hook to receive from [midiout] objects,
    NULL by default

    note: do not call this while DSP is running
    """
    lib.libpd_set_midibytehook(callback)

#-------------------------------------------------------------------------
# Gui

def start_gui(path: str):
    """open the current patches within a pd vanilla GUI

    requires the path to pd's main folder that contains bin/, tcl/, etc
    for a macOS .app bundle: /path/to/Pd-#.#-#.app/Contents/Resources
    returns 0 on success
    """
    return lib.libpd_start_gui(path.encode('utf-8'))

def stop_gui():
    """stop the pd vanilla GUI"""

    lib.libpd_stop_gui()

def poll_gui():
    """manually update and handle any GUI messages

    this is called automatically when using a libpd_process function,
    note: this also facilitates network message processing, etc so it can be
    useful to call repeatedly when idle for more throughput
    """
    lib.libpd_poll_gui()


#-------------------------------------------------------------------------
# Multiple instances

# cdef pd.t_pdinstance *new_instance():
#     """create a new pd instance

#     returns new instance or NULL when libpd is not compiled with PDINSTANCE
#     """
#     return lib.libpd_new_instance()

# cdef void set_instance(pd.t_pdinstance *p):
#     """set the current pd instance

#     subsequent libpd calls will affect this instance only
#     does nothing when libpd is not compiled with PDINSTANCE
#     """
#     lib.libpd_set_instance(p)

# cdef void free_instance(pd.t_pdinstance *p):
#     """free a pd instance

#     does nothing when libpd is not compiled with PDINSTANCE
#     """
#     lib.libpd_free_instance(p)

# cdef pd.t_pdinstance *this_instance():
#     """get the current pd instance"""

#     return lib.libpd_this_instance()

# cdef pd.t_pdinstance *get_instance(int index):
#     """get a pd instance by index

#     returns NULL if index is out of bounds or "this" instance when libpd is not
#     compiled with PDINSTANCE
#     """
#     return lib.libpd_get_instance(index)

# def num_instances() -> int:
#     """get the number of pd instances

#     returns number or 1 when libpd is not compiled with PDINSTANCE
#     """
#     return lib.libpd_num_instances()


#-------------------------------------------------------------------------
# Log level

def get_verbose() -> bool:
    """get verbose print state: 0 or 1"""
    return lib.libpd_get_verbose() == 1

def set_verbose(verbose: bool):
    """set verbose print state: 0 or 1"""
    lib.libpd_set_verbose(int(verbose))

def pd_version() -> str:
    """returns pd version"""
    major = ffi.new('int*')
    minor =  ffi.new('int*')
    bugfix = ffi.new('int*')
    lib.sys_getversion(major, minor, bugfix)
    return f'{major[0]}.{minor[0]}.{bugfix[0]}'

#-------------------------------------------------------------------------
# callbacks


@ffi.def_extern()
def print_callback(s: str):
    print("prnt>>", s.strip())

@ffi.def_extern()
def bang_callback(recv: str):
    print(f"bang>> BANG {recv}")

@ffi.def_extern()
def float_callback(recv: str, f: float):
    print(f"flot>> float {f} {recv}")

@ffi.def_extern()
def symbol_callback(recv: str, sym: str):
    print(f"syml>> symbol {sym} {recv}")

@ffi.def_extern()
def list_callback(recv: str, argc: int, atoms):
    args = list_from_atoms(atoms)
    print(f"list>> list {recv} {args}")

@ffi.def_extern()
def message_callback(recv: str, msg: str, argc: int, atoms):
    args = list_from_atoms(atoms)
    print(f"mssg>> msg {recv} {mst} {args}")

@ffi.def_extern()
def noteon_callback(channel: int, pitch: int, velocity: int):
    print(f"note>> noteon chan: {channel} pitch: {pitch} vel: {velocity}")

@ffi.def_extern()
def controlchange_callback(channel: int, controller: int, value: int):
    print(f"ctlc>> controlchange chan: {channel} controller: {controller} value: {value}")

@ffi.def_extern()
def programchange_callback(channel: int, pitch: int, velocity: int):
    print(f"prgc>> programchange chan: {channel} value: {value}")

@ffi.def_extern()
def pitchbend_callback(channel: int, velocity: int):
    print(f"ptcb>> pitchbend chan: {channel} value: {value}")

@ffi.def_extern()
def aftertouch_callback(channel: int, velocity: int):
    print(f"aftr>> aftertouch chan: {channel} value: {value}")

@ffi.def_extern()
def polyaftertouch_callback(channel: int, pitch: int, value: int):
    print(f"poly>> polyaftertouch chan: {channel} pitch: {pitch} value: {value}")

@ffi.def_extern()
def midibyte_callback(port: int, velocity: int):
    print(f"midi>> midibyte chan: {port} byte: {byte}")


