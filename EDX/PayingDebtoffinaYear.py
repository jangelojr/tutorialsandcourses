# -*- coding: utf-8 -*-
"""
Created on Sun Sep 16 15:14:22 2018

@author: jange
"""

def monthlyInterestRate (annualInterestRate):
    return annualInterestRate/12

def minimumMonthlyPayment (monthlyPaymentRate, previousBalance):
    return monthlyPaymentRate * previousBalance

def monthlyUnpaidBalance (previousBalance, monthlyPaymentRate):
    return monthlyPaymentRate * previousBalance - previousBalance

def updatedBalanceEachMonth(monthlyUnpaidBalance, monthlyInterestRate):
    return monthlyInterestRate * monthlyUnpaidBalance + monthlyUnpaidBalance
    
balance            = 42
annualInterestRate = 0.2
monthlyPaymentRate = 0.04
newBalance         = 0

monthRate = monthlyInterestRate(annualInterestRate)
    
for month in range(1, 13, 1):
    newBalance = abs(monthlyUnpaidBalance(balance, monthlyPaymentRate))
    balance = abs(updatedBalanceEachMonth(newBalance, monthRate))
    x = float("%.2f" % balance)

print(' Remaining balance: ' + str(x))