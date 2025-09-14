import sys
from os.path import dirname
from time import sleep

sys.path.insert(0, dirname(dirname(__file__)))

from cypd import Patch

p = Patch("test_msg_bind.pd", "tests/pd")
p.init_hooks()
p.init()

p.open()

assert p.is_open
print('patch is open')

print("check if an 'option' receiver exists")
assert p.exists('option')

#print("the `.exists()` test method does not work for senders")
#assert not p.exists('dispatch')

print("binding 'dispatch' sender object")
p.subscribe('dispatch')

# print('testing send_float')
# p.send_float('myfloat', 12.1)
# sleep(1)


# p.close()
