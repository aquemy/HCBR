import random
import numpy as np
from deap import base
from deap import creator
from deap import tools
from deap import algorithms

import argparse
import pandas
import os
import numpy as np
import matplotlib.pyplot as plt
import functools
from collections import Counter
import math
import random

def neighbors(W, i):
    n = []
    for k, e in enumerate(W[i]):
        if e > 0:
            for j in range(len(W)):
                if j != k and W[j][k] > 0:
                    n.append(W[j][k])
                else:
                    n.append(0)
    return n

def accuracy(decision_vector):
    ok = len([s[2] for s in decision_vector if confusion_matrix_label(s) in ['TP', 'TN']])
    return  float(ok) / len(decision_vector)

def mcc(decision_vector):
    tp = len([s[2] for s in decision_vector if confusion_matrix_label(s) in ['TP']])
    tn = len([s[2] for s in decision_vector if confusion_matrix_label(s) in ['TN']])
    fp = len([s[2] for s in decision_vector if confusion_matrix_label(s) in ['FP']])
    fn = len([s[2] for s in decision_vector if confusion_matrix_label(s) in ['FN']])
    den = 0
    if (tp + fp) == 0 or (tp + fn) == 0 or (tn + fp) == 0 or (tn + fn) == 0:
        den = 1
    else:
        den = (tp + fp) * (tp + fn) * (tn + fp) * (tn + fn)
        den = math.sqrt(den)
    return ((tp*tn) - (fp * fn)) / den


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
    TP = [s[2] for s in decision_vector if confusion_matrix_label(s) == 'TP']
    min_TP = min(TP) if TP else 0.
    FP = [s[2] for s in decision_vector if confusion_matrix_label(s) == 'FP']
    max_FP = max(FP) if FP else 0.

    d_FP_TP = min_TP - max_FP
    if min_TP < max_FP:
        k_TP = abs(max_FP - min_TP)
        k_FP = -abs(max_FP - min_TP)
    print("min TP: {} | max FP {} | distance: {}".format(min_TP, max_FP, d_FP_TP))

    TN = [s[2] for s in decision_vector if confusion_matrix_label(s) == 'TN']
    max_TN = min(TN) if TN else 0.
    FN = [s[2] for s in decision_vector if confusion_matrix_label(s) == 'FN']
    min_FN = max(FN) if FN else 0.

    d_FN_TN = min_FN - max_TN
    k_TN = -abs(min_FN - max_TN)
    k_FN = abs(min_FN - max_TN)
    print("max TN: {} | min FN {} | distance: {}".format(max_TN, min_FN, d_FN_TN))

    #k_TP = 0 # TODO: calculate from the data s.t. it becomes separable
    #k_FP = 0
    #k_TN = min_FN
    #k_FN = -min_FN

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

def calculate_fitness(predictor, mu1, mu0, weights, J, individual):
    #print(mu1)
    mu1_d = np.array(mu1)
    mu0_d = np.array(mu0)
    for i,_ in enumerate(mu1_d):
        mu1_d[i] += individual[i] / 2.
        mu0_d[i] -= individual[i] / 2.
    #mu0_d /= np.linalg.norm(mu0_d, ord=1)
    #mu1_d /= np.linalg.norm(mu1_d, ord=1)
    D, S, S0, S1 = calculate_decision_vector(predictor, mu1_d, mu0_d, weights, J)
    OS = S
    OD = D
    decision_vector = np.column_stack((D,J,S,OS,OD))
    confusion_matrix, labels = calculate_confusion_matrix(decision_vector)
    #fitness = accuracy(decision_vector) - 0.1 * np.linalg.norm(individual, ord=2)
    fitness = mcc(decision_vector) - 0.1 * np.linalg.norm(individual, ord=2) ** 2

    return fitness,

def main(args):

    #hcbr_traiing_pred = pandas.read_table('/home/aquemy/dev/cbr/build/training_set_prediction_post_training.txt', delim_whitespace=True, header=None)
    #print(hcbr_traiing_pred)


    weights = pandas.read_table(args.weights, delim_whitespace=True, header=None)
    mu0 = pandas.read_table(args.mu0, delim_whitespace=True, header=None)
    mu1 = pandas.read_table(args.mu1, delim_whitespace=True, header=None)
    J = pandas.read_table(args.outcomes, delim_whitespace=True, header=None)[:len(weights)]
    #J = pandas.read_table(args.outcomes, delim_whitespace=True, header=None)[-len(weights):]
    weights = weights.values
    mu0 = mu0.values
    mu1 = mu1.values
    J = J.values

    dr_simple = functools.partial(decision_rule)
    dr_optimized = functools.partial(decision_rule, eta1=args.eta1, eta0=args.eta0, l1=args.l1, l0=args.l0)
    predictor = np.vectorize(dr_simple)
    predictor_opti = np.vectorize(dr_optimized)

    fitness_function = functools.partial(calculate_fitness, predictor, mu1, mu0, weights, J)

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
    print('# Initial Accuracy: {}'.format(accuracy(decision_vector)))
    print('# Initial MCC: {}'.format(mcc(decision_vector)))

    def difference_matrix(a):
        x = np.reshape(a, (len(a), 1))
        return x - x.transpose()

    dmu = mu1 - mu0
    vmu = difference_matrix(dmu)
    min_vmu = vmu.min()
    print('# Minimal variation in Mu: {}'.format(min_vmu))
    print('# Min in Mu: {}'.format(min(dmu)))


    
    min_vS = np.abs(S).min()
    print('# Min variation in initial S: {}'.format(min_vS))

    IND_SIZE = len(mu0)

    creator.create("FitnessMax", base.Fitness, weights=(1.0,))
    creator.create("Individual", np.ndarray, fitness=creator.FitnessMax)
    creator.create("Strategy", np.ndarray, typecode="d", strategy=None)

    def initES(icls, scls, size, imin, imax, smin, smax):
        ind = icls(random.uniform(imin, imax) for _ in range(size))
        ind.strategy = scls(random.uniform(smin, smax) for _ in range(size))
        return ind


    toolbox = base.Toolbox()
    #toolbox.register("attr_float", random.uniform, -min_vmu / 10, min_vmu / 10)
    #toolbox.register("attr_float", initES, -min_vmu / len(weights[0]), min_vmu / len(weights[0]), -1., 1.)
    toolbox.register("individual", initES, creator.Individual,
                     creator.Strategy, IND_SIZE, -min_vmu / len(weights[0]), min_vmu / len(weights[0]), 0, 1.)
                     #creator.Strategy, IND_SIZE, -min(dmu) / 100 , min(dmu) / 100, -1., 1.)
    toolbox.register("population", tools.initRepeat, list, toolbox.individual)
    toolbox.register("evaluate", fitness_function)
    toolbox.register("mate", tools.cxTwoPoint)
    toolbox.register("mutate", tools.mutGaussian, mu=0.0, sigma=min_vmu / 20, indpb=0.05)
    #toolbox.register("mutate", tools.mutGaussian, mu=0.0, sigma=min_vmu / len(weights[0]), indpb=0.05)
    toolbox.register("select", tools.selTournament, tournsize=3)

    pop = toolbox.population(n=100)
    #for ind in pop:
    #    print(fitness_function(ind))

    stats = tools.Statistics(key=lambda ind: ind.fitness.values)
    stats.register("avg", np.mean)
    stats.register("std", np.std)
    stats.register("min", np.min)
    stats.register("max", np.max)

    #algorithms.eaSimple(pop, toolbox, cxpb=0.5, mutpb=0.05, ngen=1000, stats=stats, verbose=True)
    algorithms.eaMuPlusLambda(pop, toolbox, mu=100, lambda_=50, cxpb=0.5, mutpb=0.2, ngen=1000, stats=stats, verbose=True)
    #algorithms.eaMuCommaLambda(pop, toolbox, mu=3, lambda_=5, cxpb=0.5, mutpb=0.2, ngen=100, stats=stats, verbose=True)

    top10 = tools.selBest(pop, k=1)
    for e in top10:
        print(e.fitness)
        #print("{} {}".format(e.fitness, e))

    mu1_d = np.array(mu1)
    mu0_d = np.array(mu0)
    for i,_ in enumerate(top10[0]):
        mu1_d[i] += top10[0][i] / 2.
        mu0_d[i] -= top10[0][i] / 2.
    #mu0_d /= np.linalg.norm(mu0_d, ord=1)
    #mu1_d /= np.linalg.norm(mu1_d, ord=1)

    np.savetxt('Mu_0_optimized.txt', mu0_d, fmt='%.15f')
    np.savetxt('Mu_1_optimized.txt', mu1_d, fmt='%.15f')


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
 