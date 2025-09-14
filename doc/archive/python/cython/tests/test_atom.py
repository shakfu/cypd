import sys
from os.path import dirname
sys.path.insert(0, dirname(dirname(__file__)))

import cypd

cypd.test_Atom()
