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

def read_cases(path):
    cases = []
    headers = []
    with open(path, 'rb') as csvfile:
        reader = csvfile.readlines()
        n = len(reader[0].split(' '))
        for i, row in enumerate(reader):
            r = map(str.strip, row.strip().split(' '))
            t = []
            for i, e in enumerate(r):
                if i == 0:
                    t.append(e)
                else:
                    #print(e.split(':'))
                    v = '{}:{}'.format(e.split(':')[0], reduce_precision(e.split(':')[1], 2))
                    t.append(v)
            cases.append(t)

    return cases

def reduce_precision(f, prec=2):
    return '{:.2}'.format(round(float(f), prec))

def main():
    path = sys.argv[1]
    file_name = path.split('/')[-1].split('.')[0]
    base_name = file_name.split('.')[0]
    cases = read_cases(path)

    outcome_row = 0
    except_features_no_outcomes = [0]

    final_cases = filter_cases(cases, except_features_no_outcomes)
    casebase_output = '{}_casebase.txt'.format(base_name)
    outcomes_output = '{}_outcomes.txt'.format(base_name)

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
        for case in cases:
            file.write('{}\n'.format('0' if case[outcome_row] == '-1' else '1'))



if __name__ == '__main__':
    main()