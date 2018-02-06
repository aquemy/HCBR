import argparse
import pandas
import os
import numpy as np
import matplotlib.pyplot as plt
import functools
from collections import Counter
import math
import random

def decision_rule(s, eta1=0, eta0=0, l1=1, l0=0):
    if s > 0:
        if s > eta1:
            return 1
        else:
            return l1
    else:
        if s < eta0:
            return 0
        else:
            return l0

def confusion_matrix_label(o):
    if o[1] == 1:
        return 'TP' if o[0] == 1 else 'FN'
    else:
        return 'TN' if o[0] == 0 else 'FP'

def relative_max_mu(mu):
    return max(abs(mu[0]), abs(mu[1])) / (abs(mu[0]) + abs(mu[1]))

def label_to_color(l):
    if l == 'TP':
        return 'xkcd:royal blue'
    elif l == 'TN':
        return 'xkcd:cerulean'
    elif l == 'FP':
        return 'xkcd:dark red'
    else:
        return 'xkcd:light red'

def accuracy(decision_vector):
    ok = len([s[2] for s in decision_vector if confusion_matrix_label(s) in ['TP', 'TN']])
    return  float(ok) / len(decision_vector)

def calculate_decision_vector(predictor, mu1, mu0, weights):
    #delta_mu = mu1.subtract(mu0)
    S1 = np.dot(weights, mu1)
    S0 = np.dot(weights, mu0) 
    S = S1 - S0
    D = predictor(S)
    return D, S, S0, S1

def calculate_confusion_matrix(decision_vector):
    cf_label = np.array(map(confusion_matrix_label, decision_vector))
    return Counter(cf_label)

def update_weights(decision_vector, W, mu1, mu0):
    # S = W.mu1 - W.mu0 = W.(mu1 - mu0)
    # mu1' = mu1 + d_1
    # mu0' = mu0 + d_0
    # S' = W.(mu1 + d_1) - W.(mu0 + d_0) = S + Wd
    # <=> (S' - S) = Wd
    # <=> W*(S' - S) = d
    # With S' = S + k where the components of k describe the variations on S to reach the desired strength distribution
    # <=> W*k = d solving for d, shape contraints on k
    W_inv = np.linalg.pinv(W)

    # Test 1. increasing the TP and decreasing TN by a constant. Untouched FN and FP
    # Calculate vector k
    '''
    k_TP = 20 # TODO: calculate from the data s.t. it becomes separable
    k_TN = -40
    def ki(s, k_TP, k_TN):
        l = confusion_matrix_label(s)
        return k_TP if l == 'TP' else k_TN if l == 'TN' else 0
    k = np.array([ki(s, k_TP, k_TN) for s in decision_vector])
    k = k.reshape(len(k), 1)
    d = np.dot(W_inv, k)
    '''


    # Test 2. increasing the TP and decreasing TN by a constant. increase FN and decrease FP
    # Calculate vector k
    #'''
    k_TP = 1 # TODO: calculate from the data s.t. it becomes separable
    k_TN = -1
    k_FP = 1
    k_FN = -1
    def ki(s, k_TP, k_TN):
        l = confusion_matrix_label(s)
        return k_TP if l == 'TP' else k_TN if l == 'TN' else k_FP if l == 'FP' else k_FN
    k = np.array([ki(s, k_TP, k_TN) for s in decision_vector])
    k = k.reshape(len(k), 1)
    d = np.dot(W_inv, k)
    #'''

    # Test 3. tranformation of S by a similitude S' = aS + b. 
    # S' - S = aS + b - S = S(a - 1) + b
    # d = W*(S(a - 1) + b) 
    # Calculate vector k
    '''
    a = {
        'TP': 4,
        'TN': -4,
        'FP': -2,
        'FN': -2
    }
    b = {
        'TP': 1,
        'TN': -1,
        'FP': 1,
        'FN': -1
    }
    def ki(s, a, b):
        l = confusion_matrix_label(s)
        return (a[l] - 1) * s[2] + b[l]
    k = np.array([ki(s, a, b) for s in decision_vector])
    k = k.reshape(len(k), 1)
    d = np.dot(W_inv, k)
    '''

    #np.linalg.norm(mu1 + d, ord=1)
    return mu1 + d / 2, mu0 - d / 2


def plot(decision_vector, S, S0, S1, args, windows_id=100):
    fig = plt.figure(windows_id)
    
    n_bins = 30
    n, bins, patches = plt.hist([s[2] for s in decision_vector if confusion_matrix_label(s) == 'TP'], n_bins, normed=0, facecolor='xkcd:royal blue', alpha=0.75)
    n, bins, patches = plt.hist([s[2] for s in decision_vector if confusion_matrix_label(s) == 'FP'], n_bins, normed=0, facecolor='xkcd:dark red', alpha=0.75)

    n, bins, patches = plt.hist([s[2] for s in decision_vector if confusion_matrix_label(s) == 'TN'], n_bins, normed=0, facecolor='xkcd:cerulean', alpha=0.75)
    n, bins, patches = plt.hist([s[2] for s in decision_vector if confusion_matrix_label(s) == 'FN'], n_bins, normed=0, facecolor='xkcd:light red', alpha=0.75)

    plt.axvline(x=args.eta1)
    plt.axvline(x=args.eta0)

    plt.xlabel('xlabel')
    plt.ylabel('ylabel')

    plt.title(r'ACC={}'.format(accuracy(decision_vector)))
    plt.axis([min(S), max(S), -0.1, n_bins])
    plt.grid(True)

    fig = plt.figure(windows_id + 10)
    ax = fig.add_subplot(1, 1, 1)
    relative_max_mu_val = np.array(map(relative_max_mu, np.column_stack((S1, S0))))
    cf_label = np.array(map(confusion_matrix_label, decision_vector))
    ax.scatter(S, relative_max_mu_val, color=np.array(map(label_to_color, cf_label)), s=1)



def main(args):
    weights = pandas.read_table(args.weights, delim_whitespace=True, header=None)
    mu0 = pandas.read_table(args.mu0, delim_whitespace=True, header=None)
    mu1 = pandas.read_table(args.mu1, delim_whitespace=True, header=None)
    J = pandas.read_table(args.outcomes, delim_whitespace=True, header=None)[:len(weights)]

    dr_simple = functools.partial(decision_rule)
    dr_optimized = functools.partial(decision_rule, eta1=args.eta1, eta0=args.eta0, l1=args.l1, l0=args.l0)
    predictor = np.vectorize(dr_simple)
    predictor_opti = np.vectorize(dr_optimized)

    '''
    INITIALIZATION
    '''
    D, S, S0, S1 = calculate_decision_vector(predictor, mu1, mu0, weights)
    decision_vector = np.column_stack((D,J,S))
    confusion_matrix = calculate_confusion_matrix(decision_vector)
    print(confusion_matrix)
    print(accuracy(decision_vector))
    plot(decision_vector, S, S0, S1, args, windows_id=100)

    '''
    ITERATION
    '''
    k = 20
    for i in range(k):
        mu1, mu0 = update_weights(decision_vector, weights, mu1, mu0)
        D, S, S0, S1 = calculate_decision_vector(predictor_opti if i == k -1 else predictor, mu1, mu0, weights)
        decision_vector = np.column_stack((D,J,S))
        confusion_matrix = calculate_confusion_matrix(decision_vector)
        print(confusion_matrix)
        print(accuracy(decision_vector))
        #plot(decision_vector, S, S0, S1, args, windows_id=(i+2) * 100)

    plot(decision_vector, S, S0, S1, args, windows_id=(k+2) * 100)
    '''
    DISPLAY
    '''
    plt.show()

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
 