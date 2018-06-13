import argparse
import pandas
import os
import numpy as np
import matplotlib.pyplot as plt
import functools
from collections import Counter
import math
import random
from sklearn.preprocessing import scale

S1_ROW = 5
S0_ROW = 6
PRED_ROW = 3
OUT_ROW = 2

def brier(S, input_):
    s = 0.0
    for i, e in enumerate(input_[OUT_ROW]):
        s += (S[i] - e) ** 2
    return s / len(S)

def main(args):
    input_ = pandas.read_table(args.input, delim_whitespace=True, header=None)

    S = input_[S1_ROW] - input_[S0_ROW]
    S = (S - S.min()) / (S.max() - S.min())
    print(brier(S, input_))


def parse_args(parser0):
    args = parser.parse_args()

    # Check path
    return args

if __name__ == "__main__":
    
    parser = argparse.ArgumentParser(description='Adjust model')
    parser.add_argument('--input', type=str)

    args = parse_args(parser)

    main(args)
 