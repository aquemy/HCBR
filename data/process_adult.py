import csv
import os
import sys

def read_cases(path):
    cases = []
    outcomes = []
    headers = []
    with open(path, 'rb') as csvfile:
        reader = csvfile.readlines()
        n = len(reader[0].split())
        for i, row in enumerate(reader):
            cases.append(row.split()[1:])
            outcomes.append(row.split()[0])
    return cases, outcomes


def main():
    path = sys.argv[1]
    file_name = path.split('/')[-1].split('.')[0]
    base_name = file_name.split('.')[0]
    cases, outcomes = read_cases(path)

    casebase_output = '{}_casebase.txt'.format(base_name)
    outcomes_output = '{}_outcomes.txt'.format(base_name)

    try:
        os.remove(casebase_output)
        os.remove(outcomes_output)
    except:
        pass

    with open(casebase_output, 'a') as file:
        for case in cases:
            for e in case:
                file.write('{} '.format(e))
            file.write('\n')

    with open(outcomes_output, 'a') as file:
        for o in outcomes:
            file.write('{}\n'.format('1' if o == '-1' else '0'))


if __name__ == '__main__':
    main()