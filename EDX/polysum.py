# -*- coding: utf-8 -*-
"""
Created on Sat Sep 15 17:22:15 2018

@author: jange
"""

# import math to use tan e pi functions
import math

def polysum(n,s):
    area=(0.25*n*(s**2))/math.tan(math.pi/n)
    perimeter = n * s
    result = area + perimeter**2
    # x is a temporary use, just to cast as follow
    x = "%.4f" % result
    return float(x)

print(polysum(4, 2))