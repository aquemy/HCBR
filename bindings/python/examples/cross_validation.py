from random import randint
from subprocess import Popen, PIPE

from hcbr import HCBRClassifier

import numpy as np
from sklearn.metrics import accuracy_score, matthews_corrcoef
from sklearn.model_selection import train_test_split, RepeatedStratifiedKFold, RepeatedKFold


HCBR_BIN = '../../../build/hcbr'
DATASET = 'breast'

def example_1(clf, X, y):
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.1)
    clf.fit(X_train, y_train)

    pred = clf.predict(X_test, y_test)
    score = accuracy_score(y_test, pred)
    mcc = matthews_corrcoef(y_test, pred)
    print(score, mcc)

def example_2(clf, X, y):
    random_state = randint(0,2**32)
    k=10
    n=5
    rkf = RepeatedStratifiedKFold(n_splits=k, n_repeats=n, random_state=random_state)
    averages = [0] * n 
    for i, (train, test) in enumerate(rkf.split(X, y)):
        it = i // k
        X_train, X_test, y_train, y_test = X[train], X[test], y[train], y[test]
        clf.fit(X_train, y_train)
        pred = clf.predict(X_test, y_test)

        acc = accuracy_score(y_test, pred)
        mcc = matthews_corrcoef(y_test, pred)
        print(it, acc, mcc)
        averages[it] += acc
    averages = map(lambda x: x / k, averages)
    print('BEST ACCURACY: {}'.format(max(averages)))

def main():

    # Load the dataset
    with open('../../../data/{}_casebase.txt'.format(DATASET)) as file:
        X = file.readlines()
        X = np.array([map(int, d.split()) for d in X])
        file.close()

    with open('../../../data/{}_outcomes.txt'.format(DATASET)) as file:
        y = file.readlines()
        y = np.array([int(o.strip()) for o in y])
        file.close()

    # Create the classifier by specifying the configuration file
    clf = HCBRClassifier(params_file='../../../data/parameters/{}.params.json'.format(DATASET))

    # example 1: simple split
    print('----- EXAMPLE 1 -----')
    example_1(clf, X, y)

    # example 2: stratified K-fold cross-validation
    print('----- EXAMPLE 2 -----')
    example_2(clf, X, y)


if __name__ == '__main__':
    main()
