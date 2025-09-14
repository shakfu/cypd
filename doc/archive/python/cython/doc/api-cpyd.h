""" cypd.pyx

An cythoon extension class wrapping libpd in an 'object-orirented' way.


"""
cimport pd
cimport libpd
cimport libportaudio
from cpython cimport array

from libc.stdio cimport printf, fprintf, stderr, FILE
from posix.unistd cimport sleep

# from libc.string cimport strcpy, strlen
# from libc.stdlib cimport malloc

from collections.abc import Callable


# ----------------------------------------------------------------------------
# constants

DEF N_TICKS = 1
DEF SAMPLE_RATE = 44100
DEF CHANNELS_IN = 1
DEF CHANNELS_OUT = 2
DEF BLOCKSIZE = 64
DEF IN_BUF = CHANNELS_IN * BLOCKSIZE
DEF OUT_BUF = CHANNELS_OUT * BLOCKSIZE
DEF PRERUN_SLEEP = 2000
DEF MAX_ATOMS = 1024


# ----------------------------------------------------------------------------
# helper functions

cdef convert_args(const char *recv, const char *symbol, int argc, pd.t_atom *argv):



# ----------------------------------------------------------------------------
# callback slots

# callbacks
cdef object print_callback = None
cdef object bang_callback = None
cdef object float_callback = None
cdef object double_callback = None
cdef object symbol_callback = None
cdef object list_callback = None
cdef object message_callback = None

# midi callbacks
cdef object noteon_callback = None
cdef object controlchange_callback = None
cdef object programchange_callback = None
cdef object pitchbend_callback = None
cdef object aftertouch_callback = None
cdef object polyaftertouch_callback = None
cdef object midibyte_callback = None
# cdef object sysex_callback = None
# cdef object sysrealtime_callback = None


# ----------------------------------------------------------------------------
# callback hooks

# messaging
cdef void print_callback_hook(const char *s):
cdef void bang_callback_hook(const char *recv):
cdef void float_callback_hook(const char *recv, float f):
cdef void double_callback_hook(const char *recv, double d):
cdef void symbol_callback_hook(const char *recv, const char *symbol):
cdef void list_callback_hook(const char *recv, int argc, pd.t_atom *argv):
cdef void message_callback_hook(const char *recv, const char *symbol, int argc, pd.t_atom *argv):

# midi
cdef void noteon_callback_hook(int channel, int pitch, int velocity):
cdef void controlchange_callback_hook(int channel, int controller, int value):
cdef void programchange_callback_hook(int channel, int value):
cdef void pitchbend_callback_hook(int channel, int value):
cdef void aftertouch_callback_hook(int channel, int value):
cdef void polyaftertouch_callback_hook(int channel, int pitch, int value):
cdef void midibyte_callback_hook(int port, int byte):




# ----------------------------------------------------------------------------
# pure python callbacks

def pd_print(str s):



# ----------------------------------------------------------------------------
# audio configuration

cdef struct UserAudioData:

# globals
cdef UserAudioData data



cdef int audio_callback(const void *inputBuffer, void *outputBuffer,
                        unsigned long framesPerBuffer,
                        const libportaudio.PaStreamCallbackTimeInfo* timeInfo,
                        libportaudio.PaStreamCallbackFlags statusFlags,
                        void *userData ) nogil:


# ----------------------------------------------------------------------------
# main patch class

cdef class Patch:
    # cdef readonly str path
    cdef readonly str name
    cdef readonly str dir
    
    # audio
    cdef readonly int sample_rate
    cdef readonly int blocksize
    cdef readonly int ticks
    cdef readonly int in_channels
    cdef readonly int out_channels

    # patch handle
    cdef void * handle
    cdef bint is_open

    # pointer dicts
    cdef dict patch_dict
    cdef dict recv_dict

    def __cinit__(self, str name, str dir='.')
    def play(self):
    cdef terminate(self, libportaudio.PaError err, void *handle):
    def init(self) -> int:
    def clear_search_path(self):
    def add_to_search_path(self, path: str):
    def open(self):
    def close(self):
    def getdollarzero(self) -> int:
    def get_blocksize(self) -> int:
    def init_audio(self) -> int:

    cdef int process_float(self, const int ticks, const float *in_buffer, float *out_buffer) nogil:
    cdef int process_short(self, const int ticks, const short *in_buffer, short *out_buffer) nogil:
    cdef int process_double(self, const int ticks, const double *in_buffer, double *out_buffer) nogil:
    cdef int process_raw(self, const float *in_buffer, float *out_buffer) nogil:
    cdef int process_raw_short(self, const short *in_buffer, short *out_buffer) nogil:
    cdef int process_raw_double(self, const double *in_buffer, double *out_buffer) nogil:
    
    def array_size(self, name: str) -> int:
    def resize_array(self, name: str, size: int) -> int:
    
    cdef int read_array(self, float *dest, const char *name, int offset, int n):
    cdef int write_array(self, const char *name, int offset, const float *src, int n):
    cdef int read_array_double(self, double *dest, const char *src, int offset, int n):
    cdef int write_array_double(self, const char *dest, int offset, const double *src, int n):
    
    def send_bang(self, receiver: str) -> int:
    def send_float(self, receiver: str, f: float) -> int:
    def send_double(self, receiver: str, f: float) -> int:
    def send_symbol(self, receiver: str, symbol: str) -> int:
    def start_message(self, maxlen: int) -> int:
    def add_float(self, x: float):
    def add_double(self, x: float):
    def add_symbol(self, symbol: str):

    cdef void set_float(self, pd.t_atom *a, float x):
    cdef void set_double(self, pd.t_atom *a, float x):
    cdef void set_symbol(self, pd.t_atom *a, const char *symbol):
    cdef int send_list(self, const char *recv, int argc, pd.t_atom *argv):
    def send_message(self, reciever: str, msg: str, *args) -> int:
    cdef int finish_list(self, const char *recv):
    cdef int finish_message(self, const char *recv, const char *msg):
    
    def dsp(self, on=True):

    def subscribe(self, recv: str):
    def unsubscribe(self, recv: str):
    def exists(self, recv: str) -> int:
    
    def set_print_callback(self, callback: Callable[str]):
    def set_bang_callback(self, callback: Callable[str]):
    def set_float_callback(self, callback: Callable[str, float]):
    def set_double_callback(self, callback: Callable[str, float]):
    def set_symbol_callback(self, callback: Callable[str, str]):
    def set_list_callback(self, callback: Callable[...]):
    def set_message_callback(self, callback: Callable[...]):

    cdef int is_float(self, pd.t_atom *a):
    cdef int is_symbol(self, pd.t_atom *a):
    cdef float get_float(self, pd.t_atom *a):
    cdef double get_double(self, pd.t_atom *a):
    cdef const char *get_symbol(self, pd.t_atom *a):
    cdef pd.t_atom *next_atom(self, pd.t_atom *a):
    
    def noteon(self, channel: int , pitch: int, velocity: int) -> int:
    def controlchange(self, channel: int, controller: int, value: int) -> int:
    def programchange(self, channel: int, value: int) -> int:
    def pitchbend(self, channel: int, value: int) -> int:
    def aftertouch(self, channel: int, value: int) -> int:
    def polyaftertouch(self, channel: int, pitch: int, value: int) -> int:
    def midibyte(self, port: int, byte: int) -> int:
    def sysex(self, port: int, byte: int) -> int:
    def sysrealtime(self, port: int, byte: int) -> int:

    def set_noteon_callback(self, callback):
    def set_controlchange_callback(self, callback):
    def set_programchange_callback(self, callback):
    def set_pitchbend_callback(self, callback):
    def set_aftertouch_callback(self, callback):
    def set_polyaftertouch_callback(self, callback):
    def set_midibyte_callback(self, callback):
    def start_gui(self, str path):
    def stop_gui(self):
    def poll_gui(self):

    # cdef pd.t_pdinstance *new_instance(self):
    # cdef void set_instance(self, pd.t_pdinstance *p):
    # cdef void free_instance(self, pd.t_pdinstance *p):
    # cdef pd.t_pdinstance *this_instance(self):
    # cdef pd.t_pdinstance *get_instance(self, int index):
    # def num_instances(self) -> int:

    def get_verbose(self) -> int:
    def set_verbose(self, verbose: int):
    def pd_version(self) -> str:


