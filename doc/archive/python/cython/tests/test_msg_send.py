import sys
from os.path import dirname
from time import sleep

sys.path.insert(0, dirname(dirname(__file__)))

from cypd import Patch

p = Patch("test_msg_send.pd", "tests/pd")
p.init_hooks()
p.init()

p.open()

assert p.is_open
print('patch is open')

print('testing send_float')
p.send_bang('mybang')
sleep(1)


print('testing send_float')
p.send_float('myfloat', 12.1)
sleep(1)


print('testing send_symbol')
p.send_symbol('mysymbol', "hello")
sleep(1)

print('testing send_list')
p.send_list('mylist', "a", "b", "c", 1, 2, 3)
sleep(1)

print('testing send_message')
p.send_message('mymessage', "foo", "x", "y", "z", 4, 5, 6)
sleep(1)


p.close()
