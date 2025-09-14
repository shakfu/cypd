import sys
from os.path import dirname
import array

sys.path.insert(0, dirname(dirname(__file__)))

import libpd

# def pd_receive(*s):
#   print('received:', s)

# libpd.set_print_callback(pd_receive)
# libpd.set_float_callback(pd_receive)
# libpd.set_list_callback(pd_receive)
# libpd.set_symbol_callback(pd_receive)
# libpd.set_noteon_callback(pd_receive)

libpd.init_hooks()

libpd.init() # if not here then seg fault
libpd.subscribe('eggs')

# m = libpd.PdManager(1, 2, 44100, 1)
patch = libpd.open_patch('test_full.pd', 'tests/pd')
print("$0: ", patch)

libpd.send_float('spam', 42)
libpd.send_symbol('spam', "don't panic")
libpd.send_list('spam', 'test', 1, 'foo', 2)

# buf = array.array('f', range(64))
# print("array size:", libpd.arraysize("array1"))
# print("array size:", libpd.arraysize("?????"))  # doesn't exist
# print(libpd.read_array(buf, "array1", 0, 64))
# print(buf)

# inbuf = array.array('h', range(64))
# outbuf = m.process(inbuf)
# print(outbuf)

# buf = array.array('f', map(lambda x : x / 64.0, range(64)))
# print(libpd.write_array("array1", 0, buf, 64))

# outbuf = m.process(inbuf)
# print(outbuf)

libpd.release()
