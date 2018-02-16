import argparse
import pandas as pd
import os
import numpy as np
import matplotlib.pyplot as plt
import functools
from collections import Counter
import math
import random
import sklearn
from sklearn.metrics import confusion_matrix

def relative_max_mu(mu):
    return max(abs(mu[0]), abs(mu[1])) / (abs(mu[0]) + abs(mu[1]))

def label_to_color(l):
    if l == 'tp':
        return 'xkcd:royal blue'
    elif l == 'tn':
        return 'xkcd:cerulean'
    elif l == 'fp':
        return 'xkcd:dark red'
    else:
        return 'xkcd:light red'

def plot(M, args, windows_id=100):
    fig = plt.figure(windows_id)
    
    n_bins = args.bins
    n, bins, patches = plt.hist([m.S for _, m in M.iterrows() if m.label == 'tp'], n_bins, normed=0, facecolor='xkcd:royal blue', alpha=0.75)
    n, bins, patches = plt.hist([m.S for _, m in M.iterrows() if m.label == 'fp'], n_bins, normed=0, facecolor='xkcd:dark red', alpha=0.75)
    n, bins, patches = plt.hist([m.S for _, m in M.iterrows() if m.label == 'tn'], n_bins, normed=0, facecolor='xkcd:cerulean', alpha=0.75)
    n, bins, patches = plt.hist([m.S for _, m in M.iterrows() if m.label == 'fn'], n_bins, normed=0, facecolor='xkcd:light red', alpha=0.75)

    plt.xlabel(r'$S(x) = S^{(1)}(x) - S^{(0)}(x)$')
    plt.ylabel('#{x}')

    fig = plt.figure(windows_id + 10)
    ax = fig.add_subplot(1, 1, 1)
    ax.scatter(M.S, M.delta_max_mu, color=np.array(map(label_to_color, M.label)), s=1)

def label(m):
    if m[1] == 1:
        if m[2] == 1:
            return 'tp'
        else:
            return 'fn'
    else:
        if m[2] == 1:
            return 'fp'
        else:
            return 'tn'

def main(args):
    M = pd.read_table(args.prediction_file, delim_whitespace=True)

    M['S'] = np.array(map(lambda m: m[3] - m[4], M.values))
    M['delta_max_mu'] = np.array(map(relative_max_mu, np.column_stack((M.s_1.values, M.s_0.values))))
    M['label'] = np.array(map(label, M.values))

    # Determine confusion matrix
    cm = confusion_matrix(M.correct, M.pred).ravel()
    print(cm)
    acc = sklearn.metrics.accuracy_score(M.correct, M.pred)
    f1 = sklearn.metrics.f1_score(M.correct, M.pred)
    mcc = sklearn.metrics.matthews_corrcoef(M.correct, M.pred)
    print('ACCURACY: {}'.format(acc))
    print('F1 SCORE: {}'.format(f1))
    print('MATTHEWS CORR.: {}'.format(mcc))
    
    plot(M, args)

    plt.show()

def parse_args(parser0):
    args = parser.parse_args()

    # Check path
    return args

if __name__ == "__main__":
    
    parser = argparse.ArgumentParser(description='Adjust model')
    parser.add_argument('--prediction-file', type=str)
    parser.add_argument('--bins', type=int, default=50)

    args = parse_args(parser)

    main(args)
 