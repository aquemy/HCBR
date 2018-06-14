import json
from random import randint
from subprocess import Popen, PIPE

import numpy as np
from sklearn.base import BaseEstimator, ClassifierMixin
from sklearn.metrics import accuracy_score, matthews_corrcoef
from sklearn.model_selection import train_test_split, RepeatedStratifiedKFold, RepeatedKFold
from sklearn.datasets import load_svmlight_file

HCBR_BIN='../../../build/hcbr'

class HCBRClassifier(BaseEstimator, ClassifierMixin):  

    def __init__(self, params_file):
        self.params_file = params_file
        self.params = None
        self.local_training_param_file = './training.params.json'
        self.HCBR_BIN = HCBR_BIN

    def fit(self, X, y=None):
        # Check parameters
        try:
            self.params = json.load(open(self.params_file))
        except Exception as e:
            print("Could not load parameter file...")
            print(e)
            return None

        # Modifying configuration
        try:
            self.params['input']['source'] = 'stdin'

            self.params['serialization']['serialize'] = True
            self.params['parameters']['no_prediction'] = True
            self.params['deserialization']['deserialize'] = False
            self.params['parameters']['limit'] = len(X)
            with open(self.local_training_param_file, 'w') as f:
                f.write(json.dumps(self.params, indent=4))
        except Exception as e:
            print("Could not modify and save the parameter file")
            print(e)
            return None

        # Build the model and output the files
        try:
            cmd = [self.HCBR_BIN, '--params', self.local_training_param_file]
            p = Popen(cmd, stdin=PIPE, stdout=PIPE, stderr=PIPE)
            data = []
            for i,yi in enumerate(y):
                data.append(list(X[i]) + [yi])
            data_str = '\n'.join([' '.join(map(str, d)) for d in data])
            output, err = p.communicate(input=data_str)
        except Exception as e:
            print("Could not build the model")
            print(e)
            return None

        return self

    def predict(self, X, y=None):
        # Modifying configuration
        try:
            self.params['serialization']['serialize'] = False
            self.params['parameters']['no_prediction'] = False
            self.params['deserialization']['deserialize'] = True
            self.params['parameters']['limit'] = 0
            self.params['parameters']['keep_offset'] = False
            self.params['parameters']['training_iterations'] = 0
            with open(self.local_training_param_file, 'w') as f:
                f.write(json.dumps(self.params, indent=4))
        except Exception as e:
            print("Could not modify and save the parameter file")
            print(e)
            return None

        # Build the model and output the files
        res = []
        try:
            cmd = [self.HCBR_BIN, '--params', self.local_training_param_file]
            p = Popen(cmd, stdin=PIPE, stdout=PIPE, stderr=PIPE)
            data = []
            for i,yi in enumerate(y):
                data.append(list(X[i]) + [yi])
            data_str = '\n'.join([' '.join(map(str, d)) for d in data])
            output, err = p.communicate(input=data_str)
            output = open('predictions.txt', 'r').read().strip()
            res = [int(o.split()[2]) for o in output.splitlines()[1:]]
        except Exception as e:
            print("Could not make prediction")
            print(e)
            return None
        return res

    def score(self, X, y=None):
        pred = predict(X, y)
        return accuracy_score(y, pred)

'''
with open('../../data/breast_casebase.txt') as file:
    data = file.readlines()
    data = np.array([map(int, d.split()) for d in data])
    file.close()

with open('../../data/breast_outcomes.txt') as file:
    outcomes = file.readlines()
    outcomes = np.array([int(o.strip()) for o in outcomes])
    file.close()

X = data
y = outcomes
clf = HCBRClassifier(params_file='../../data/parameters/breast.params.json')
#X = X.toarray()
#X = StandardScaler().fit_transform(X)

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.1)
clf.fit(X_train, y_train)

pred = clf.predict(X_test, y_test)
score = accuracy_score(y_test, pred)
mcc = matthews_corrcoef(y_test, pred)
print(score, mcc)

random_state = randint(0,2**32)
k=10
n=1
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
print('{} {}'.format(random_state, max(averages)))
'''