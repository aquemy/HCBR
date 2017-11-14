import os
import sys
import time
import subprocess

LOG_FILE = "validation.log"
ONLY_ANALYSIS = False

'''
Instances and seeds used for the article 'Binary Classification On Hypergraphs'
'''
INSTANCES = [
    ('adult', 1509029032), #    0.8206451 1506844911), # 0.8217306
    ('audiology', 1509000373), #OK 0.9947368 1506863181), # 0.9886078
    ('breast', 1509009986), # OK 0.9695652 1506930659), # 0.9663081
    ('breast_original', 1506901272), # 0.967647
    ('heart', 1508982364), # OK 0.8576923 1506861795), # 0.8570092
    ('ionosphere', 1506867085), # 0.8453238
    ('mushrooms', 1508973358), # OK 1 #1506776153), # 1.0 
    ('phishing', 1508982614), # OK 0.9605072 # 1506814280), # 0.9536304
    ('skin', 1508993549), # OK 0.9864599 #1506824485), # 0.9831426
    ('splice', 1509028798), # OK    0.9443038 # 1506834690), # 0.9416073
]

'''
INSTANCES = [
    ('echr_circumstances_6', None),
    ('echr_circumstances_8', None),
    ('echr_circumstances_3', None),
    ('echr_full_6', None),
    ('echr_full_8', None),
    ('echr_full_3', None),
    ('echr_law_6', None),
    ('echr_law_8', None),
    ('echr_law_3', None),
    ('echr_procedure_3', None),
    ('echr_procedure_6', None),
    ('echr_procedure_8', None),
    ('echr_relevantLaw_6', None),
    ('echr_relevantLaw_8', None),
    ('echr_relevantLaw_3', None)
]
'''

def main():
    kfold = 10
    training_set_pct = 0.9
    print('########################################################')
    print('# ALL VALIDATION')
    print('########################################################')
    for instance in INSTANCES:
        print('########################################################')
        print('# INSTANCE {}'.format(instance[0]))
        print('########################################################')
        seed = int(time.time()) if instance[1] is None else instance[1]
        print('# Seed: {}'.format(seed))
        cmd = "python validation_wrapper.py {} {} {} {} {} 2>> {}".format(
            kfold,
            training_set_pct,
            instance[0],
            seed,
            ONLY_ANALYSIS,
            LOG_FILE
        )
    	rc = subprocess.call(cmd, shell=True)
        print("RUN RC: {}".format(rc))
       
if __name__ == '__main__':
    main()
