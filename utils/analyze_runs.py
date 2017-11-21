import sys
import os
import re
import re
import csv
import json
from collections import OrderedDict
import confusion_matrix

def read_csv(path):
    cases = []
    headers = []
    with open(path, 'rb') as csvfile:
        reader = csv.reader(csvfile, delimiter=',', quotechar='"')
        for i, row in enumerate(reader):
            if i == 0:
                continue
            cases.append(row)
        with open(path, 'rb') as file:
            headers = map(str.strip, file.readlines()[0].split(','))
    return headers, cases

def read_raw(path):
    cases = []
    headers = []
    with open(path, 'rb') as file:
        data = file.readlines()
        for i, row in enumerate(data):
            cases.append(map(float, row.split()))
    return cases

def average(data, index):
    n = len(data)
    s = 0
    for e in data:
        try:
            s += float(e[index])
        except:
            return e[index]
    return float(s) / n

def tex_escape(text):
    """
        :param text: a plain text message
        :return: the message escaped to appear correctly in LaTeX
    """
    conv = {
        #'&': r'\&',
        #'%': r'\%',
        #'$': r'\$',
        #'#': r'\#',
        #'_': r'\_',
        #'{': r'\{',
        #'}': r'\}',
        '~': r'\textasciitilde{}',
        '^': r'\^{}',
        '\\': '\\',#r'\textbackslash{}',
        '\a': r'\a',
        '\b': r'\b',
        '\f': r'\f',
        '\n': r'\n',
        '\r': r'\r',
        '\t': r'\t',
        '\v': r'\v',
        #'<': r'\textless ',
        #'>': r'\textgreater ',
        '\n': '\n',
        '\\\n': '\\\\\n'
    }
    regex = re.compile('|'.join(re.escape(unicode(key)) for key in sorted(conv.keys(), key = lambda item: - len(item))))
    return regex.sub(lambda match: conv[match.group()], text)

def generate_latex(data, caption, label):
    card = str(int(data[38]))
    acc = "{:.4f}".format(data[46])
    tp = "{:.2f}".format(data[47])
    fp = "{:.2f}".format(data[48])
    fn = "{:.2f}".format(data[49])
    tn = "{:.2f}".format(data[50])
    prev = "{:.4f}".format((data[47] + data[49]) / int(data[38]))
    tpr = "{:.4f}".format(data[51])
    tnr = "{:.4f}".format(data[52])
    ppv = "{:.4f}".format(data[53])
    npv = "{:.4f}".format(data[54])
    fnr = "{:.4f}".format(data[55])
    fpr = "{:.4f}".format(data[56])
    fdr = "{:.4f}".format(data[57])
    forr = "{:.4f}".format(data[58])
    f1 = "{:.4f}".format(data[59])
    mcc = "{:.4f}".format(data[60])
    a = "{:.2f}".format(data[47] + data[49])
    b = "{:.2f}".format(data[48] + data[50])
    c = "{:.2f}".format(data[47] + data[48])
    d = "{:.2f}".format(data[49] + data[50])

    res = "\
    \renewcommand\arraystretch{1.5}\n\
    \setlength\tabcolsep{0pt}\n\
    \begin{table}\n\
    \caption{" + caption + "}\n\
    \label{" + label + "}\n\
     \begin{small}\n\
    \begin{tabular}{c >{\bfseries}r @{\hspace{0.7em}}c @{\hspace{0.4em}}c @{\hspace{0.7em}}l}\n\
      \multirow{10}{*}{\rotatebox{90}{\parbox{3.1cm}{\bfseries\centering Predicted class}}} &\n\
        & \multicolumn{2}{c}{\bfseries Real class} & \\\n\
      & & \bfseries P & \bfseries N & \bfseries Total \\\n\
      & \cmlegend{P} & \cmbox{" + tp + "} & \cmbox{" + fp + "} & \cmlegend{" + c + "} \\\n\
      & \cmlegend{N} & \cmbox{" + fn + "} & \cmbox{" + tn + "} & \cmlegend{" + d + "} \\\n\
      & \cmlegend{Total} & \cmlegend{" + a + "} & \cmlegend{" + b + "} & \cmlegend{" + card + "}\n\
    \end{tabular}\n\
    \end{small}\n\
    \hfill\n\
    \begin{small}\n\
    \begin{tabular}{| @{\hspace{0.7em}}l  @{\hspace{0.7em}} l  @{\hspace{0.7em}}|}\n\
        \hline\n\
        Accuracy: &" + acc + "\\\n\
        Prevalence: & " + prev + "\\\n\
        True positive rate: & " + tpr + "\\\n\
        True negative rate: &" + tnr + " \\\n\
        Positive predictive value: & " + ppv + " \\\n\
        Negative predictive value: & " + npv + "\\\n\
        F1 score: & " +f1 + "\\\n\
        Matthews corr. coef.: & " + mcc + "\\\n\
        \hline\n\
      \end{tabular}\n\
    \end{small}\n\
    \end{table}\n\
    "


    save = "\
    \renewcommand\arraystretch{1.5}\n\
    \setlength\tabcolsep{0pt}\n\
    \begin{table}\n\
    \caption{" + caption + "}\n\
    \label{" + label + "}\n\
     \begin{small}\n\
    \begin{tabular}{c >{\bfseries}r @{\hspace{0.7em}}c @{\hspace{0.4em}}c @{\hspace{0.7em}}l}\n\
      \multirow{10}{*}{\rotatebox{90}{\parbox{3.1cm}{\bfseries\centering Predicted class}}} &\n\
        & \multicolumn{2}{c}{\bfseries Real class} & \\\n\
      & & \bfseries P & \bfseries N & \bfseries Total \\\n\
      & \cmlegend{P} & \cmbox{" + tp + "} & \cmbox{" + fp + "} & \cmlegend{" + c + "} \\\n\
      & \cmlegend{N} & \cmbox{" + fn + "} & \cmbox{" + tn + "} & \cmlegend{" + d + "} \\\n\
      & \cmlegend{Total} & \cmlegend{" + a + "} & \cmlegend{" + b + "} & \cmlegend{" + card + "}\n\
    \end{tabular}\n\
    \end{small}\n\
    \hfill\n\
    \begin{small}\n\
    \begin{tabular}{| @{\hspace{0.7em}}l  @{\hspace{0.7em}} l  @{\hspace{0.7em}}|}\n\
        \hline\n\
        Accuracy: &" + acc + "\\\n\
        Prevalence: & " + prev + "\\\n\
        True positive rate: & " + tpr + "\\\n\
        True negative rate: &" + tnr + " \\\n\
        Positive predictive value: & " + ppv + " \\\n\
        Negative predictive value: & " + npv + "\\\n\
        False positive rate: & " + fpr + "\\\n\
        False negative rate: & " + fnr + "\\\n\
        False discovery rate: & " + fdr + "\\\n\
        False omission rate: & " + forr + "\\\n\
        F1 score: & " +f1 + "\\\n\
        Matthews corr. coef.: & " + mcc + "\\\n\
        \hline\n\
      \end{tabular}\n\
    \end{small}\n\
    \end{table}\n\
    "
    return tex_escape(res)

def generate_markdown():
    pass

def main():
    path = sys.argv[1]
    folder = sys.argv[2]
    nb_runs = int(sys.argv[3])
    output = sys.argv[4]
    label = sys.argv[5]
    caption = sys.argv[6]

    '''
    Calculate the average table for prediction
    '''
    
    data_run = []
    headers, average_data = read_csv(os.path.join(folder, "run_{}".format(0), "prediction.run_{}.log.csv".format(0)))
    for k, l in enumerate(average_data):
        #print(l)
        for j, _ in enumerate(l):
            #print(average_data[k][j])
            try:
                average_data[k][j] = float(average_data[k][j])
            except Exception as e:
                pass
                #print("{} {}".format(e, average_data[k][j]))

    for i in range(1, nb_runs):
        _, data_run =read_csv(os.path.join(folder, "run_{}".format(i), "prediction.run_{}.log.csv".format(i)))
        for k, l in enumerate(data_run):
            #print('LINE {}'.format(l))
            for j, v in enumerate(l):
                try:
                    #print(type(v),v, float(v.strip()))
                    average_data[k][j] += float(v.strip())
                except Exception as e:
                    pass
                    #print(e)
    for k, l in enumerate(average_data):
        for j, _ in enumerate(l):
            try:
                average_data[k][j] /= float(nb_runs)
            except Exception as e:
                pass
                #print(e)

    average_output = os.path.join(folder, "prediction.average.log.csv")
    try:
        os.remove(average_output)
    except:
        pass
        
    with open(average_output, 'a') as file:
        file.write(' , '.join(headers) + '\n')
        for k, l in enumerate(average_data):
            file.write(' , '.join(map(str, l)) + '\n')

    '''
    Calculate the average table for training
    '''

    data_run = []
    headers, average_data = read_csv(os.path.join(folder, "run_{}".format(0), "training.run_{}.log.csv".format(0)))
    for k, l in enumerate(average_data):
        #print(l)
        for j, _ in enumerate(l):
            #print(average_data[k][j])
            try:
                average_data[k][j] = float(average_data[k][j])
            except Exception as e:
                pass
                #print("{} {}".format(e, average_data[k][j]))

    for i in range(1, nb_runs):
        _, data_run =read_csv(os.path.join(folder, "run_{}".format(i), "training.run_{}.log.csv".format(i)))
        for k, l in enumerate(data_run):
            #print('LINE {}'.format(l))
            for j, v in enumerate(l):
                try:
                    #print(type(v),v, float(v.strip()))
                    average_data[k][j] += float(v.strip())
                except Exception as e:
                    pass
                    #print(e)
    for k, l in enumerate(average_data):
        for j, _ in enumerate(l):
            try:
                average_data[k][j] /= float(nb_runs)
            except Exception as e:
                pass
                #print(e)

    average_output = os.path.join(folder, "training.average.log.csv")
    try:
        os.remove(average_output)
    except:
        pass
        
    with open(average_output, 'a') as file:
        file.write(' , '.join(headers) + '\n')
        for k, l in enumerate(average_data):
            file.write(' , '.join(map(str, l)) + '\n')


    '''
    Calculate the average table for overlap
    '''

    data_run = []
    headers, average_data = read_csv(os.path.join(folder, "run_{}".format(0), "overlap.run_{}.log.csv".format(0)))
    for k, l in enumerate(average_data):
        #print(l)
        for j, _ in enumerate(l):
            #print(average_data[k][j])
            try:
                average_data[k][j] = float(average_data[k][j])
            except Exception as e:
                pass
                #print("{} {}".format(e, average_data[k][j]))

    for i in range(1, nb_runs):
        _, data_run =read_csv(os.path.join(folder, "run_{}".format(i), "overlap.run_{}.log.csv".format(i)))
        for k, l in enumerate(data_run):
            #print('LINE {}'.format(l))
            for j, v in enumerate(l):
                try:
                    #print(type(v),v, float(v.strip()))
                    average_data[k][j] += float(v.strip())
                except Exception as e:
                    pass
                    #print(e)
    for k, l in enumerate(average_data):
        for j, _ in enumerate(l):
            try:
                average_data[k][j] /= float(nb_runs)
            except Exception as e:
                pass
                #print(e)

    average_output = os.path.join(folder, "overlap.average.log.csv")
    try:
        os.remove(average_output)
    except:
        pass
        
    with open(average_output, 'a') as file:
        file.write(' , '.join(headers) + '\n')
        for k, l in enumerate(average_data):
            file.write(' , '.join(map(str, l)) + '\n')


    '''
    Calculate the average table for strength
    '''

    data_run = []
    headers, average_data = read_csv(os.path.join(folder, "run_{}".format(0), "strength.run_{}.log.csv".format(0)))
    for k, l in enumerate(average_data):
        #print(l)
        for j, _ in enumerate(l):
            #print(average_data[k][j])
            try:
                average_data[k][j] = float(average_data[k][j])
            except Exception as e:
                pass
                #print("{} {}".format(e, average_data[k][j]))

    for i in range(1, nb_runs):
        _, data_run =read_csv(os.path.join(folder, "run_{}".format(i), "strength.run_{}.log.csv".format(i)))
        for k, l in enumerate(data_run):
            #print('LINE {}'.format(l))
            for j, v in enumerate(l):
                try:
                    #print(type(v),v, float(v.strip()))
                    average_data[k][j] += float(v.strip())
                except Exception as e:
                    pass
                    #print(e)
    for k, l in enumerate(average_data):
        for j, _ in enumerate(l):
            try:
                average_data[k][j] /= float(nb_runs)
            except Exception as e:
                pass
                #print(e)

    average_output = os.path.join(folder, "strength.average.log.csv")
    try:
        os.remove(average_output)
    except:
        pass
        
    with open(average_output, 'a') as file:
        file.write(' , '.join(headers) + '\n')
        for k, l in enumerate(average_data):
            file.write(' , '.join(map(str, l)) + '\n')



    '''
    Calculate the average table for the raw standard output
    '''

    data_run = read_raw(os.path.join(folder, "run_{}".format(0), "output_run_{}.txt".format(0)))
    average_data = read_raw(os.path.join(folder, "run_{}".format(0), "output_run_{}.txt".format(0)))
    for i in range(1, nb_runs):
        data_run =read_raw(os.path.join(folder, "run_{}".format(i), "output_run_{}.txt".format(i)))
        for k, l in enumerate(data_run):
            #print('LINE {}'.format(l))
            for j, v in enumerate(l):
                try:
                    #print(average_data[k][j], type(average_data[k][j]), type(v),v, float(v.strip()))
                    average_data[k][j] += float(v)
                except Exception as e:
                    pass
                    #print(e)
    for k, l in enumerate(average_data):
        for j, _ in enumerate(l):
            try:
                average_data[k][j] /= float(nb_runs)
            except Exception as e:
                pass
                #print(e)

    average_output = os.path.join(folder, "output.average.txt")
    try:
        os.remove(average_output)
    except:
        pass
        
    with open(average_output, 'a') as file:
        for k, l in enumerate(average_data):
            file.write(''.join(map(str, l)))



    headers, runs = read_csv(path)
    average_vector = []
    for i in range(0, len(runs[0])):
        average_vector.append(average(runs, i))

    res = dict(zip(headers, average_vector))
    print(json.dumps(res, indent=4, sort_keys=True))
    #print(headers)
    
    latex_output = os.path.join(folder, '{}.tex'.format(output))
    try:
        os.remove(latex_output)
    except:
        pass
        
    with open(latex_output, 'a') as file:
        file.write('{}'.format(generate_latex(average_vector, caption, label)))


if __name__ == '__main__':
    main()
