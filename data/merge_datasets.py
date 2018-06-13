import csv
import os
import sys

def read_cases(path):
    cases = []
    headers = []
    with open(path, 'rb') as csvfile:
        reader = csvfile.readlines()
        n = len(reader[0].split())
        m = 0
        for i, row in enumerate(reader):
            r = row.split()
            cases.append(r)
            lm = max(r)
            m = m if lm < m else lm
    return cases, m


def main():
    base_name1 = sys.argv[1]
    base_name2 = sys.argv[2]

    casebase_1_p = '{}_casebase.txt'.format(base_name1)
    outcomes_1_p = '{}_outcomes.txt'.format(base_name1)

    casebase_2_p = '{}_casebase.txt'.format(base_name2)
    outcomes_2_p = '{}_outcomes.txt'.format(base_name2)

    cases1, offset1 = read_cases(casebase_1_p)
    cases2, offset2 = read_cases(casebase_2_p)

    outcomes1 = []
    outcomes2 = []
    with open(outcomes_1_p, 'rb') as file:
        outcomes1 = file.readlines()

    with open(outcomes_2_p, 'rb') as file:
        outcomes2 = file.readlines()

    min_l = len(cases1) if len(cases1) < len(cases2) else len(cases2)

    cases1 = cases1[:min_l]
    cases2 = cases2[:min_l]
    outcomes1 = outcomes1[:min_l]
    outcomes2 = outcomes2[:min_l]

    casebase_output = '{}+{}_casebase.txt'.format(base_name1, base_name2)
    outcomes_output = '{}+{}_outcomes.txt'.format(base_name1, base_name2)

    try:
        os.remove(casebase_output)
        os.remove(outcomes_output)
    except:
        pass

    for i, c in enumerate(cases2):
        cases1.append([f + offset1 for f in c])
        outcomes1.append(outcomes2[i])

    with open(casebase_output, 'a') as file:
        for case in cases1:
            for e in case:
                file.write('{} '.format(e))
            file.write('\n')

    with open(outcomes_output, 'a') as file:
        for o in outcomes1:
            file.write('{}\n'.format(o.strip()))


if __name__ == '__main__':
    main()