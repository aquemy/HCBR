import sys
import os
import re
from collections import OrderedDict
import confusion_matrix

def main():
    path = sys.argv[1]
    files = os.listdir(path)
    files = [os.path.join(path,f) for f in files if f.endswith('.txt')]

    res = []
    for file in files:
        confusion_matrix.main(file)
        file_name = file.split('/')[-1].split('.')[0]
        input_file = '{}_confusion_matrix.txt'.format(file_name)
        with open(input_file) as f:
            first = 0
            starting = 0
            m = re.search('starting_(\d+)', input_file)
            if m is not None:
                starting = int(m.group(1))
            m = re.search('first_(\d+)', input_file)
            if m is not None:
                first = int(m.group(1))
            data = f.readlines()[-1]
            res.append((first, starting, data))

    res = sorted(res, key=lambda x: x[0], reverse=False)
    output_file = 'aggregated_confusion_matrix.txt'
    try:
        os.remove(output_file)
    except:
        pass
    with open(output_file, 'a') as f:
        for l in res:
            f.write('{} {} {}'.format(l[0], l[1], l[2]))
    generate_gnuplot(output_file)

def generate_gnuplot(path):

    gp_headers = "reset\n\
        \n\
        set style line 1 lc rgb '#8b1a0e' pt 1 ps 1 lt 1 lw 2 # --- red\n\
        set style line 2 lc rgb '#5e9c36' pt 8 ps 1 lt 1 lw 2 # --- green\n\
        set style line 3 lc rgb '#4488bb' pt 5 ps 1 lt 1 lw 2 # --- blue\n\
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

    plots = [
            "plot '{0}' u 1:19 w lp ls 3 pt 3 t 'Accuracy', \
            '{0}' u 1:11 w lp ls 2 pt 5 t 'True Positive Rate', \
            '{0}' u 1:12 w lp ls 1 pt 7 t 'True Negative Rate', \
            '{0}' u 1:13 w lp ls 2 pt 4 lw 1 dashtype 2 t 'Positive Prediction Value', \
            '{0}' u 1:14 w lp ls 1 pt 6 lw 1 dashtype 2 t 'Negative Prediction Value'\n".format(path),
        ]

    keys_and_ranges = ["set key bottom right\n",
            "set key bottom right\n\
            set yrange [0.2:1]\n",
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
    main()
