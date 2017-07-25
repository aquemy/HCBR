import sys
import os
from collections import OrderedDict
"""
Expected format for the input file:
#Id #Real value #Guessed value [...]
0 1 0 0.000000 0.000000 0.000000 0.000000 1.000000 1.000000 0.000042 0.000042
"""

ID_ROW=0
REAL_ROW=1
GUESS_ROW=2

def main(path):
    file_name = path.split('/')[-1].split('.')[0]

    with open(path) as f:
        data = f.readlines()

    var = ['T', 'P', 'N', 'PREV', 'TP', 'TN', 'FP', 'FN', 'TPR', 'TNR', 'PPV', 'NPV', 'FNR', 'FPR', 'FDR', 'FOR', 'ACC', 'F1', 'MCC', 'DOR', 'LRp', 'LRm']
    r = OrderedDict(zip(var, [0.]*len(var)))
    N = len(data)
    output_file = '{}_confusion_matrix.txt'.format(file_name)
    try:
        os.remove(output_file)
    except:
        pass

    for line in data:
        e = map(float, line.split())
        r['T'] += 1
        if e[REAL_ROW] == 0:
            r['N'] += 1
            if e[GUESS_ROW] == 0:
                r['TN'] += 1
            else:
                r['FP'] += 1
        else:
            r['P'] += 1
            if e[GUESS_ROW] == 0:
                r['FN'] += 1
            else:
                r['TP'] += 1

        r['PREV'] = r['P'] / r['T']
        r['ACC'] = (r['TP'] + r['TN']) / r['T']
        r['TPR'] = r['TP'] / r['P'] if r['P'] > 0 else 0
        r['TNR'] = r['TN'] / r['N'] if r['N'] > 0 else 0
        r['PPV'] = r['TP'] / (r['TP'] + r['FP']) if (r['TP'] + r['FP']) > 0 else 0
        r['NPV'] = r['TN'] / (r['TN'] + r['FN']) if (r['TN'] + r['FN']) > 0 else 0
        r['FNR'] = 1 - r['TPR']
        r['FPR'] = 1 - r['TNR']
        r['FDR'] = 1 - r['PPV']
        r['FOR'] = 1 - r['NPV']
        r['F1'] = (2*r['TP']) / (2*r['TP'] + r['FP'] + r['FN']) if (2*r['TP'] + r['FP'] + r['FN']) else 0
        r['MCC'] = ((r['TP'] * r['TN']) - (r['FP'] * r['FN'])) / ((r['TP'] + r['FP']) * (r['TP'] + r['FN']) * (r['TN'] + r['FP']) * (r['TN'] + r['FN']))**(0.5) if (r['TP'] + r['FP']) * (r['TP'] + r['FN']) * (r['TN'] + r['FP']) * (r['TN'] + r['FN']) > 0 else 0
        r['LRp'] = r['TPR'] / r['FPR'] if r['FPR'] > 0 else 0
        r['LRm'] = r['FNR'] / r['TNR'] if r['TNR'] > 0 else 0
        r['DOR'] = r['LRp'] / r['LRm'] if r['LRm'] > 0 else 0


        with open(output_file, 'a') as f:
            f.write(' '.join(map(str, r.values())) + '\n')

        generate_gnuplot(output_file)

def generate_gnuplot(path):

    gp_headers = "reset\n\
        \n\
        set style line 1 lc rgb '#8b1a0e' pt 1 ps 0.1 lt 1 lw 2 # --- red\n\
        set style line 2 lc rgb '#5e9c36' pt 8 ps 0.1 lt 1 lw 2 # --- green\n\
        set style line 3 lc rgb '#4488bb' pt 5 ps 0.1 lt 1 lw 2 # --- blue\n\
        \n\
        set style line 11 lc rgb '#808080' lt 1\n\
        set border 3 back ls 11\n\
        set tics nomirror\n\
        set style line 12 lc rgb '#808080' lt 0 lw 1\n\
        set grid back ls 12\n"

    def gp_terminals(t_type, name):
        if t_type == 'png':
            return "set terminal pngcairo size 820,500 enhanced font 'Verdana,9'\n\
        set output '{}.png'\n".format(name)
        elif t_type == 'svg':
            return "set terminal svg size 820,500 fname 'Verdana, Helvetica, Arial, sans-serif'\n\
        set output '{}.svg'\n".format(name)
    

    terminals_types = ['png', 'svg']

    plots = ["plot '{0}' u 0:1 w l ls 3 t 'Total', \
            '{0}' u 0:2 w l ls 2 t 'Positive', \
            '{0}' u 0:5 w l ls 2 dashtype 2 t 'True Positive', \
            '{0}' u 0:7 w l ls 2 dashtype 3 t 'False Positive', \
            '{0}' u 0:3 w l ls 1 t 'Negative', \
            '{0}' u 0:6 w l ls 1 dashtype 2 t 'True Negative', \
            '{0}' u 0:8 w l ls 1 dashtype 3 t 'False Negative'\n".format(path),

            "plot '{0}' u 0:17 w l ls 3 t 'Accuracy', \
            '{0}' u 0:4 w l ls 3 dashtype 2 t 'Prevalence', \
            '{0}' u 0:9 w l ls 2 t 'True Positive Rate', \
            '{0}' u 0:10 w l ls 1 t 'True Negative Rate', \
            '{0}' u 0:11 w l ls 2 lw 1 dashtype 2 t 'Positive Prediction Value', \
            '{0}' u 0:12 w l ls 1 lw 1 dashtype 2 t 'Negative Prediction Value'\n".format(path),

            "plot '{0}' u 0:17 w l ls 3 t 'Accuracy', \
            '{0}' u 0:18 w l ls 1 t 'F1 Score', \
            '{0}' u 0:19 w l ls 2 t 'Matthews correlation coefficient'\n".format(path)
        ]

    keys_and_ranges = ["set key top left\n",

            "set key bottom right\n\
            set yrange [0.2:1]\n",

            "set key bottom right\n\
            set yrange [0.2:1]\n"
        ]

    base_name = path.split('.')[0]
    output_file = "{}.gp".format(base_name)
    try:
        os.remove(output_file)
    except:
        pass
    with open(output_file, 'w') as f:
        f.write("#!/usr/bin/gnuplot5 \n\n")
        for i, plot in enumerate(plots):
            for o in terminals_types:
                f.write(gp_headers + '\n')
                f.write(gp_terminals(o, "{}_{}".format(base_name, i)) + '\n')
                f.write(keys_and_ranges[i] + '\n')
                f.write(plot + '\n')

        
if __name__ == '__main__':
    path = sys.argv[1]
    main(path)
