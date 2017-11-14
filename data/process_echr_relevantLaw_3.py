import csv
import os
import sys

def feature_to_index(cases, column_nb, offset=0):
    feature_set = set()
    for case in cases:
        if len(case) > column_nb:
            feature_set.add(case[column_nb])
    l = list(feature_set)
    index = {}
    i = 0
    for f in l:
        if f != '':
            index[f] = i + offset
            i += 1
    return index

def filter_cases(cases, except_features):
    features_index = []
    features_mapping = {}
    offset = 0
    m = len(cases[0])
    for c in cases:
        if len(c) > m:
            m = len(c)
    for j, f in enumerate([i for i in range(0, m) if i not in except_features]):
        feat = feature_to_index(cases, f, offset)
        features_index.append(feat)
        features_mapping[f] = j
        offset += len(feat)

    final_cases = []
    i = 0
    for case in cases:
        final_cases.append([])
        for j, f in enumerate(case):
            if j not in except_features:
                if case[j] is None or case[j] not in ['']:
                    translation = features_index[features_mapping[j]][case[j]]
                    final_cases[i].append(translation)
        i += 1
        
    return final_cases

def read_cases(path, sep=','):
    cases = []
    headers = []
    with open(path, 'rb') as csvfile:
        reader = csvfile.readlines()
        n = len(reader[0].split(sep))
        for i, row in enumerate(reader):
            d = row.split(sep)
            d = map(str.strip, d)
            #d = [e for e in d if e != '0.000000000000000000e+00']
            #print(len(d))
            cases.append(d)

    return cases


def main():
    path = '../data/echr_dataset/Article3/ngrams_a3_relevantLaw.csv'
    #path = './echr_dataset/Article3/topics3.csv'
    file_name = path.split('/')[-1].split('.')[0]
    base_name = file_name.split('.')[0]
    cases = read_cases(path, sep=',')
    s = 0.
    n = 0
    v = 0.
    for i, c in enumerate(cases):
        #print(c)
        for j, f in enumerate(c):
            cases[i][j] = f if f != '0.000000000000000000e+00' else ''
            s += float(f) if f != '0.000000000000000000e+00' else 0
            n += 1 if f != '0.000000000000000000e+00' else 0
            v += float(f)*float(f) if f != '0.000000000000000000e+00' else 0
        #print(cases[i])
    print('SUM: {} - WORD: {}'.format(s, n))
    print('AVG: {} - VAR: {}'.format(s / n, v / n - (s / n)**2))
    n2 = 0
    v = (v / n) - (s / n)**2
    for i, c in enumerate(cases):
        #print(c)
        for j, f in enumerate(c):
            if f != '' and float(f) > (s / n) + 3*v:
                cases[i][j] = 1
                n2 += 1
            else:
                cases[i][j] = ''
    print('NEW WORDS: {}'.format(n2))


    outcome_file = '../data/echr_dataset/Article3/cases_a3.csv'

    except_features_no_outcomes = []


    final_cases = filter_cases(cases, except_features_no_outcomes)
    casebase_output = 'echr_relevantLaw_3_casebase.txt'.format(base_name)
    outcomes_output = 'echr_relevantLaw_3_outcomes.txt'.format(base_name)

    outcomes = read_cases(outcome_file)
    final_outcomes = filter_cases(outcomes, [0])

    try:
        os.remove(casebase_output)
        os.remove(outcomes_output)
    except:
        pass

    with open(casebase_output, 'a') as file:
        for case in final_cases:
            for e in case:
                file.write('{} '.format(e))
            file.write('\n')

    with open(outcomes_output, 'a') as file:
        for case in final_outcomes:
            file.write('{}\n'.format(case[0]))



if __name__ == '__main__':
    main()