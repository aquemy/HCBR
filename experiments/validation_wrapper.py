import json
import os, errno
import sys
import time
import shutil
import subprocess
from subprocess import Popen, PIPE

EXECUTABLE = 'hcbr_learning'
BUILD_FOLDER = '../build'
DATA_FOLDER = '../data'
KFOLD_SCRIPT = 'kfold_validation.py'
ACCURACY_ROW = 4

#METAOPTIMIZATION = '../tuning/hyperopt_wrapper.py'
#METAOPTIMIZATION_TIMEOUT = 60

METAOPTIMIZATION = '../script/genetic_algorithm.py'

def convert_paramILS_to_HCBR_params(paramILS):
    convert_map = {
        'e': 'eta',
        'd': 'delta',
        'g': 'gamma',
        'i': 'online',
        'p': 'learning_phases',
        'z': 'heuristic'
    }
    def if_exists(k, v):
        if k in convert_map:
            return convert_map[k], v
        else:
            return None, None
    params = {}
    for k, v in paramILS.iteritems():
        key, val = if_exists(k, v)
        if key is not None:
            params[key] = val
    return params



def read_outcomes(path):
    cases = []
    headers = []
    with open(path, 'rb') as csvfile:
        reader = csvfile.readlines()
        n = len(reader[0].split())
        for i, row in enumerate(reader):
            cases.append(int(row))
    return cases

def main():
    executable_path = os.path.join(BUILD_FOLDER, EXECUTABLE)

    k = int(sys.argv[1])
    l = float(sys.argv[2])
    instance_name = sys.argv[3]
    seed = None
    if len(sys.argv) > 4:
        seed = sys.argv[4]
    only_analysis = False
    if len(sys.argv) > 5:
        only_analysis = True if sys.argv[5] == 'True' else False
    if len(sys.argv) > 6:
        nested_CV = True if sys.argv[6] == 'True' else False
    suffix = ""
    if len(sys.argv) > 7:
        suffix = "_" + sys.argv[7]

    path = instance_name
    file_name = path.split('/')[-1].split('.')[0]
    base_name = file_name.split('.')[0]
    
    # Check build, executable and paths
    base_output_path = "{}{}".format(instance_name, suffix)

    if not only_analysis:
        try:
            shutil.rmtree(base_output_path)
        except:
            pass
        try:
            os.makedirs(base_output_path)
        except OSError as e:
            if e.errno != errno.EEXIST:
                raise


        # Create the casebase
        print('# Create casebase and outcome files...')
        process_script = os.path.join(DATA_FOLDER, "process_{}.py".format(instance_name))
        data_location = os.path.join(DATA_FOLDER, "{}.txt".format(instance_name))
        cmd = "python {} {}".format(process_script, data_location)
        rc = subprocess.call(cmd, shell=True)
        print('CMD: {}'.format(cmd))
        print('RC: {}'.format(rc))
        if rc:
            exit(1)
        path_casebase = os.path.join("{}_casebase.txt".format(instance_name))
        path_outcomes = os.path.join("{}_outcomes.txt".format(instance_name))
        try:
            outcomes = read_outcomes(path_outcomes)
        except Exception as e:
            print(e)
            exit(1)

        n = len(outcomes)

        # Create the k-folds
        print('# Create k-folds files for validation...')
        fold_creation_output = os.path.join(base_output_path, 'kfold_creation.log')
        cmd_fold_validation = "python {} {} {} {} {} {} > {}".format(
            KFOLD_SCRIPT,
            k,
            path_casebase,
            path_outcomes,
            os.path.join(base_output_path, "input_data"),
            seed if seed is not None else "",
            fold_creation_output
            )
        print('CMD: {}'.format(cmd_fold_validation))
        rc = subprocess.call(cmd_fold_validation, shell=True)
        print('RC: {}'.format(rc))
        if rc:
            exit(1)

        # Read configuration
        print('# Read configuration for this instance...')
        examples = int(round(n * l))
        parameters_path = os.path.join(DATA_FOLDER, "parameters", "{}.params.json".format(instance_name))
        default_params = {
                # TODO
            }
        parameters = None
        try:
            with open(parameters_path) as json_data:
                parameters = json.load(json_data)
        except Exception as e:
            print('[ERROR] Could not retrieve parameters. Use default parameters.')
            print(e)
        if parameters is None:
            parameters = default_params
        else:
            for key, v in default_params.iteritems():
                if key not in parameters:
                    print('# - Add {}={} as parameter because value not found'.format(key, v))
                    parameters[key] = v
        print('# Configuration: {}'.format(parameters))
        # Start validation runs
        print('# Start validation runs...')
        average_accuracy = 0
    for i in range(0, k):
        print('\n#########################')
        print('# - Run {}'.format(i))
        print('#########################')
        run_nb = 'run_{}'.format(i)
        fold_casebase = os.path.join("../experiments", base_output_path, "input_data", "{}_casebase.fold_{}.txt".format(instance_name, i))
        fold_outcomes =  os.path.join("../experiments", base_output_path, "input_data", "{}_outcomes.fold_{}.txt".format(instance_name, i))
        fold_output_path = os.path.join("../experiments", base_output_path, run_nb)

        parameters_path = os.path.join(DATA_FOLDER, "parameters", "{}.params.json".format(instance_name))
        default_params = {
                # TODO
            }
        parameters = None
        try:
            with open(parameters_path) as json_data:
                parameters = json.load(json_data)
        except Exception as e:
            print('[ERROR] Could not retrieve parameters. Use default parameters.')
            print(e)

        parameters["input"]["casebase"] = fold_casebase
        parameters["input"]["outcomes"] = fold_outcomes
        parameters["parameters"]["limit"] = examples
        parameters["parameters"]["run_id"] = i

        if not only_analysis:
            try:
                shutil.rmtree(fold_output_path)
            except:
                pass
            try:
                os.makedirs(fold_output_path)
            except OSError as e:
                if e.errno != errno.EEXIST:
                    print('[ERROR] Could not create output path for {}'.format(run_nb))
                    continue
            if(nested_CV):
                print('# Start Meta-optimization for Model Selection')
                print('# Preliminary run')
                fold_param_file = os.path.join(fold_output_path, 'params_{}.init.json'.format(run_nb))

                with open(fold_param_file, 'w') as f:
                    f.write(json.dumps(parameters, indent=4))
                print('# Initial configuration: {}'.format(parameters))
                cmd = "{} --params {} > {} 2> {}".format(executable_path,
                        fold_param_file,
                        os.path.join(fold_output_path, 'output_{}.init.txt'.format(run_nb)),
                        os.path.join(fold_output_path, 'log_{}.init.txt'.format(run_nb))
                        )
                '''
                cmd = "{} -c {} -o {} -l {} -s -p {} -e {} -d {} -g {} {} {} -b {} > {} 2> {}".format(
                        executable_path,
                        fold_casebase,
                        fold_outcomes,
                        examples,
                        parameters['learning_phases'],
                        parameters['eta'],
                        parameters['delta'],
                        parameters['gamma'],
                        '-i' if int(parameters['online']) == 1 else "",
                        '-z' if int(parameters['heuristic']) == 1 else "",
                        i,
                        os.path.join(fold_output_path, 'output_{}.txt'.format(run_nb)),
                        os.path.join(fold_output_path, 'log_{}.txt'.format(run_nb))
                    )
                '''
                print('#   CMD: {}'.format(cmd))
                rc = subprocess.call(cmd, shell=True)
                p = Popen(['tail', '-n', '1', os.path.join(fold_output_path, 'output_{}.init.txt'.format(run_nb))], stdin=PIPE, stdout=PIPE, stderr=PIPE)
                output, err = p.communicate()
                prun_accuracy = float(output.split()[ACCURACY_ROW])
                print('# Preliminary run accuracy: {}'.format(prun_accuracy))
                cmd = "python {} \
                    --weights ../experiments/W.txt \
                    --mu0 ../experiments/Mu_0_post_training.txt \
                    --mu1 ../experiments/Mu_1_post_training.txt \
                    --outcomes {}".format(METAOPTIMIZATION, fold_outcomes)
                print('# CMD: {}'.format(cmd))
                p = Popen(cmd.split(), stdin=PIPE, stdout=PIPE, stderr=PIPE)
                output, err = p.communicate()

                parameters_path = os.path.join(DATA_FOLDER, "parameters", "{}.optimized.params.json".format(instance_name))
                parameters = json.load(open(parameters_path))

                parameters["deserialization"]["mu0_file"] = "../experiments/Mu_0_optimized.txt"
                parameters["deserialization"]["mu1_file"] = "../experiments/Mu_1_optimized.txt"

            parameters["input"]["casebase"] = fold_casebase
            parameters["input"]["outcomes"] = fold_outcomes

            parameters["parameters"]["limit"] = examples
            parameters["parameters"]["run_id"] = i

            fold_param_file = os.path.join(fold_output_path, 'params_{}.json'.format(run_nb))

            with open(fold_param_file, 'w') as f:
                f.write(json.dumps(parameters, indent=4))
            print('# Final configuration: {}'.format(parameters))
            cmd = "{} --params {} > {} 2> {}".format(executable_path, 
                    fold_param_file, 
                    os.path.join(fold_output_path, 'output_{}.txt'.format(run_nb)),
                    os.path.join(fold_output_path, 'log_{}.txt'.format(run_nb))
                    )

            print('#   CMD: {}'.format(cmd))
            rc = subprocess.call(cmd, shell=True)
            try:
                shutil.move("training.run_{}.log.csv".format(i), os.path.join(base_output_path, "run_{}".format(i), "training.run_{}.log.csv".format(i)))
                shutil.move("prediction.run_{}.log.csv".format(i), os.path.join(base_output_path, "run_{}".format(i), "prediction.run_{}.log.csv".format(i)))
                shutil.move("overlap.run_{}.log.csv".format(i), os.path.join(base_output_path, "run_{}".format(i), "overlap.run_{}.log.csv".format(i)))
                shutil.move("strength.run_{}.log.csv".format(i), os.path.join(base_output_path, "run_{}".format(i), "strength.run_{}.log.csv".format(i)))
            except Exception as e:
                pass
            p = Popen(['tail', '-n', '1', os.path.join(fold_output_path, 'output_{}.txt'.format(run_nb))], stdin=PIPE, stdout=PIPE, stderr=PIPE)
            output, err = p.communicate()
            run_accuracy = float(output.split()[ACCURACY_ROW])
            average_accuracy += run_accuracy
            print("#    Accuracy: {}".format(run_accuracy))
        print('# Analyze the results...')
        try:
            # Confusion matrix
            cmd_confusion_matrix = "python ../utils/confusion_matrix.py {}".format(os.path.join(fold_output_path, 'output_{}.txt'.format(run_nb)))
            cmd_cm_gp = "gnuplot {}".format('output_{}_confusion_matrix.gp'.format(run_nb))
            rc = subprocess.call(cmd_confusion_matrix, shell=True)
            rc = subprocess.call(cmd_cm_gp, shell=True)
            
            shutil.move('output_{}_confusion_matrix.gp'.format(run_nb), os.path.join(base_output_path, "run_{}".format(i), 'output_{}_confusion_matrix.gp'.format(run_nb)))
            shutil.move('output_{}_confusion_matrix.txt'.format(run_nb), os.path.join(base_output_path, "run_{}".format(i), 'output_{}_confusion_matrix.txt'.format(run_nb)))
            shutil.move('output_{}_confusion_matrix_0.png'.format(run_nb), os.path.join(base_output_path, "run_{}".format(i), 'output_{}_confusion_matrix_0.png'.format(run_nb)))
            shutil.move('output_{}_confusion_matrix_1.png'.format(run_nb), os.path.join(base_output_path, "run_{}".format(i), 'output_{}_confusion_matrix_1.png'.format(run_nb)))
            shutil.move('output_{}_confusion_matrix_2.png'.format(run_nb), os.path.join(base_output_path, "run_{}".format(i), 'output_{}_confusion_matrix_2.png'.format(run_nb)))
            shutil.move('output_{}_confusion_matrix_0.svg'.format(run_nb), os.path.join(base_output_path, "run_{}".format(i), 'output_{}_confusion_matrix_0.svg'.format(run_nb)))
            shutil.move('output_{}_confusion_matrix_1.svg'.format(run_nb), os.path.join(base_output_path, "run_{}".format(i), 'output_{}_confusion_matrix_1.svg'.format(run_nb)))
            shutil.move('output_{}_confusion_matrix_2.svg'.format(run_nb), os.path.join(base_output_path, "run_{}".format(i), 'output_{}_confusion_matrix_2.svg'.format(run_nb)))
            
            # Prediction analysis
            cmd_prediction_analysis ="python ../utils/prediction_analysis.py {path} ".format(
                path=os.path.join(fold_output_path, 'output_{}.txt'.format(run_nb))
            )
            cmd_pa_gp = "gnuplot {}".format('output_{}_diff_pred.gp'.format(run_nb))
            rc = subprocess.call(cmd_prediction_analysis, shell=True)
            rc = subprocess.call(cmd_pa_gp, shell=True)
            
            shutil.move('output_{}_diff_bad_pred.txt'.format(run_nb), os.path.join(base_output_path, "run_{}".format(i), 'output_{}_diff_bad_pred.txt'.format(run_nb)))
            shutil.move('output_{}_diff_negative_bad_pred.txt'.format(run_nb), os.path.join(base_output_path, "run_{}".format(i), 'output_{}_diff_negative_bad_pred.txt'.format(run_nb)))
            shutil.move('output_{}_diff_negative_pred.txt'.format(run_nb), os.path.join(base_output_path, "run_{}".format(i), 'output_{}_diff_negative_pred.txt'.format(run_nb)))
            shutil.move('output_{}_diff_positive_bad_pred.txt'.format(run_nb), os.path.join(base_output_path, "run_{}".format(i), 'output_{}_diff_positive_bad_pred.txt'.format(run_nb)))
            shutil.move('output_{}_diff_pred.txt'.format(run_nb), os.path.join(base_output_path, "run_{}".format(i), 'output_{}_diff_pred.txt'.format(run_nb)))
            shutil.move('output_{}_positive_diff_pred.txt'.format(run_nb), os.path.join(base_output_path, "run_{}".format(i), 'output_{}_positive_diff_pred.txt'.format(run_nb)))
            shutil.move('output_{}_diff_pred.gp'.format(run_nb), os.path.join(base_output_path, "run_{}".format(i), 'output_{}_diff_pred.gp'.format(run_nb)))
            
            shutil.move('output_{}_diff_pred_0.png'.format(run_nb), os.path.join(base_output_path, "run_{}".format(i), 'output_{}_diff_pred_0.png'.format(run_nb)))
            shutil.move('output_{}_diff_pred_1.png'.format(run_nb), os.path.join(base_output_path, "run_{}".format(i), 'output_{}_diff_pred_0.png'.format(run_nb)))
            shutil.move('output_{}_diff_pred_0.svg'.format(run_nb), os.path.join(base_output_path, "run_{}".format(i), 'output_{}_diff_pred_0.svg'.format(run_nb)))
            shutil.move('output_{}_diff_pred_1.svg'.format(run_nb), os.path.join(base_output_path, "run_{}".format(i), 'output_{}_diff_pred_0.svg'.format(run_nb)))
            

            # ROC
            cmd_roc ="python ../utils/roc.py {path} ".format(
                path=os.path.join(fold_output_path, 'output_{}.txt'.format(run_nb))
            )
            print('CMD: {}'.format(cmd_roc))
            rc = subprocess.call(cmd_roc, shell=True)
            shutil.move('roc.png', os.path.join(base_output_path, "run_{}".format(i), 'roc.png'))
            
            # Time
            cmd_time ="python ../utils/time_analysis.py {path} ".format(
                path=os.path.join(os.path.join(fold_output_path, 'output_{}.txt'.format(run_nb)))
            )
            cmd_time_gp = "gnuplot {}".format(os.path.join(base_output_path, "run_{}".format(i), 'output_{}_time.gp'.format(run_nb)).format(run_nb))
            #rc = subprocess.call(cmd_time, shell=True)
            #rc = subprocess.call(cmd_time_gp, shell=True)
        except Exception as e:
            print(e)

    print('# Analyze all runs...')
    try:
        cmd_analyze_runs ="python ../utils/analyze_runs.py {path} {instance} {k} {instance} 'table:{instance}' '{caption}'".format(
            instance=instance_name, 
            path="hcbr.global.log.csv" if not only_analysis else os.path.join(base_output_path, "hcbr.global.log.csv"), 
            k=k, 
            caption="Confusion matrix and performances indicators for the \\texttt{" + instance_name +"} dataset."
        )
        rc = subprocess.call(cmd_analyze_runs, shell=True)
        print('CMD: {}'.format(cmd_analyze_runs))

        cmd_confusion_matrix = "python ../utils/confusion_matrix.py {}".format(os.path.join(base_output_path, 'output.average.txt'))
        cmd_cm_gp = "gnuplot {}".format('output_confusion_matrix.gp')
        rc = subprocess.call(cmd_confusion_matrix, shell=True)
        rc = subprocess.call(cmd_cm_gp, shell=True)
            
        shutil.move('output_confusion_matrix.gp', os.path.join(base_output_path, 'output_confusion_matrix.gp'))
        shutil.move('output_confusion_matrix.txt', os.path.join(base_output_path, 'output_confusion_matrix.txt'))
        shutil.move('output_confusion_matrix_0.png', os.path.join(base_output_path, 'output_confusion_matrix_0.png'))
        shutil.move('output_confusion_matrix_1.png', os.path.join(base_output_path, 'output_confusion_matrix_1.png'))
        shutil.move('output_confusion_matrix_2.png', os.path.join(base_output_path, 'output_confusion_matrix_2.png'))
        shutil.move('output_confusion_matrix_0.svg', os.path.join(base_output_path, 'output_confusion_matrix_0.svg'))
        shutil.move('output_confusion_matrix_1.svg', os.path.join(base_output_path, 'output_confusion_matrix_1.svg'))
        shutil.move('output_confusion_matrix_2.svg', os.path.join(base_output_path, 'output_confusion_matrix_2.svg'))

        # Prediction analysis
        cmd_prediction_analysis ="python ../utils/prediction_analysis.py {path} ".format(
            path=os.path.join(base_output_path, 'output.average.txt')
        )
        cmd_pa_gp = "gnuplot {}".format('output.average_diff_pred.gp')
        rc = subprocess.call(cmd_prediction_analysis, shell=True)
        rc = subprocess.call(cmd_pa_gp, shell=True)
        
        shutil.move('output.average_diff_bad_pred.txt', os.path.join(base_output_path, 'output.average_diff_bad_pred.txt'))
        shutil.move('output.average_diff_negative_bad_pred.txt', os.path.join(base_output_path, 'output.average_diff_negative_bad_pred.txt'))
        shutil.move('output.average_diff_negative_pred.txt', os.path.join(base_output_path, 'output.average_diff_negative_pred.txt'))
        shutil.move('output.average_diff_positive_bad_pred.txt', os.path.join(base_output_path,  'output.average_diff_positive_bad_pred.txt'))
        shutil.move('output.average_diff_pred.txt', os.path.join(base_output_path, 'output.average_diff_pred.txt'))
        shutil.move('output.average_positive_diff_pred.txt', os.path.join(base_output_path, 'output.average_positive_diff_pred.txt'))
        shutil.move('output.average_diff_pred.gp', os.path.join(base_output_path, 'output.average_diff_pred.gp'))
            
        shutil.move('output.average_diff_pred_0.png', os.path.join(base_output_path, 'output.average_diff_pred_0.png'))
        shutil.move('output.average_diff_pred_1.png', os.path.join(base_output_path, 'output.average_diff_pred_1.png'))
        shutil.move('output.average_diff_pred_0.svg', os.path.join(base_output_path, 'output.average_diff_pred_0.svg'))
        shutil.move('output.average_diff_pred_1.svg', os.path.join(base_output_path, 'output.average_diff_pred_1.svg'))
            
        # ROC
        cmd_roc ="python ../utils/roc.py {path} ".format(
            path=os.path.join(base_output_path, 'output.average.txt')
        )
        print('CMD: {}'.format(cmd_roc))
        rc = subprocess.call(cmd_roc, shell=True)
        shutil.move('roc.png', os.path.join(base_output_path, 'roc.png'))
            
        # Time
        cmd_time ="python ../utils/time_analysis.py {path} {column}".format(
            path=os.path.join(base_output_path, 'output.average.txt'),
            column=10
        )
        cmd_time_gp = "gnuplot {}".format(os.path.join(base_output_path, 'output.average_time.gp'))
        rc = subprocess.call(cmd_time, shell=True)
        rc = subprocess.call(cmd_time_gp, shell=True)

        cmd_time ="python ../utils/time_analysis.py {path} {column}".format(
            path=os.path.join(base_output_path, 'overlap.average.log.csv'),
            column=3
        )
        cmd_time_gp = "gnuplot {}".format(os.path.join(base_output_path, 'overlap.average.log_time.gp'))
        rc = subprocess.call(cmd_time, shell=True)
        rc = subprocess.call(cmd_time_gp, shell=True)

        cmd_time ="python ../utils/time_analysis.py {path} {column}".format(
            path=os.path.join(base_output_path, 'strength.average.log.csv'),
            column=5
        )
        cmd_time_gp = "gnuplot {}".format(os.path.join(base_output_path, 'strength.average.log_time.gp'))
        rc = subprocess.call(cmd_time, shell=True)
        rc = subprocess.call(cmd_time_gp, shell=True)

        cmd_time ="python ../utils/time_analysis.py {path} {column}".format(
            path=os.path.join(base_output_path, 'training.average.log.csv'),
            column=1
        )
        cmd_time_gp = "gnuplot {}".format(os.path.join(base_output_path, 'training.average.log_time.gp'))
        #rc = subprocess.call(cmd_time, shell=True)
        #rc = subprocess.call(cmd_time_gp, shell=True)

    except Exception as e:
        print(e)

    if not only_analysis:
        print('# Copy the results...')
        shutil.move("hcbr.global.log.csv", os.path.join(base_output_path, "hcbr.global.log.csv"))
        shutil.move("{}_casebase.txt".format(instance_name), os.path.join(base_output_path, "{}_casebase.txt".format(instance_name)))
        shutil.move("{}_outcomes.txt".format(instance_name), os.path.join(base_output_path, "{}_outcomes.txt".format(instance_name)))

        msg = "{} {} {}\n".format(instance_name, seed, average_accuracy / float(k))
        sys.stderr.write(msg)
        print(msg)
       
if __name__ == '__main__':
    main()