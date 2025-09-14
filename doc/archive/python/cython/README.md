# pyx: Experimental Cython branch of libpd

Using cython to make a more 'hackable' python implementation of libpd.


## Requirements

- python3

- cython: `pip3 install cython`


## Objectives

- Provide a cython-based 'more hackable' alternative to the swig-based pylibpd

- Builtin integration with `portaudio` or alternative (`miniaudio?`)

- Should be easy to use in ipython for scripting headless puredata

- Should perform without observable audio artifacts

  - `nogil` for audio processing functions

- Provide two implementations:

  - Functional implentation: essentially a module with functions

  - Object-Oriented implementation: a more 'pythonic' approach with classes


## Status

The project provides access to the two relevant apis via cython `pxd` files:

1. puredata: the `m_pd` header api is made available to `cython` code via `pd.pxd`.

2. libpd: the`libpd` api is made available to `cython` code via `libpd.pxd`.


There are currently two different independent implementations which are variations of pretty much the same codebase to make the `libpd` api accessible to python:

1. `libpd.pyx` -- **functional api** -- `libpd` functions implemented in a python extension module

2. `cypd.pyx` -- **object-oriented api** (should check out the cpp version for comparison)

The `portaudio` library is made available in the libpd repo via `pure-data` in `pure-data/portaudio`. A static library of `portaudio`, `libportaudio.a` is compiled as a dependency (see `libportaudio.mk`) and statically linked to the above cython extensions.

This enables both implementation variants to generate sound from a pd patch without relying on an external dependency like`pyaudio` as is the case with the swig-based `pylibpd`.



