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


def main(args):

    #hcbr_traiing_pred = pandas.read_table('/home/aquemy/dev/cbr/build/training_set_prediction_post_training.txt', delim_whitespace=True, header=None)
    #print(hcbr_traiing_pred)
    instance = args.instance
    runs = int(args.runs)

    res = []
    average_iacc = 0.
    average_imcc = 0.
    average_facc = 0.
    average_fmcc = 0.
    for i in range(0, runs):
        with open('{}_res_{}.txt'.format(instance, i)) as f:
            content = f.readlines()
            initial_accuracy = float(content[2].split(':')[1].strip())
            initial_mcc = float(content[3].split(':')[1].strip())
            final_accuracy = float(content[-2].strip())
            final_mcc = float(content[-1].strip())
            content = [[float(t.strip()) for t in l.strip().split('\t')] for l in content[8:-2]]

            average_iacc += initial_accuracy
            average_imcc += initial_mcc
            average_facc += final_accuracy
            average_fmcc += final_mcc

            if len(res) == 0:
                res = content
            else:
                for j, l in enumerate(content):
                    for k, e in enumerate(l):
                        res[j][k] += e

    for j, l in enumerate(content):
        for k, e in enumerate(l):
            res[j][k] /= runs

    average_iacc /= runs
    average_imcc /= runs
    average_facc /= runs
    average_fmcc /= runs

    print(average_iacc)
    print(average_imcc)
    print(average_facc)
    print(average_fmcc)
    print('\n\n')
    for gen in content:
        print('{}'.format(' '.join(map(str, gen))))


def parse_args(parser0):
    args = parser.parse_args()

    # Check path
    return args

if __name__ == "__main__":
    
    parser = argparse.ArgumentParser(description='Adjust model')
    parser.add_argument('--instance', type=str)
    parser.add_argument('--runs', type=str)

    args = parse_args(parser)

    main(args)
 