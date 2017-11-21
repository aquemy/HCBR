import json
import os, errno
import sys
import time
import shutil
import subprocess
from subprocess import Popen, PIPE

def parse_and_format_final_params(content):
    content = content.replace("Final best parameter configuration:", "")
    content = content.split(',')
    content = map(str.strip, content)
    content = [p.split('=') for p in content]

    params = {}
    for k, v in content:
        params[k] = v
    return params

def main():
    casebase_name = sys.argv[1]
    outcomes_name = sys.argv[2]
    timeout = sys.argv[3]
    training_set_size = sys.argv[4]

    instance_name = casebase_name.split('/')[-1].split('.txt')[0]

    # Generate scenario
    cmd = "python ../utils/paramils/generate_params.py {} {} {}".format(instance_name, timeout, training_set_size)
    rc = subprocess.call(cmd, shell=True)

    # Call paramILS
    cmd = "ruby ../utils/paramils/param_ils_2_3_run.rb -N 1 -numRun 0 -maxIts 1 -scenariofile ../utils/paramils/hcbr_tuning/hcbr/{}_scenario.txt -validN 0 -userunlog 1 -deterministic 1 > paramILS.run.txt 2> /dev/null".format(instance_name)
    rc = subprocess.call(cmd, shell=True)

    output_file = "../utils/paramils/hcbr_tuning/results/hcbr/paramils/focused-runs1-runobjqual-overallobjmean-maxit1-time1000000000.0-tunerTime{}.0-algoAlgo-result_0.txt".format(timeout)

    content = ""
    with open(output_file, 'r') as file:
        content = file.readlines()[0]
    final_params = parse_and_format_final_params(content)
    print(json.dumps(final_params))

if __name__ == '__main__':
    main()