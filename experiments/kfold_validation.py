import os, errno
import sys
import time
from random import shuffle
import random

def read_cases(path):
    cases = []
    headers = []
    with open(path, 'rb') as csvfile:
        reader = csvfile.readlines()
        n = len(reader[0].split())
        for i, row in enumerate(reader):
            case = row.split()[:]
            cases.append(case)
    return cases

def read_outcomes(path):
    cases = []
    headers = []
    with open(path, 'rb') as csvfile:
        reader = csvfile.readlines()
        n = len(reader[0].split())
        for i, row in enumerate(reader):
            cases.append(int(row))
    return cases

def main():
    k = int(sys.argv[1])
    path_casebase = sys.argv[2]
    path_outcomes = sys.argv[3]
    output_folder = sys.argv[4]
    seed = None
    if len(sys.argv) > 5:
        seed = sys.argv[5]
    l = 1.0
    if len(sys.argv) > 6:
        l = float(sys.argv[6])
    file_name = path_casebase.split('/')[-1].split('.')[0]
    base_name = '_'.join(file_name.split('.')[0].split('_')[:-1])

    cases = read_cases(path_casebase)
    outcomes =read_outcomes(path_outcomes)

    if len(cases) != len(outcomes):
        print('Casebase and outcome file are not the same length!')
        exit(1)
    n = int(len(cases) * l)

    cases = cases[:n]
    outcomes = outcomes[:n]

    n = len(cases)
    hf = float(n) / k
    h = int(round(hf))
    lfs = int(n - (k-1) * h)
    prev = len([i for i in outcomes if i == 1]) / float(n)

    index = [i for i in range(0, n)]
    if seed is not None:
        random.seed(seed)
        shuffle(index)

    print("Casebase size : {}".format(n))
    print("Fold number   : {}".format(k))
    print("Fold size     : {}".format(h))
    print("Last fold size: {}".format(lfs))
    print("Prevalence    : {:0.4f}".format(prev))

    for i in range(0, k):
        print("Fold {}".format(i))
        m = i*h #if i < k - 1 else (i-1)*h + lfs
        #l = (i+k)*h + lfs
        print("  [{} ; {}]".format(m,(h+m) % n))

        prev = len([j for j in index[m:h+m] if outcomes[j] == 1]) / float(h if i < k - 1 else lfs)
        print("  Prev.: {:0.4f}".format(prev))

        casebase_output = os.path.join(output_folder, '{}_casebase.fold_{}.txt'.format(base_name, i))
        outcomes_output = os.path.join(output_folder, '{}_outcomes.fold_{}.txt'.format(base_name, i))

        try:
            os.remove(casebase_output)
            os.remove(outcomes_output)
        except:
            pass
        try:
            os.makedirs(output_folder)
        except OSError as e:
            if e.errno != errno.EEXIST:
                raise

        with open(casebase_output, 'a') as file:
            for j in index[m:] + index[0:m]:
                for e in cases[j]:
                    file.write('{} '.format(e))
                file.write('\n')

        with open(outcomes_output, 'a') as file:
            for j in index[m:] + index[0:m]:
                file.write('{}\n'.format(outcomes[j]))

if __name__ == '__main__':
    main()