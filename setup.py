import os
import shlex
import subprocess
import platform

from setuptools import Extension, setup
from Cython.Build import cythonize

PLATFORM = platform.system()

def get_output(cmd: str) -> str:
    return subprocess.check_output(shlex.split(cmd)).decode().strip()

if PLATFORM == "Darwin":
    LOCAL_PREFIX = get_output("brew --prefix")

    os.environ['LDFLAGS'] = " ".join([
        "-framework CoreServices",
        "-framework CoreFoundation",
        "-framework AudioUnit",
        "-framework AudioToolbox",
        "-framework CoreAudio",
    ])

if PLATFORM == "Linux":
    LOCAL_PREFIX = "/usr/local"


DEFINE_MACROS = [
    ('PD', 1),
    ('HAVE_UNISTD_H', 1),
    ('HAVE_LIBDL', 1),
    ('USEAPI_DUMMY', 1),
    ('LIBPD_EXTRA', 1),
    # ('PDINSTANCE', 1),   # compile with multi-instance support
    # ('PDTHREADS', 1),    # compile with per-thread storage for global variables, required for multi-instance support
    # ('PD_FLOATSIZE', 1), # set the float precision, 32 (default) or 64, ex. `PD_FLOATSIZE=64`
]

INCLUDE_DIRS = [
    f"{LOCAL_PREFIX}/include",
    "thirdparty/pure-data/include",
    "thirdparty/portaudio/include",
    "thirdparty/portmidi/include",
]

LIBRARIES = [
    'm',
    'dl',
    'pthread',
    # 'portaudio', # requires portaudio to be installed system-wide
]

LIBRARY_DIRS = [
    f"{LOCAL_PREFIX}/lib",
    "thirdparty/pure-data/lib"
]

EXTRA_OBJECTS = [
    "thirdparty/pure-data/lib/libpd.a",
    f"{LOCAL_PREFIX}/lib/libportaudio.a",
]


CYPD_EXTENSION = Extension("cypd", ["cypd.pyx"],
    define_macros = DEFINE_MACROS,
    include_dirs = INCLUDE_DIRS,
    libraries = LIBRARIES,
    library_dirs = LIBRARY_DIRS,
    extra_objects = EXTRA_OBJECTS,
)

LIBPD_EXTENSION = Extension("libpd", ["libpd.pyx"],
    define_macros = DEFINE_MACROS,
    include_dirs = INCLUDE_DIRS,
    libraries = LIBRARIES,
    library_dirs = LIBRARY_DIRS,
    extra_objects = EXTRA_OBJECTS,
)

extensions = []

if os.getenv('CYPD'):
    extensions.append(CYPD_EXTENSION)

elif os.getenv('LIBPD'):
    extensions.append(LIBPD_EXTENSION)

elif os.getenv('DEMO'):
    import numpy

    DEMO_EXTENSION = Extension("demo", ["demo.pyx", "tests/task.c"],
        define_macros = DEFINE_MACROS,
        include_dirs = INCLUDE_DIRS + [numpy.get_include()],
        libraries = LIBRARIES,
        library_dirs = LIBRARY_DIRS,
        extra_objects = EXTRA_OBJECTS,
    )

    extensions.append(DEMO_EXTENSION)

else:
    extensions.extend([
        CYPD_EXTENSION,
        LIBPD_EXTENSION,
    ])

setup(
    name="pd in cython",
    ext_modules=cythonize(extensions, 
        compiler_directives={
            'language_level' : '3',
            'embedsignature': True,
            # 'cdivision': True,      # use C division instead of Python
            # 'boundscheck': True,    # check arrays boundaries
            # 'wraparound': False,    # allow negative indexes to fetch the end of an array

        }),
    zip_safe=False,
)
