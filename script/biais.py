import argparse
import pandas
import os
import numpy as np
import matplotlib.pyplot as plt
import functools
from collections import Counter
import math
import random

def accuracy(decision_vector):
    ok = len([s[2] for s in decision_vector if confusion_matrix_label(s) in ['TP', 'TN']])
    return  float(ok) / len(decision_vector)

def determine_bias(mu0, mu1, weights, J, f=accuracy):
    bias = 0
    dr = functools.partial(decision_rule, bias=bias)
    predictor = np.vectorize(dr)
    D, S, S0, S1 = calculate_decision_vector(predictor, mu1, mu0, weights, J)
    decision_vector = np.column_stack((D,J,S,S,D))
    confusion_matrix, labels = calculate_confusion_matrix(decision_vector)
    max_v = 0
    max_i = 0
    for i, e in enumerate(decision_vector):
        if labels[i] in ['FP', 'FN']:
            dr = functools.partial(decision_rule, bias=e[3])
            predictor = np.vectorize(dr)
            D, S, S0, S1 = calculate_decision_vector(predictor, mu1, mu0, weights, J)
            dv = np.column_stack((D,J,S,S,D))
            confusion_matrix, labels = calculate_confusion_matrix(dv)
            v = f(dv)
            max_v = max_v if max_v > v else v
            max_i = max_i if max_v > v else i
        #print('{}/{} - {} | {}'.format(i, len(decision_vector), max_v, decision_vector[max_i][3]))

    return decision_vector[max_i][3]

def decision_rule(s, eta1=0, eta0=0, l1=1, l0=0, bias=0):
    if s > bias:
        if s > eta1:
            return 1
        else:
            return l1
    else:
        if s < eta0:
            return 0
        else:
            return l0

def confusion_matrix_label(o,i=0):
    if o[1] == 1:
        return 'TP' if o[i] == 1 else 'FN'
    else:
        return 'TN' if o[i] == 0 else 'FP'

def calculate_confusion_matrix(decision_vector):
    cf_label = np.array(map(confusion_matrix_label, decision_vector))
    return Counter(cf_label), cf_label

def calculate_decision_vector(predictor, mu1, mu0, weights, J):
    S1 = np.matmul(weights, mu1)
    S0 = np.matmul(weights, mu0) 
    S = S1 - S0
    D = predictor(S)
    return D, S, S0, S1

def main(args):
    weights = pandas.read_table(args.weights, delim_whitespace=True, header=None)
    mu0 = pandas.read_table(args.mu0, delim_whitespace=True, header=None)
    mu1 = pandas.read_table(args.mu1, delim_whitespace=True, header=None)
    J = pandas.read_table(args.outcomes, delim_whitespace=True, header=None)[:len(weights)]
    weights = weights.values
    mu0 = mu0.values
    mu1 = mu1.values
    J = J.values

    bias = determine_bias(mu0, mu1, weights, J)
    print(bias)


def parse_args(parser0):
    args = parser.parse_args()

    # Check path
    return args

if __name__ == "__main__":
    
    parser = argparse.ArgumentParser(description='Adjust model')
    parser.add_argument('--weights', type=str)
    parser.add_argument('--mu0', type=str)
    parser.add_argument('--mu1', type=str)
    parser.add_argument('--outcomes', type=str)
    parser.add_argument('--l1', default=1, type=int)
    parser.add_argument('--l0', default=0, type=int)
    parser.add_argument('--eta1', default=0., type=float)
    parser.add_argument('--eta0', default=0., type=float)

    args = parse_args(parser)

    main(args)
 