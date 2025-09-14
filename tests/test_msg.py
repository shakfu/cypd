import sys
from os.path import dirname
from time import sleep

sys.path.insert(0, dirname(dirname(__file__)))

from cypd import Patch

def print_receive(*s):
  print('print_receive:', s)

def float_receive(*s):
  print('float_receive:', s)

def list_receive(*s):
  print('list_receive:', s)

def symbol_receive(*s):
  print('symbol_receive:', s)

def noteon_receive(*s):
  print('noteon_receive:', s)

# libpd_set_print_callback(print_receive)
# libpd_set_float_callback(float_receive)
# libpd_set_list_callback(list_receive)
# libpd_set_symbol_callback(symbol_receive)
# libpd_set_noteon_callback(noteon_receive)


p = Patch("test_msg.pd", "tests/pd")
p.init_hooks()
p.init()


# assert p.is_open
# print('patch is open')

# print("check if an 'option' receiver exists")
# assert p.exists('option')

#print("the `.exists()` test method does not work for senders")
#assert not p.exists('dispatch')

print("binding 'eggs' sender object")
p.subscribe('eggs')

p.open()

p.send_float('spam', 42)
p.send_symbol('spam', "don't panic")
p.send_list('spam', 'test', 1, 'foo', 2)


# print('testing send_float')
# p.send_float('myfloat', 12.1)
# sleep(1)

p.unsubscribe('eggs')
p.close()




# libpd_subscribe('eggs')

# m = PdManager(1, 2, 44100, 1)
# patch = libpd_open_patch('test.pd', '.')
# print("$0: ", patch)

# libpd_float('spam', 42)
# libpd_symbol('spam', "don't panic")
# libpd_list('spam', 'test', 1, 'foo', 2)

# libpd_release()

