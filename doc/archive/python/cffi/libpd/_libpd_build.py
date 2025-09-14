import os

from cffi import FFI
ffibuilder = FFI()

os.environ['LDFLAGS'] = " ".join([
    "-framework CoreServices",
    "-framework CoreFoundation",
    "-framework AudioUnit",
    "-framework AudioToolbox",
    "-framework CoreAudio",
])

DEFINE_MACROS = [
    ('PD', 1),
    ('HAVE_UNISTD_H', 1),
    ('HAVE_LIBDL', 1),
    ('USEAPI_DUMMY', 1),
    ('LIBPD_EXTRA', 1),
]

INCLUDE_DIRS = [
    "/usr/local/include",
    "../../libpd_wrapper",
    "../../libpd_wrapper/util",
    "../../pure-data/src",
]

LIBRARIES = [
    'm',
    'dl',
    'pthread',
    'portaudio', # requires portaudio to be installed system-wide
]

LIBRARY_DIRS = [
    '/usr/local/lib',
    '../../libs',
]

EXTRA_OBJECTS = [
    '../../libs/libpd.a',
]



# set_source() gives the name of the python extension module to
# produce, and some C source code as a string.  This C code needs
# to make the declarated functions, types and globals available,
# so it is often just the "#include".
ffibuilder.set_source("libpd._libpd",
"""
#include "../../pure-data/src/m_pd.h"              // puredata api 

#include "../../libpd_wrapper/z_libpd.h"           // libpd core api
#include "../../libpd_wrapper/util/z_queued.h"     // libpd extended queued api
#include "../../libpd_wrapper/util/z_print_util.h" // libpd extended print_util api

// --------------------------------------------------------------------------
// custom

void compute_audio(int x)
{
    libpd_start_message(1);
    libpd_add_float(x);
    libpd_finish_message("pd", "dsp");
}
""",
    define_macros = DEFINE_MACROS,
    include_dirs = INCLUDE_DIRS,
    libraries = LIBRARIES,
    library_dirs = LIBRARY_DIRS,
    extra_objects = EXTRA_OBJECTS,
)



# cdef() expects a single string declaring the C types, functions and
# globals needed to use the shared object. It must be in valid C syntax.
ffibuilder.cdef("""
// libpd api reference

// --------------------------------------------------------------------------
// m_pd.h

typedef enum
{
    A_NULL,
    A_FLOAT,
    A_SYMBOL,
    A_POINTER,
    A_SEMI,
    A_COMMA,
    A_DEFFLOAT,
    A_DEFSYM,
    A_DOLLAR,
    A_DOLLSYM,
    A_GIMME,
    A_CANT
}  t_atomtype;

typedef struct _atom
{
    t_atomtype a_type;
    ...;
} t_atom;

void sys_getversion(int *major, int *minor, int *bugfix);

// --------------------------------------------------------------------------
// z_libpd.h

// init
int libpd_init();
void libpd_clear_search_path();
void libpd_add_to_search_path(const char *path);

// opening patches
void *libpd_openfile(const char *name, const char *dir);
void libpd_closefile(void *p);
int libpd_getdollarzero(void *p);

// audio processing
int libpd_blocksize();
int libpd_init_audio(int inChannels, int outChannels, int sampleRate);
int libpd_process_float(const int ticks, const float *inBuffer, float *outBuffer);
int libpd_process_short(const int ticks, const short *inBuffer, short *outBuffer);
int libpd_process_double(const int ticks, const double *inBuffer, double *outBuffer);
int libpd_process_raw(const float *inBuffer, float *outBuffer);
int libpd_process_raw_short(const short *inBuffer, short *outBuffer);
int libpd_process_raw_double(const double *inBuffer, double *outBuffer);

// array access
int libpd_arraysize(const char *name);
int libpd_resize_array(const char *name, long size);
int libpd_read_array(float *dest, const char *name, int offset, int n);
int libpd_write_array(const char *name, int offset, const float *src, int n);
int libpd_read_array_double(double *dest, const char *src, int offset, int n);
int libpd_write_array_double(const char *dest, int offset, const double *src, int n);

// sending messages to pd
int libpd_bang(const char *recv);
int libpd_float(const char *recv, float x);
int libpd_double(const char *recv, double x);
int libpd_symbol(const char *recv, const char *symbol);

// sending compound messages: sequenced function calls
int libpd_start_message(int maxlen);
void libpd_add_float(float x);
void libpd_add_double(double x);
void libpd_add_symbol(const char *symbol);
int libpd_finish_list(const char *recv);
int libpd_finish_message(const char *recv, const char *msg);

// sending compound messages: atom array
void libpd_set_float(t_atom *a, float x);
void libpd_set_double(t_atom *v, double x);
void libpd_set_symbol(t_atom *a, const char *symbol);
int libpd_list(const char *recv, int argc, t_atom *argv);
int libpd_message(const char *recv, const char *msg, int argc, t_atom *argv);


// receiving messages from pd
void *libpd_bind(const char *recv);
void libpd_unbind(void *p);
int libpd_exists(const char *recv);
typedef void (*t_libpd_printhook)(const char *s);
typedef void (*t_libpd_banghook)(const char *recv);
typedef void (*t_libpd_floathook)(const char *recv, float x);
typedef void (*t_libpd_doublehook)(const char *recv, double x);
typedef void (*t_libpd_symbolhook)(const char *recv, const char *symbol);
typedef void (*t_libpd_listhook)(const char *recv, int argc, t_atom *argv);
typedef void (*t_libpd_messagehook)(const char *recv, const char *msg, int argc, t_atom *argv);

void libpd_set_printhook(const t_libpd_printhook hook);
void libpd_set_banghook(const t_libpd_banghook hook);
void libpd_set_floathook(const t_libpd_floathook hook);
void libpd_set_doublehook(const t_libpd_doublehook hook);
void libpd_set_symbolhook(const t_libpd_symbolhook hook);
void libpd_set_listhook(const t_libpd_listhook hook);
void libpd_set_messagehook(const t_libpd_messagehook hook);
int libpd_is_float(t_atom *a);
int libpd_is_symbol(t_atom *a);
float libpd_get_float(t_atom *a);
double libpd_get_double(t_atom *a);
const char *libpd_get_symbol(t_atom *a);
t_atom *libpd_next_atom(t_atom *a);


// sending MIDI messages to pd
int libpd_noteon(int channel, int pitch, int velocity);
int libpd_controlchange(int channel, int controller, int value);
int libpd_programchange(int channel, int value);
int libpd_pitchbend(int channel, int value);
int libpd_aftertouch(int channel, int value);
int libpd_polyaftertouch(int channel, int pitch, int value);
int libpd_midibyte(int port, int byte);
int libpd_sysex(int port, int byte);
int libpd_sysrealtime(int port, int byte);

// receiving MIDI messages from pd
typedef void (*t_libpd_noteonhook)(int channel, int pitch, int velocity);
typedef void (*t_libpd_controlchangehook)(int channel, int controller, int value);
typedef void (*t_libpd_programchangehook)(int channel, int value);
typedef void (*t_libpd_pitchbendhook)(int channel, int value);
typedef void (*t_libpd_aftertouchhook)(int channel, int value);
typedef void (*t_libpd_polyaftertouchhook)(int channel, int pitch, int value);
typedef void (*t_libpd_midibytehook)(int port, int byte);
void libpd_set_noteonhook(const t_libpd_noteonhook hook);
void libpd_set_controlchangehook(const t_libpd_controlchangehook hook);
void libpd_set_programchangehook(const t_libpd_programchangehook hook);
void libpd_set_pitchbendhook(const t_libpd_pitchbendhook hook);
void libpd_set_aftertouchhook(const t_libpd_aftertouchhook hook);
void libpd_set_polyaftertouchhook(const t_libpd_polyaftertouchhook hook);
void libpd_set_midibytehook(const t_libpd_midibytehook hook);

// GUI
int libpd_start_gui(const char *path);
void libpd_stop_gui();
int libpd_poll_gui();

// log level
void libpd_set_verbose(int verbose);
int libpd_get_verbose();

// ---------------------------------------------------------------------------
// extended api: util/z_queued.h

// extended queued api
void libpd_set_queued_printhook(const t_libpd_printhook hook);
void libpd_set_queued_banghook(const t_libpd_banghook hook);
void libpd_set_queued_floathook(const t_libpd_floathook hook);
void libpd_set_queued_doublehook(const t_libpd_doublehook hook);
void libpd_set_queued_symbolhook(const t_libpd_symbolhook hook);
void libpd_set_queued_listhook(const t_libpd_listhook hook);
void libpd_set_queued_messagehook(const t_libpd_messagehook hook);
void libpd_set_queued_noteonhook(const t_libpd_noteonhook hook);
void libpd_set_queued_controlchangehook(const t_libpd_controlchangehook hook);
void libpd_set_queued_programchangehook(const t_libpd_programchangehook hook);
void libpd_set_queued_pitchbendhook(const t_libpd_pitchbendhook hook);
void libpd_set_queued_aftertouchhook(const t_libpd_aftertouchhook hook);
void libpd_set_queued_polyaftertouchhook(const t_libpd_polyaftertouchhook hook);
void libpd_set_queued_midibytehook(const t_libpd_midibytehook hook);
int libpd_queued_init();
void libpd_queued_release();
void libpd_queued_receive_pd_messages();
void libpd_queued_receive_midi_messages();

// ---------------------------------------------------------------------------
// extended api: util/z_print_util.h

// extended print_util api
void libpd_set_concatenated_printhook(const t_libpd_printhook hook);
void libpd_print_concatenator(const char *s);

// --------------------------------------------------------------------------
// custom

void compute_audio(int x);

// --------------------------------------------------------------------------
// callbacks

extern "Python" void print_callback(const char *s);
extern "Python" void bang_callback(const char *recv);
extern "Python" void float_callback(const char *recv, float x);
extern "Python" void double_callback(const char *recv, double x);
extern "Python" void symbol_callback(const char *recv, const char *symbol);
extern "Python" void list_callback(const char *recv, int argc, t_atom *argv);
extern "Python" void message_callback(const char *recv, const char *msg, int argc, t_atom *argv);

extern "Python" void noteon_callback(int channel, int pitch, int velocity);
extern "Python" void controlchange_callback(int channel, int controller, int value);
extern "Python" void programchange_callback(int channel, int value);
extern "Python" void pitchbend_callback(int channel, int value);
extern "Python" void aftertouch_callback(int channel, int value);
extern "Python" void polyaftertouch_callback(int channel, int pitch, int value);
extern "Python" void midibyte_callback(int port, int byte);

""")

if __name__ == "__main__":    # not when running with setuptools
    ffibuilder.compile(verbose=True)

