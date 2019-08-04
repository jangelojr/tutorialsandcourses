# -*- coding: utf-8 -*-
"""
Created on Sat Sep 15 10:36:31 2018

@author: jange
"""

entrada       = -1
menor         = 0
maior         = 100
achoQueE      = 0
minhaResposta = ''

entrada = int(input("Please think of a number between 0 and 100!"))

while entrada < 0 or entrada > 99:
    entrada = int(input("Please think of a number between 0 and 100!"))

achoQueE = (maior + menor) // 2
print('Is your secret number ' + str(achoQueE) + '?')

minhaResposta = input('Enter h to indicate the guess is too high. Enter l to indicate the guess is too low.' \
                      ' Enter c to indicate I guessed correctly.')

while (minhaResposta != 'h' and minhaResposta != 'l' and minhaResposta != 'c'):
    print('Sorry, I did not understand your input.')
    minhaResposta = input('Enter h to indicate the guess is too high. Enter l to indicate the guess is too low.' \
                      ' Enter c to indicate I guessed correctly.')
    
while (minhaResposta != 'c'):
    if (minhaResposta != 'h' and minhaResposta != 'l' and minhaResposta != 'c'):
        print('Sorry, I did not understand your input.')
        minhaResposta = input('Enter h to indicate the guess is too high. Enter l to indicate the guess is too low.' \
                      ' Enter c to indicate I guessed correctly.')
    
    print('achoQueE: ' + str(achoQueE))
    print('Menor    : ' + str(menor))
    print('Maior    : ' + str(maior))
    
    if minhaResposta == 'h':
        menor = achoQueE
        achoQueE = (menor + maior) // 2
        print('Is your secret number ' + str(achoQueE) + '?')
        minhaResposta = input('Enter h to indicate the guess is too high. Enter l to indicate the guess is too low.' \
                      ' Enter c to indicate I guessed correctly.')
    elif minhaResposta == 'l':
        maior = achoQueE
        achoQueE = (menor + maior) // 2
        print('Is your secret number ' + str(achoQueE) + '?')
        minhaResposta = input('Enter h to indicate the guess is too high. Enter l to indicate the guess is too low.' \
                      ' Enter c to indicate I guessed correctly.')
        
    print('Minha resposta é: ' + minhaResposta)
        
print('Game over. Your secret number was: ' + str(achoQueE))