import json
import os, errno
import sys
import time
import shutil
import subprocess
from subprocess import Popen, PIPE

BASE_NAME = 'random'

INSTANCES = [
    #('adult', 1506844911), # 0.8217306
    #('audiology', 1506863181), # 0.9886078
    ('breast', 1506930659), # 0.9663081
    #('breast_original', 1506901272), # 0.967647
    #('heart', 1506861795), # 0.8570092
    #('ionosphere', 1506867085), # 0.8453238
    #('mushrooms', 1506776153), # 1.0 
    #('phishing', 1506814280), # 0.9536304
    #('skin', 1506824485), # 0.9831426
    #('splice', 1506834690), # 0.9416073
]

def generate_random(k, n):

    with open('{}_k{}_n{}_casebase.txt'.format(BASE_NAME, k, n), 'w') as file:
        for i in range(0, k):
            file.write(' '.join(map(str, [j for j in range(i, i+n)])) + '\n')

    with open('{}_k{}_n{}_outcomes.txt'.format(BASE_NAME, k, n), 'w') as file:
        for i in range(0, k):
            file.write(str(i % 2)  + '\n')


if __name__ == '__main__':
    k_min = 100
    k_max = 10000
    k_step = 100
    k = 100

    n = 10
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
            os.remove('hcbr.global.log.csv')
        except:
            pass
        for n in range(10, 1000, 10):
            #print('- k {} {} {} {}'.format(k, k_min, k_max, k_step))
            generate_random(n, n)
            cb = '../experiments/{}_k{}_n{}_casebase.txt'.format(BASE_NAME, n, n)
            outcomes = '../experiments/{}_k{}_n{}_outcomes.txt'.format(BASE_NAME, n, n)
            cmd = "{} -c {} -o {} -l {} -s -v -p {} -e {} -d {} {} {} -b {} > {} 2> {}".format(
                    '../build/hcbr_learning',
                    cb,
                    outcomes,
                    n,
                    1,
                    0,
                    0,
                    "",
                    "",
                    0,
                    'log.txt',
                    'err.txt'
                )
            print(cmd)
            rc = subprocess.call(cmd, shell=True)
            print(rc)
            try:
                os.remove(cb)
                os.remove(outcomes)
            except:
                pass
