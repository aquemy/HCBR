import time
import random
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.datasets import make_moons, make_circles, make_classification
from sklearn.neural_network import MLPClassifier
from sklearn.neighbors import KNeighborsClassifier
from sklearn.svm import SVC
from sklearn.gaussian_process import GaussianProcessClassifier
from sklearn.gaussian_process.kernels import RBF
from sklearn.tree import DecisionTreeClassifier
from sklearn.ensemble import RandomForestClassifier, AdaBoostClassifier
from sklearn.naive_bayes import GaussianNB
from sklearn.discriminant_analysis import QuadraticDiscriminantAnalysis

from sklearn.metrics import accuracy_score, matthews_corrcoef

from sklearn.datasets import load_svmlight_file

h = .02  # step size in the mesh

names = ["Nearest Neighbors", "Linear SVM", "RBF SVM", #"Gaussian Process",
         "Decision Tree", "Random Forest", "Neural Net", "AdaBoost",
         "Naive Bayes", "QDA"]
names = ["Nearest Neighbors", "Linear SVM", "RBF SVM", "Neural Net" ]
classifiers = [
    KNeighborsClassifier(),
    SVC(kernel="linear"),
    SVC(),
    #GaussianProcessClassifier(1.0 * RBF(1.0)),
    DecisionTreeClassifier(max_depth=None),
    RandomForestClassifier(n_estimators=10, max_depth=None, max_features='auto'),
    MLPClassifier(max_iter=200),
    AdaBoostClassifier(),
    GaussianNB(),
    QuadraticDiscriminantAnalysis()
    ]

with open('../../data/breast.txt') as file:
    data_breast = file.readlines()
    data_breast = [d.split(',')[:-1] for d in data_breast]
    for i,l in enumerate(data_breast):
        data_breast[i] = [int(d) if d != '?' else 9999 for d in data_breast[i] ]
    length = len(sorted(data_breast, key=len, reverse=True)[0])
    data_breast = np.array([xi+[9999]*(length-len(xi)) for xi in data_breast])
    #data = np.array(data)
    file.close()

with open('../../data/breast_outcomes.txt') as file:
    outcomes_breast = file.readlines()
    outcomes_breast = np.array([int(o.strip()) for o in outcomes_breast])
    file.close()


with open('../../data/adult.txt') as file:
    data_adult = file.readlines()
    data_adult = [map(int, d.split()[1:]) for d in data_adult]
    length = len(sorted(data_adult, key=len, reverse=True)[0])
    data_adult = np.array([xi+[9999]*(length-len(xi)) for xi in data_adult])
    #data = np.array(data)
    file.close()

with open('../../data/adult_outcomes.txt') as file:
    outcomes_adult = file.readlines()
    outcomes_adult = np.array([int(o.strip()) for o in outcomes_adult])
    file.close()


data_mushrooms, outcomes_mushrooms = load_svmlight_file("../../data/mushrooms.txt")
data_heart, outcomes_heart = load_svmlight_file("../../data/heart.txt")
data_phishing, outcomes_phishing = load_svmlight_file("../../data/phishing.txt")
data_skin, outcomes_skin = load_svmlight_file("../../data/skin.txt")
data_splice, outcomes_splice = load_svmlight_file("../../data/splice.txt")

dataset_names = ['adult', 'breast', 'mushrooms', 'heart', 'phishing', 'skin', 'splice']
datasets = [
    (data_adult, outcomes_adult),
    (data_breast, outcomes_breast),
    (data_mushrooms, outcomes_mushrooms),
    (data_heart, outcomes_heart),
    (data_phishing, outcomes_phishing),
    (data_skin, outcomes_skin),
    (data_splice, outcomes_splice)
    ]

training_size = [0.01, 0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.99]
k = 10
for ds_cnt, ds in enumerate(datasets):
    print('# {}\n'.format(dataset_names[ds_cnt]))
    for name, clf in zip(names, classifiers):
        with open("{}_{}_training_size.txt".format(name, dataset_names[ds_cnt]), 'w') as file:
            file.write('# {}\n'.format(name))
            print('# {}\n'.format(name))
            for ts in training_size:
                real_k = 0
                try:
                    X, y = ds
                    if dataset_names[ds_cnt] in ['mushrooms', 'heart', 'phishing', 'skin', 'splice']:
                        X = X.toarray()
                    X = StandardScaler().fit_transform(X)
                    average_score = 0.0
                    average_mcc = 0.0
                    average_time = 0.0
                    for j in range(0, k):
                        start_time = time.time()
                        X_train, X_test, y_train, y_test = \
                            train_test_split(X, y, test_size=1.0 - ts, random_state=random.randint(0,10000))
                    #print(len(X_train))

                        #ax = plt.subplot(len(datasets), len(classifiers) + 1, i)
                        clf.fit(X_train, y_train)
                        pred = clf.predict(X_test)
                        score = accuracy_score(y_test, pred)
                        mcc = matthews_corrcoef(y_test, pred)
                        average_score += score
                        average_mcc += mcc
                        average_time += time.time() - start_time
                        real_k += 1
                except Exception as e:
                    pass
                if real_k != 0:
                    print('# {} {} {} {}'.format(ts, average_score / real_k, average_mcc / real_k, average_time / real_k))
                    file.write("{} {} {} {}\n".format(ts, average_score / real_k,  average_mcc / real_k, average_time / real_k))
            file.write('\n')
            file.close()