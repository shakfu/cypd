
import sys
from os.path import dirname

sys.path.insert(0, dirname(dirname(__file__)))

import libpd


libpd.play(name='test.pd', dir='tests/pd')
