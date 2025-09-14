import sys
from os.path import dirname

sys.path.insert(0, dirname(dirname(__file__)))

from cypd import Patch

p = Patch("test5.pd", "tests/pd")
p.init_hooks()
p.init()
p.open()

p.subscribe("eggs")

p.send_float("spam", 42)
p.send_symbol("spam", "don't panic")
# p.send_list("spam", "test", 1, "foo", 2)

p.unsubscribe("eggs")

# FIXME: hanging for cypd (not and for pylib-)