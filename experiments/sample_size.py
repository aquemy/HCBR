import os
import csv
import sys
import time
import subprocess

LOG_FILE = "validation.log"
ONLY_ANALYSIS = False

'''
Instances and seeds used for the article 'Binary Classification On Hypergraphs'
'''
INSTANCES = [
    ('adult', None), # 1509029032), # 0.8217306
    #('audiology', 1506863181), # 0.9886078
    #('breast', 1509009986), # 0.9663081
    #('breast_original', 1506901272), # 0.967647
    #('heart', 1508982364), # 0.8570092
    #('ionosphere', 1506867085), # 0.8453238
    #('mushrooms', 1508973358), # 1.0 
    #('phishing', 1508982614), # 0.9536304
    #('skin', 1508993549), # 0.9831426
    #('splice', 1509028798), # 0.9416073
]

def read_csv(path):
    cases = []
    headers = []
    with open(path, 'rb') as csvfile:
        reader = csv.reader(csvfile, delimiter=',', quotechar='"')
        for i, row in enumerate(reader):
            if i == 0:
                continue
            cases.append(row)
        with open(path, 'rb') as file:
            headers = map(str.strip, file.readlines()[0].split(','))
    return headers, cases


def main():
    kfold = 10
    training_set_pct = [0.01, 0.05, 0.10, 0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80, 0.90, 0.99]
    print('########################################################')
    print('# SAMPLE SIZE VALIDATION')
    print('########################################################')
    for instance in INSTANCES:
        print('########################################################')
        print('# INSTANCE {}'.format(instance[0]))
        print('########################################################')
        seed = int(time.time()) if instance[1] is None else instance[1]
        print('# Seed: {}'.format(seed))
        try:
            os.remove('{}.size.txt'.format(instance[0]))
        except:
            pass
        try:
            os.remove('hcbr.global.log.csv')
        except:
            pass
        for pct in training_set_pct:
            cmd = "python validation_wrapper.py {} {} {} {} {} {} 2>> {}".format(
                kfold,
                pct,
                instance[0],
                seed,
                ONLY_ANALYSIS,
                pct,
                LOG_FILE
            )
            print(cmd)
            rc = subprocess.call(cmd, shell=True)
            
            #fold_output_path = os.path.join("{}_{}".format(instance[0], pct))
            fold_output_path = os.path.join("{}".format(instance[0]))
            path = os.path.join(fold_output_path, 'hcbr.global.log.csv')
            h, res = read_csv(path)
            '''
            7 - building time
            31 - learning time
            30 - strength time
            38 - perdiction time
            46 - accuracy
            60 - MCC
            34 - accuracy training
            '''
            columns = [6, 29, 30, 37, 46, 60, 34]
            s = [0.] * 6
            for k, l in enumerate(res):
                for j, i in enumerate(columns):
                    if j == 3:
                        print(k, h[i], float(l[i].strip()), s[j])
                    #print(j, l[i].strip())
                    s[j] += float(l[i].strip())
            print('building: {}'.format(s[0] / kfold))
            print('strength: {}'.format(s[1] / kfold))
            print('learning: {}'.format(s[2] / kfold))
            print('prediction: {}'.format(s[3] / kfold))
            print('total: {}'.format((s[0] + s[1] + s[2] + s[3]) / kfold))
            print('accuracy: {}'.format(s[4] / kfold))
            print('MCC: {}'.format(s[5] / kfold))
            print('training accuracy: {}'.format(s[6] / kfold))

            
            with open('{}.size.txt'.format(instance[0]), 'a') as file:
                file.write('{} {} {} {} {} {} {} {} {}\n'.format(
                    pct, 
                    kfold, 
                    s[0] / kfold, 
                    s[1] / kfold, 
                    s[2] / kfold,
                    s[3] / kfold, 
                    (s[0] + s[1] + s[2] + s[3]) / kfold, 
                    s[4] / kfold,
                    s[5] / kfold,
                    s[6] / kfold
                ))


if __name__ == '__main__':
    main()
