# -*- coding: utf-8 -*-
"""
Created on Sat Sep 15 17:22:15 2018

@author: jange
"""

def iterPower(base, exp):
    '''
    base: int or float.
    exp: int >= 0
 
    returns: int or float, base^exp
    '''
    x = base
    if exp == 0:
        base = 1
    else:
        while (exp > 1):
            base = base * x
            exp -= 1
        
    return base

import math
def polysum(n,s):
    area=(0.25*n*(s**2))/math.tan(math.pi/n)
    perimeter = n * s
    result = area + perimeter**2
    return "%.4f" % result

print(polysum(4, 2))