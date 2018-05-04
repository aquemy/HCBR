import os
import sys
import time
import subprocess

LOG_FILE = "validation.log"
ONLY_ANALYSIS = False
NESTED_CROSS_VALIDATION = True

'''
Instances and seeds used for the article 'Binary Classification On Hypergraphs'
'''
INSTANCES = [
    #('adult', None), #1509029032), #    0.8206451 1506844911), # 0.8217306
    #('audiology', 1509000373), #OK 0.9947368 1506863181), # 0.9886078
    ('breast', None) #1506930659), # OK 0.9695652 1506930659), # 0.9663081
    #('breast_original', 1506901272), # 0.967647
    #('heart', None), #1508982364), # OK 0.8576923 1506861795), # 0.8570092
    #('ionosphere', 1506867085), # 0.8453238
    #('mushrooms', 1508973358), # OK 1 #1506776153), # 1.0 
    #('phishing', 1508982614), # OK 0.9605072 # 1506814280), # 0.9536304
    #('skin', 1508993549), # OK 0.9864599 #1506824485), # 0.9831426
    #('splice', None) #1509028798), # OK    0.9443038 # 1506834690), # 0.9416073
]

'''
INSTANCES = [
    ('echr_full_3', None),#None),#1509757550),
    ('echr_full_6', None),
    ('echr_full_8', None),
    ('echr_procedure_3', None),
    ('echr_procedure_6', None),
    ('echr_procedure_8', None),
    ('echr_circumstances_3', None),
    ('echr_circumstances_6', None),
    ('echr_circumstances_8', None),
    ('echr_relevantLaw_3', None),
    ('echr_relevantLaw_6', None),
    ('echr_relevantLaw_8', None),
    ('echr_facts_3', None),
    ('echr_facts_6', None),
    ('echr_facts_8', None),
    ('echr_law_3', None),
    ('echr_law_6', None),
    ('echr_law_8', None)
]
#'''
'''
INSTANCES = [
    ('credo', None)
]
'''
'''
INSTANCES = [
    ('echr_full_3', 1509757550),
    ('echr_law_3', 1510764127),
    ('echr_procedure_3', 1509819902),
    ('echr_relevantLaw_3', 1510841250),
    ('echr_circumstances_3', 1511020246),
    #('echr_topics_3', None),
    #('echr_topics_circ_3', None),

    ('echr_full_6', 1509846129),
    ('echr_law_6', 1511038259),
    ('echr_procedure_6', 1509943643),
    ('echr_relevantLaw_6', 1510824274),
    ('echr_circumstances_6', 1509889420),
    #('echr_topics_6', None),
    #('echr_topics_circ_6', None),

    ('echr_full_8', 1510928265),
    ('echr_law_8', 1509911215),
    ('echr_procedure_8', 1510758528),
    ('echr_relevantLaw_8', None),
    ('echr_circumstances_8', None),
    #('echr_topics_8', None),
    #('echr_topics_circ_8', None)
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
        cmd = "python validation_wrapper.py {} {} {} {} {} {} 2>> {}".format(
            kfold,
            training_set_pct,
            instance[0],
            seed,
            ONLY_ANALYSIS,
            NESTED_CROSS_VALIDATION,
            LOG_FILE
        )
    	rc = subprocess.call(cmd, shell=True)
        print("RUN RC: {}".format(rc))
       
if __name__ == '__main__':
    main()
