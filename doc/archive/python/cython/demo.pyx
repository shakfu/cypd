# demo.pyx
"""
This file tests array access and conversion as well as memoryviews


"""

cimport pd
cimport libpd
cimport libportaudio

from libc.string cimport strcpy, strlen

from cpython cimport array
import array

import numpy as np
cimport numpy as np
np.import_array()

DEF N_TICKS = 1
DEF CHANNELS = 1
DEF BLOCKSIZE = 64
DEF BUFFSIZE = N_TICKS * BLOCKSIZE * CHANNELS


# ----------------------------------------------------------------------------
# generic

def dump(float[:] view):
    for i in range(BUFFSIZE):
        print(i, view[i])

cdef void zero(float[:] view):
    view[:] = 0.0
    # also
    # view[...] = 0.0

# cdef void zero(float *buf):
#     for i in range(BUFFSIZE):
#         buf[i] = 0.0

# ----------------------------------------------------------------------------
# test c float array directly

cdef int process_float(const float *in_buffer, float *out_buffer):
    for i in range(BUFFSIZE):
        out_buffer[i] = in_buffer[i] + 5.1
    return 0

def test_c_array():
    cdef float inbuf[BUFFSIZE]
    cdef float outbuf[BUFFSIZE]
    # writing directly to c-buffer
    zero(inbuf)
    zero(outbuf)
    process_float(inbuf, outbuf)
    return <list>outbuf


# ----------------------------------------------------------------------------
# test c float array using memoryviews


cdef int process_float_view(float[:] in_buffer, float[:] out_buffer):
    for i in range(BUFFSIZE):
        out_buffer[i] = in_buffer[i] + 5.1
    return 0

def test_c_array_view():
    cdef float inbuf[BUFFSIZE]
    cdef float outbuf[BUFFSIZE]
    # writing directly to c-buffer
    zero(inbuf)
    zero(outbuf)
    process_float_view(inbuf, outbuf)
    return outbuf

# ----------------------------------------------------------------------------
# test float array.array using memoryviews


def test_python_array_view():
    cdef array.array inbuf = array.array('f', [0.0]*BUFFSIZE)
    cdef array.array outbuf = array.array('f', [0.0]*BUFFSIZE)
    process_float_view(inbuf, outbuf)
    return outbuf


# ----------------------------------------------------------------------------
# test float numpy ndarray using memoryviews

DTYPE = np.float32

def test_numpy_array_view():
    inbuf = np.zeros(BUFFSIZE, dtype=DTYPE)
    outbuf = np.zeros(BUFFSIZE, dtype=DTYPE)
    process_float_view(inbuf, outbuf)
    return outbuf

# ----------------------------------------------------------------------------
# test for equivalence

assert sum(test_c_array()) == sum(test_python_array_view())
assert sum(test_c_array()) == sum(test_numpy_array_view())

# ----------------------------------------------------------------------------
# test regular c buffer interface

def process_buffer_view(float[:] in_buffer not None, float[:] out_buffer = None):
    if out_buffer is None:
        out_buffer = in_buffer[:] # full copy
        # also the below is valid
        # out_buffer = in_buffer.copy()
    cdef int i
    for i in range(out_buffer.size):
        out_buffer[i] += 1.5
    return out_buffer

def test_c_array_view_interface():
    """returns memory view or `array`"""
    cdef float buf[BUFFSIZE]
    cdef float[:] buf_view = buf
    zero(buf)
    for i in range(BUFFSIZE):
        assert buf[i] == 0.0
    buf_view[:] = 1.0
    for i in range(BUFFSIZE):
        assert buf[i] == 1.0
    return process_buffer_view(buf_view)


# ----------------------------------------------------------------------------
# test python array.array buffer interface


def gen_array_conversion_scenario(n=0):
    cdef float c_array[BUFFSIZE]
    cdef array.array py_array = array.array('f', range(BUFFSIZE))
    np_array = np.zeros(BUFFSIZE, dtype=DTYPE)
    cdef float[:] arr_view = py_array
    cdef int i

    # populate arrays with different values (for comparison)
    for i in range(BUFFSIZE):
        py_array[i] = 1.0
        c_array[i]  = 2.0
    
    # this is sufficient for numpy's vectorized ops
    np_array[:] = 3.0

    if n==1:
        arr_view[:] = c_array
    if n==2:
        arr_view = np_array[:]

    # default (n=0) to return py_array
    return arr_view


def test_array_conversions():
    py_array_view = gen_array_conversion_scenario(0)
    c_array_view  = gen_array_conversion_scenario(1)
    np_arrav_view = gen_array_conversion_scenario(2)

    assert py_array_view[0] == 1.0
    assert c_array_view[0]  == 2.0
    assert np_arrav_view[0] == 3.0


# ----------------------------------------------------------------------------
# test numpy buffer interface

# narr = np.arange(BUFFSIZE, dtype=np.dtype("f"))
narr = np.random.random(BUFFSIZE).astype("f")
cdef float [:] narr_view = narr

dump_narr = lambda: dump(narr_view)


# ----------------------------------------------------------------------------
# test process function wrapping buffer interface
# 
# different ways of wrapping libpd.libpd_process_float
# 
# these forms are unecessary and inelegant

# cdef object _wrap_libpd_process_float(object py_ticks, object py_inbuff, object py_outbuf):
#     cdef int ticks = <int>py_ticks
#     cdef float *inbuff = <float *>py_inbuff 
#     cdef float *outbuf = <float *>py_outbuf
#     cdef int result
#     cdef Py_ssize_t dummy1
#     cdef Py_ssize_t dummy2
    
#     if (PyObject_AsReadBuffer(py_inbuff, <void **>&inbuff, &dummy1)):
#         return NULL  
    
#     if (PyObject_AsWriteBuffer(py_outbuf, <void **>&outbuf, &dummy2)):
#         return NULL  
  
#     result = <int>libpd_process_float(ticks, <float *>inbuff, outbuf)
#     return int(result)


cdef int process_float_0(int ticks, float[:] in_buffer, float[:] out_buffer):
    cdef float[BUFFSIZE] inbuff
    cdef float[BUFFSIZE] outbuff
    cdef int result
    inbuf = in_buffer[:]
    outbuf = out_buffer[:]
    result = libpd.libpd_process_float(<int>ticks, <const float*>inbuff, <float*>outbuff)
    return result


cdef int process_float_0_alt(int ticks, float[:] in_buffer, float[:] out_buffer):
    cdef float* inbuff = NULL
    cdef float* outbuff = NULL
    cdef int result
    inbuf = in_buffer[:]
    outbuf = out_buffer[:]
    result = libpd.libpd_process_float(ticks, inbuff, outbuff)
    return result

def process_float_1(int ticks, float[::1] in_buffer, float[::1] out_buffer):
    cdef float[BUFFSIZE] inbuff
    cdef float[BUFFSIZE] outbuff # these have to proper size 
    inbuf = in_buffer[:]
    outbuf = out_buffer[:]
    libpd.libpd_process_float(ticks, inbuff, outbuff)
    return 0


def process_float_2(int ticks, float[:] in_buffer, float[:] out_buffer):
    cdef float[BUFFSIZE] inbuff
    cdef float[BUFFSIZE] outbuff # these have to proper size 
    inbuf = in_buffer[:]
    outbuf = out_buffer[:]
    libpd.libpd_process_float(ticks, inbuff, outbuff)
    return 0


cpdef process_float_x1(int ticks, float[:] in_buffer, float[:] out_buffer = None):
    cdef float[BUFFSIZE] inbuff
    cdef float[BUFFSIZE] outbuff
    cdef int i
    if out_buffer is None:
        out_buffer = array.array('f', [0.0] * BUFFSIZE)

    for i in range(BUFFSIZE):
        inbuff[i] = in_buffer[i]
        outbuff[i] = out_buffer[i]

    libpd.libpd_process_float(ticks, <const float*>inbuff, <float*>outbuff)
    return out_buffer


def process_float_x2(int ticks, array.array in_buffer, array.array out_buffer = None):
    cdef float[:] in_buffer_view = in_buffer
    cdef float[:] out_buffer_view = out_buffer
    if out_buffer is None:
        out_buffer_view[:] = array.array('f', [0.0] * BUFFSIZE)
    cdef float[BUFFSIZE] inbuff;
    cdef float[BUFFSIZE] outbuff;
    cdef float[:] inbuff_view = inbuff
    cdef float[:] outbuff_view = outbuff
    inbuff_view[:] = in_buffer_view
    outbuff_view[:] = out_buffer_view
    libpd.libpd_process_float(ticks, <const float*>inbuff, <float*>outbuff)
    return out_buffer

def process_float_x3(int ticks, array.array in_buffer, array.array out_buffer = None):
    cdef float[BUFFSIZE] inbuff
    cdef float[BUFFSIZE] outbuff
    cdef int i
    if out_buffer is None:
        out_buffer = array.array('f', [0.0] * BUFFSIZE)

    for i in range(BUFFSIZE):
        inbuff = in_buffer[i]
        outbuff = out_buffer[i]

    libpd.libpd_process_float(ticks, <const float*>inbuff, <float*>outbuff)
    return out_buffer


# ----------------------------------------------------------------------------
# test cplay

cdef extern from "tests/task.h" nogil:
    int cplay(char* name, char* dir)


def play(name: str, dir: str):
    cdef char[512] filename
    cdef char[512] dirname

    strcpy(filename, name.encode('utf-8'))
    strcpy(dirname, dir.encode('utf-8'))

    with nogil:
        cplay(filename, dirname)






