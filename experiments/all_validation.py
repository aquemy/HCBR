import os
import sys
import time
import subprocess

LOG_FILE = "validation.log"

'''
Instances and seeds used for the article 'Binary Classification On Hypergraphs'
'''
INSTANCES = [
    #('adult', 1506844911), # 0.8217306
    #('audiology', 1506863181), # 0.9886078
    #('breast', 1506930659), # 0.9663081
    #('breast_original', 1506901272), # 0.967647
    #('heart', 1506861795), # 0.8570092
    #('ionosphere', 1506867085), # 0.8453238
    #('mushrooms', 1506776153), # 1.0 
    #('phishing', 1506814280), # 0.9536304
    ('skin', 1506824485), # 0.9831426
    #('splice', 1506834690), # 0.9416073
]

def main():
    kfold = 10
    training_set_pct = 0.6
    print('########################################################')
    print('# ALL VALIDATION')
    print('########################################################')
    for instance in INSTANCES:
        print('########################################################')
        print('# INSTANCE {}'.format(instance[0]))
        print('########################################################')
        seed = int(time.time()) if instance[1] is None else instance[1]
        print('# Seed: {}'.format(seed))
        cmd = "python validation_wrapper.py {} {} {} {} 2>> {}".format(
            kfold,
            training_set_pct,
            instance[0],
            seed, 
            LOG_FILE
        )
    	rc = subprocess.call(cmd, shell=True)
       
if __name__ == '__main__':
    main()