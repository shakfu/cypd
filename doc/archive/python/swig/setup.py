#!/usr/bin/env python3

from distutils.core import setup, Extension

setup(name='pypdlib',
      version='0.12',
      py_modules = ['pylibpd'],
      ext_modules = [
        Extension("_pylibpd",
            define_macros = [
                ('PD', 1),
                ('HAVE_UNISTD_H', 1),
                ('HAVE_LIBDL', 1),
                ('USEAPI_DUMMY', 1),
                ('LIBPD_EXTRA', 1)
            ],
            include_dirs = [
                '../../libpd_wrapper',
                '../../pure-data/src',
            ],
            library_dirs = [
                '/usr/local/lib',
                '../../libs',
            ],
            libraries = [
                'm',
                'dl',
                'pthread'
            ],
            extra_objects = [
                '../../libs/libpd.a',
            ],
            sources = [
                'pylibpd.i',
            ],
        )
    ]
)

