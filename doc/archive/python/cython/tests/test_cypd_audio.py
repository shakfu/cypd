#!/usr/bin/env python3

import sys
from os.path import dirname

sys.path.insert(0, dirname(dirname(__file__)))


import cypd

if __name__ == '__main__':
    if len(sys.argv) < 2:
        pdfile = 'test.pd'
    else:
        pdfile = sys.argv[1]
    print(f'pdfile: {pdfile}')    
    p = cypd.Patch(name=pdfile, dir='tests/pd')
    p.play()
