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
    print(fitness, mcc(decision_vector),  0.1 * np.linalg.norm(individual, ord=2) ** 2)
    return fitness,

def calculate_final_mcc(predictor, mu1, mu0, weights, J, individual):
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
    fitness = mcc(decision_vector)
    return fitness

def calculate_final_accuracy(predictor, mu1, mu0, weights, J, individual):
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
    fitness = accuracy(decision_vector)
    return fitness

def main(args):
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
    D, S, S0, S1 = calculate_decision_vector(predictor, mu1, mu0, weights, J)

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
                     creator.Strategy, IND_SIZE, -min_vmu / 10, min_vmu / 10, 0, 1.)
                     #creator.Strategy, IND_SIZE, -min(dmu) / 100 , min(dmu) / 100, -1., 1.)
    toolbox.register("population", tools.initRepeat, list, toolbox.individual)
    toolbox.register("evaluate", fitness_function)
    toolbox.register("mate", tools.cxTwoPoint)
    toolbox.register("mutate", tools.mutGaussian, mu=0.0, sigma=min_vmu / 10, indpb=0.05)
    #toolbox.register("mutate", tools.mutGaussian, mu=0.0, sigma=min_vmu / len(weights[0]), indpb=0.05)
    toolbox.register("select", tools.selTournament, tournsize=3)

    pop = toolbox.population(n=200)

    stats = tools.Statistics(key=lambda ind: ind.fitness.values)
    stats.register("avg", np.mean)
    stats.register("std", np.std)
    stats.register("min", np.min)
    stats.register("max", np.max)

    #algorithms.eaSimple(pop, toolbox, cxpb=0.5, mutpb=0.05, ngen=1000, stats=stats, verbose=True)
    algorithms.eaMuPlusLambda(pop, toolbox, mu=100, lambda_=50, cxpb=0.5, mutpb=0.2, ngen=100, stats=stats, verbose=True)
    #algorithms.eaMuCommaLambda(pop, toolbox, mu=3, lambda_=5, cxpb=0.5, mutpb=0.2, ngen=100, stats=stats, verbose=True)

    top10 = tools.selBest(pop, k=1)

    mu1_d = np.array(mu1)
    mu0_d = np.array(mu0)
    for i,_ in enumerate(top10[0]):
        mu1_d[i] += top10[0][i] / 2.
        mu0_d[i] -= top10[0][i] / 2.

    f_accuracy = functools.partial(calculate_final_accuracy, predictor, mu1, mu0, weights, J)
    f_mcc = functools.partial(calculate_final_mcc, predictor, mu1, mu0, weights, J)

    print(f_accuracy(top10[0]))
    print(f_mcc(top10[0]))

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
 