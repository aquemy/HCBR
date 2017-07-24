import csv
import os
import sys

def feature_to_index(cases, column_nb, offset=0):
    feature_set = set()
    for case in cases:
        feature_set.add(case[column_nb])
    l = list(feature_set)
    index = {}
    for i, f in enumerate(l):
        index[f] = i + offset
    return index

def filter_cases(cases, except_features):
    features_index = []
    features_mapping = {}
    offset = 0
    for j, f in enumerate([i for i in range(0, len(cases[0])) if i not in except_features]):
        feat = feature_to_index(cases, f, offset)
        features_index.append(feat)
        features_mapping[f] = j
        offset += len(feat)

    final_cases = []
    i = 0
    for case in cases:
        if case[36] not in ['0', '1']:
            continue # Skip the cases without reported outcome
        final_cases.append([])
        for j, f in enumerate(case):
            if j not in except_features:
                translation = features_index[features_mapping[j]][case[j]]
                if case[j] is None or case[j] not in ['']:
                    final_cases[i].append(translation)
        i += 1
    return final_cases

def read_cases(path):
    cases = []

    with open(path, 'rb') as csvfile:
        reader = csv.reader(csvfile, delimiter=',', quotechar='"')
        for i, row in enumerate(reader):
            if i == 0:
                continue
            cases.append(row)

    return cases


def main():
    path = sys.argv[1]
    file_name = path.split('/')[-1].split('.')[0]
    base_name = file_name.split('.')[0]
    cases = read_cases(path)

    outcome_row = 36
    year_column = 10
    except_features_no_outcomes = [0, 1, 2, 3, 6, 7, 8, 9, 14, 36, 37, 38, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52]

    final_cases = filter_cases(cases, except_features_no_outcomes)
    casebase_output = '{}_casebase.txt'.format(base_name)
    outcomes_output = '{}_outcomes.txt'.format(base_name)
    terms_output = '{}_terms.txt'.format(base_name)

    try:
        os.remove(casebase_output)
        os.remove(outcomes_output)
    except:
        pass

    with open(terms_output, 'a') as file:
        current = None
        for i, case in enumerate(cases):
            if case[outcome_row] not in ['0', '1']:
                continue # Skip the cases without reported outcome
            if case[year_column] != current:
                file.write('{} {}\n'.format(i, case[year_column]))
                current = case[year_column]
           
    with open(casebase_output, 'a') as file:
        for case in final_cases:
            for e in case:
                file.write('{} '.format(e))
            file.write('\n')

    with open(outcomes_output, 'a') as file:
        for case in cases:
            if case[outcome_row] not in ['0', '1']:
                continue # Skip the cases without reported outcome
            file.write('{}\n'.format(case[outcome_row]))

if __name__ == '__main__':
    main()