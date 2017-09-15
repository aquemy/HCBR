from sklearn.cluster import KMeans
import numpy as np
import csv
import os
import sys

if __name__ == '__main__':
    path = 'Justice.csv'
    justices = []
    ideology = []
    qualification = []
    with open(path, 'rb') as csvfile:
        reader = csv.reader(csvfile, delimiter=',', quotechar='"')
        for i, row in enumerate(reader):
            if i == 0:
                continue
            justices.append(row)
            ideology.append([float(row[2])])
            qualification.append([float(row[3])])
    
    x = ideology
    km = KMeans(n_clusters=5)
    r = km.fit_predict(x)
    for i, j in enumerate(justices):
        j[2] = km.cluster_centers_[r[i]][0]

    x = qualification
    km = KMeans(n_clusters=5)
    r = km.fit_predict(x)
    #print(km.cluster_centers_)
    for i, j in enumerate(justices):
        j[3] = km.cluster_centers_[r[i]][0]

    justice_output = 'justice_base.txt'
    with open(justice_output, 'a') as file:
        for j in justices:
            for e in j:
                file.write('"{}", '.format(e))
            file.write('\n')
    
    #print(km.cluster_centers_[e][0])