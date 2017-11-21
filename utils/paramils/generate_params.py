import csv
import os
import sys
import math

def reduce_precision(value, prec=2):
    return "{:.{}f}".format(round(float(value), prec), prec)

def generate_linear_grid(n=100, a=0, b=1):
    h = float(b - a) / n
    prec = int(math.log10(n / float(b - a)) + 2)
    last_h = b - h
    grid = []
    for i in range(0, n):
        v = int(i)*h
        grid.append(float(reduce_precision(v, prec)))
    grid.append(str(b))
    return grid


def generate_linear_grid_by_inc(h_zero=1, a=0, b=1):
    h = a + h_zero
    prec = int(math.log10(1 / h_zero + 1) + 1)
    grid = []
    grid.append(str(a))
    while(h < b):
        grid.append(reduce_precision(h, prec))
        h += h_zero
    grid.append(str(b))
    return grid


def generate_log_grid(n=100, a=0, b=1, base=100000):
    h = float(b - a) / n
    s = 0
    grid = []
    while(pow(base, s) - 1 < base):
        grid.append(pow(base, s) - 1)
        s += h
    grid = [reduce_precision(e / base, int(math.log10(base) + 1)) for e in grid] + [str(b)]

    return grid


def neg(grid, prec):
    prec = int(math.log10(1 / prec) + 1)
    for i, v in enumerate(grid):
        grid[i] = str(reduce_precision(-float(v), prec))
    return grid

def format_grid(grid):
    return '{' + '{}'.format(', '.join(grid)) + '}'

def format_params(params):
    res = ""
    for k, v in params.iteritems():
        res += "{} {}[{}]\n".format(k, format_grid(map(str, v['grid'])), str(v['default']))
    return res

def generate_scenario(instance_name, timeout):
    return "algo = ./hcbr_wrapper.sh\n\
execdir = ../utils/paramils/hcbr_tuning/\n\
deterministic = 1\n\
run_obj = qual\n\
overall_obj = mean\n\
cutoff_time = max\n\
cutoff_length = max\n\
tunerTimeout = {timeout}\n\
paramfile = ../utils/paramils/hcbr_tuning/hcbr/{instance}-params.txt\n\
outdir = ../utils/paramils/hcbr_tuning/results/hcbr/paramils\n\
instance_file = ../utils/paramils/hcbr_tuning/hcbr-inst.txt\n\
test_instance_file = ../utils/paramils/hcbr_tuning/hcbr-inst.txt".format(timeout=timeout, instance=instance_name)

def generate_params(instance_name, training_set_size):
    base_instance_name = '_'.join(instance_name.split('.')[0].split('_')[:-1])
    fold = instance_name.split('.')[1]
    casebase = "../../../experiments/{}/input_data/{}.txt".format(base_instance_name, instance_name)
    outcomes = "../../../experiments/{}/input_data/{}_outcomes.{}.txt".format(base_instance_name, base_instance_name, fold)
    params = {
        'l': {
            'default': training_set_size,
            'grid': [training_set_size]
        },
        'c': {
            'default': casebase,
            'grid': [casebase]
        },
        'o': {
            'default': outcomes,
            'grid': [outcomes]
        },
        'r': {
            'default': 0,
            'grid': [0]
        },
        'z': {
            'default': 1,
            'grid': [0,1]
        },
        'i': {
            'default': 1,
            'grid': [0, 1]
        },
        'p': {
            'default': 1,
            'grid': [0,1,2,5,10,20,30,50,100]#\
                #map(int, map(float, generate_linear_grid_by_inc(1, 0, 10)))# +
                #map(int, map(float, generate_linear_grid_by_inc(10, 20, 100))) +
                #map(int, map(float, generate_linear_grid_by_inc(100, 200, 500)))
        },
        'g': {
            'default': '0.000000',
            'grid': \
                generate_log_grid(100, 0, 1) +
                neg(generate_log_grid(100, 0, 1), 0.0000001)
        },
        'd': {
            'default': '0.000000',
            'grid': \
                generate_log_grid(100, 0, 1) +
                neg(generate_log_grid(100, 0, 1), 0.0000001)
        },
        'e': {
            'default': '0.000000',
            'grid': \
                generate_log_grid(100, 0, 1) +
                neg(generate_log_grid(100, 0, 1), 0.0000001)
        }

    }
    return format_params(params)

def main(instance_name, timeout, training_set_size):
    params = generate_params(instance_name, training_set_size)
    scenario = generate_scenario(instance_name, timeout)

    params_file = "../utils/paramils/hcbr_tuning/hcbr/{}-params.txt".format(instance_name)
    scenario_file = "../utils/paramils/hcbr_tuning/hcbr/{}_scenario.txt".format(instance_name)
    try:
        os.remove(params_file)
    except:
        pass

    try:
        os.remove(scenario_file)
    except:
        pass

    with open(params_file, 'a') as file:
        file.write(params)

    with open(scenario_file, 'a') as file:
        file.write(scenario)

if __name__ == '__main__':
    instance_name = sys.argv[1]
    timeout = sys.argv[2]
    training_set_size = sys.argv[3]
    main(instance_name, timeout, training_set_size)