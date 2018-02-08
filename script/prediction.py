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


def determine_bias(S, mu0, mu1, weights, J, f=accuracy):
    min_S = min(S)
    max_S = max(S)
    bias = min_S + abs(max_S - min_S) / 2

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

    return decision_vector[max_i][3]

def adjust_intrinsic_strength_full_loop(S, J, D, mu0, mu1, W, k_max=1):
    for k in range(k_max):
        for i, C in enumerate(W):
            if J[i] != int(D[i]):
                #print('Case {} misclassified!'.format(i))
                for j, w in enumerate(C):
                    err = abs(mu1[j] - mu0[j])
                    if w != 0:
                        #print(' ERROR E{} = {}'.format(j, err))
                        err *= w 
                        if int(D[i]) == 1:
                            mu0[j] += err
                            mu1[j] -= err
                        else:
                            mu0[j] -= err
                            mu1[j] += err
    return mu0, mu1


def adjust_intrinsic_strength(S, J, D, mu0, mu1, W, k_max=1):
    for it in range(k_max):
        for i, ps in enumerate(S):
            C = W[i]
            s = np.dot(C, mu1 - mu0)
            pred = decision_rule(s)
            if J[i] != pred:
                #print('Case {} misclassified!'.format(i))
                for j, w in enumerate(C):
                    err = abs(mu1[j] - mu0[j])
                    if w != 0:
                        #print(' ERROR E{} = {}'.format(j, err))
                        err *= w 
                        if int(D[i]) == 1:
                            mu0[j] += err
                            mu1[j] -= err
                        else:
                            mu0[j] -= err
                            mu1[j] += err
    return mu0, mu1

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

def original_label(o):
    return o[3]

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


def calculate_decision_vector(predictor, mu1, mu0, weights, J):
    #delta_mu = mu1.subtract(mu0)
    S1 = np.matmul(weights, mu1)
    S0 = np.matmul(weights, mu0) 
    S = S1 - S0
    D = predictor(S)
    #for i, s1 in enumerate(S1):
    #    print('{} - {} = {} | P : {} | {} | {}'.format(s1, S0[i], S[i], D[i], i, J[i]))
    return D, S, S0, S1

def calculate_confusion_matrix(decision_vector):
    cf_label = np.array(map(confusion_matrix_label, decision_vector))
    return Counter(cf_label), cf_label

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
    min_TP = min([s[2] for s in decision_vector if confusion_matrix_label(s) == 'TP'])
    max_FP = max([s[2] for s in decision_vector if confusion_matrix_label(s) == 'FP'])

    d_FP_TP = min_TP - max_FP
    if min_TP < max_FP:
        k_TP = abs(max_FP - min_TP)
        k_FP = -abs(max_FP - min_TP)
    print("min TP: {} | max FP {} | distance: {}".format(min_TP, max_FP, d_FP_TP))


    max_TN = min([s[2] for s in decision_vector if confusion_matrix_label(s) == 'TN'])
    min_FN = max([s[2] for s in decision_vector if confusion_matrix_label(s) == 'FN'])

    d_FN_TN = min_FN - max_TN
    k_TN = -abs(min_FN - max_TN)
    k_FN = abs(min_FN - max_TN)
    print("max TN: {} | min FN {} | distance: {}".format(max_TN, min_FN, d_FN_TN))

    #k_TP = 0 # TODO: calculate from the data s.t. it becomes separable
    #k_FP = 0
    #k_TN = 0#min_FN
    #k_FN = 0#-min_FN

    def ki(s, k_TP, k_TN):
        l = confusion_matrix_label(s)
        return k_TP if l == 'TP' else k_TN if l == 'TN' else k_FP if l == 'FP' else k_FN
    k = np.array([ki(s, k_TP, k_TN) for s in decision_vector])
    k = k.reshape(len(k), 1)
    d = np.matmul(W_inv, k)
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
    
    n_bins = 50
    
    #'''
    n, bins, patches = plt.hist([s[2] for s in decision_vector if confusion_matrix_label(s) == 'TP'], n_bins, normed=0, facecolor='xkcd:royal blue', alpha=0.75)
    n, bins, patches = plt.hist([s[2] for s in decision_vector if confusion_matrix_label(s) == 'FP'], n_bins, normed=0, facecolor='xkcd:dark red', alpha=0.75)

    n, bins, patches = plt.hist([s[2] for s in decision_vector if confusion_matrix_label(s) == 'TN'], n_bins, normed=0, facecolor='xkcd:cerulean', alpha=0.75)
    n, bins, patches = plt.hist([s[2] for s in decision_vector if confusion_matrix_label(s) == 'FN'], n_bins, normed=0, facecolor='xkcd:light red', alpha=0.75)
    #'''
    '''
    n, bins, patches = plt.hist([s[2] for s in decision_vector if confusion_matrix_label(s, 4) == 'TP'], n_bins, normed=0, facecolor='xkcd:royal blue', alpha=0.75)
    n, bins, patches = plt.hist([s[2] for s in decision_vector if confusion_matrix_label(s, 4) == 'FP'], n_bins, normed=0, facecolor='xkcd:dark red', alpha=0.75)

    n, bins, patches = plt.hist([s[2] for s in decision_vector if confusion_matrix_label(s, 4) == 'TN'], n_bins, normed=0, facecolor='xkcd:cerulean', alpha=0.75)
    n, bins, patches = plt.hist([s[2] for s in decision_vector if confusion_matrix_label(s, 4) == 'FN'], n_bins, normed=0, facecolor='xkcd:light red', alpha=0.75)
    '''
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

    #hcbr_traiing_pred = pandas.read_table('/home/aquemy/dev/cbr/build/training_set_prediction_post_training.txt', delim_whitespace=True, header=None)
    #print(hcbr_traiing_pred)


    weights = pandas.read_table(args.weights, delim_whitespace=True, header=None)
    mu0 = pandas.read_table(args.mu0, delim_whitespace=True, header=None)
    mu1 = pandas.read_table(args.mu1, delim_whitespace=True, header=None)
    J = pandas.read_table(args.outcomes, delim_whitespace=True, header=None)[:len(weights)]
    weights = weights.values
    mu0 = mu0.values
    mu1 = mu1.values
    J = J.values

    dr_simple = functools.partial(decision_rule)
    dr_optimized = functools.partial(decision_rule, eta1=args.eta1, eta0=args.eta0, l1=args.l1, l0=args.l0)
    predictor = np.vectorize(dr_simple)
    predictor_opti = np.vectorize(dr_optimized)

    '''
    INITIALIZATION
    '''
    print('# INITIALIZATION')
    #mu0 /= np.linalg.norm(mu0, ord=1)
    #mu1 /= np.linalg.norm(mu1, ord=1)
    D, S, S0, S1 = calculate_decision_vector(predictor, mu1, mu0, weights, J)
    #print(S0)
    #print(S1)
    #@print(S)
    #S /= np.linalg.norm(S, ord=1)
    OS = S
    OD = D
    decision_vector = np.column_stack((D,J,S,OS,OD))
    confusion_matrix, labels = calculate_confusion_matrix(decision_vector)
    print(confusion_matrix)
    print(accuracy(decision_vector))
    plot(decision_vector, S, S0, S1, args, windows_id=100)

    #print(np.column_stack((D, hcbr_traiing_pred, S)))

    '''
    BIAS AND OPTIMIZATION
    '''
    '''
    bias = determine_bias(S, mu0, mu1, weights, J)
    print('BIAS: {}'.format(bias))
    dr_bias = functools.partial(decision_rule, bias=bias)
    predictor_bias = np.vectorize(dr_bias)
    D, S, S0, S1 = calculate_decision_vector(predictor_bias, mu1, mu0, weights, J)
    decision_vector = np.column_stack((D,J,S,OS,OD))
    confusion_matrix, labels = calculate_confusion_matrix(decision_vector)
    print(confusion_matrix)
    print(accuracy(decision_vector))
    plot(decision_vector, S, S0, S1, args, windows_id=101)
    '''
    '''
    UPDATE CONFIDENCE
    '''
    #'''
    print('# UPDATE CONFIDENCE')
    #mu0, mu1 = adjust_intrinsic_strength_full_loop(S, J, D, mu0, mu1, weights, k_max=1)
    mu0, mu1 = adjust_intrinsic_strength(S, J, D, mu0, mu1, weights, k_max=2)
    D, S, S0, S1 = calculate_decision_vector(predictor, mu1, mu0, weights, J)
    decision_vector = np.column_stack((D,J,S,OS,OD))
    confusion_matrix, labels = calculate_confusion_matrix(decision_vector)
    print(confusion_matrix)
    print(accuracy(decision_vector))
    plot(decision_vector, S, S0, S1, args, windows_id=100 * 100)
    #'''
    '''
    SEPARATION PHASE
    '''
    print('# SEPARATE')
    '''
    k = 1
    for i in range(k):
        print('ITERATION {}'.format(i))
        mu1, mu0 = update_weights(decision_vector, weights, mu1, mu0)
        mu0 /= np.linalg.norm(mu0, ord=1)
        mu1 /= np.linalg.norm(mu1, ord=1)
        D, S, S0, S1 = calculate_decision_vector(predictor_opti if i == k -1 else predictor, mu1, mu0, weights, J)
        S /= np.linalg.norm(S, ord=1) if i != k -1 else 1
        decision_vector = np.column_stack((D,J,S,OS,OD))
        confusion_matrix, labels = calculate_confusion_matrix(decision_vector)
        #print(confusion_matrix)
        #print(accuracy(decision_vector))
        #plot(decision_vector, S, S0, S1, args, windows_id=(i+2) * 100)
    #plot(decision_vector, S, S0, S1, args, windows_id=(k+2) * 100)


        bias = determine_bias(S, mu0, mu1, weights, J)
        print('BIAS: {}'.format(bias))
        dr_bias = functools.partial(decision_rule, bias=bias)
        predictor_bias = np.vectorize(dr_bias)
        D, S, S0, S1 = calculate_decision_vector(predictor_bias, mu1, mu0, weights, J)
        decision_vector = np.column_stack((D,J,S,OS,OD))
        confusion_matrix, labels = calculate_confusion_matrix(decision_vector)
        print(confusion_matrix)
        print(accuracy(decision_vector))

    plot(decision_vector, S, S0, S1, args, windows_id=102)
    

    '''
    '''
    SERIALIZE
    '''
    np.savetxt('Mu_0_separated.txt', mu0, fmt='%.15f')
    np.savetxt('Mu_1_separated.txt', mu1, fmt='%.15f')

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
 