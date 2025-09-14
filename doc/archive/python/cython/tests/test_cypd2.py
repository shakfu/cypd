
import sys
from os.path import dirname

sys.path.insert(0, dirname(dirname(__file__)))

import cypd


p = cypd.Patch(name='test2.pd', dir='tests/pd')

p.init_hooks()
p.init()
p.play()
