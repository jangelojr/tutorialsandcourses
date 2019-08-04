# -*- coding: utf-8 -*-
"""
Created on Mon Sep 17 22:17:24 2018

@author: jange
"""
teste = ('I', 'am', 'a', 'test', 'tuple')

def oddTuples(aTup):
    # a placeholder to gather our response
    rTup = ()
    index = 0

    # Idea: Iterate over the elements in aTup, counting by 2
    #  (every other element) and adding that element to 
    #  the result
    while index < len(aTup):
        rTup += (aTup[index],)
        print(rTup)
        index += 2

    return rTup

