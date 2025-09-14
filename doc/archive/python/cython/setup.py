import os
from distutils.core import setup
from distutils.extension import Extension

from Cython.Build import cythonize

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
    # ('PDINSTANCE', 1),   # compile with multi-instance support
    # ('PDTHREADS', 1),    # compile with per-thread storage for global variables, required for multi-instance support
    # ('PD_FLOATSIZE', 1), # set the float precision, 32 (default) or 64, ex. `PD_FLOATSIZE=64`
]

INCLUDE_DIRS = [
    "/usr/local/include",
    "../../libpd_wrapper",
    "../../libpd_wrapper/util",
    "../../pure-data/src",
    "../../pure-data/portaudio/portaudio/include",
    "../../pure-data/portaudio/portaudio/src/common",
]

LIBRARIES = [
    'm',
    'dl',
    'pthread',
    # 'portaudio', # requires portaudio to be installed system-wide
]

LIBRARY_DIRS = [
    '/usr/local/lib',
    '../../libs',
]

EXTRA_OBJECTS = [
    '../../libs/libpd.a',
    '../../libs/libportaudio.a',
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
