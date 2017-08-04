import sys
import os
"""
Expected format for the input file:
#Id #Real value #Guessed value #Anything #Weight for class 1 #Weight for class 0
0 1 0 0.000000 0.000000 0.000000 0.000000 1.000000 1.000000 0.000042 0.000042
"""

ID_ROW=0
REAL_ROW=1
GUESS_ROW=2
W1_ROW = 5
W0_ROW = 6

def main():
    path = sys.argv[1]
    file_name = path.split('/')[-1].split('.')[0]
    base_name = file_name.split('.')[0]

    with open(path) as f:
        content = f.readlines()
    content = [x.split() for x in content]

    diff_positive_pred_output = '{}_positive_diff_pred.txt'.format(base_name)
    diff_positive_bad_pred_output = '{}_diff_positive_bad_pred.txt'.format(base_name)
    diff_negative_pred_output = '{}_diff_negative_pred.txt'.format(base_name)
    diff_negative_bad_pred_output = '{}_diff_negative_bad_pred.txt'.format(base_name)
    try:
        os.remove(diff_positive_pred_output)
        os.remove(diff_positive_bad_pred_output)
        os.remove(diff_negative_pred_output)
        os.remove(diff_negative_bad_pred_output)
    except:
        pass

    for i, row in enumerate(content):
        diff = float(row[W1_ROW]) - float(row[W0_ROW])
        res = 1*diff*abs(float(row[REAL_ROW])-float(row[GUESS_ROW]))
        if diff > 0:
            with open(diff_positive_pred_output, 'a') as f:
                f.write('{} {}\n'.format(i, diff))
        if diff < 0:
            with open(diff_negative_pred_output, 'a') as f:
                f.write('{} {}\n'.format(i, diff))
        if res > 0:
            with open(diff_positive_bad_pred_output, 'a') as f:
                f.write('{} {}\n'.format(i, res))
        if res < 0:
            with open(diff_negative_bad_pred_output, 'a') as f:
                f.write('{} {}\n'.format(i, res))

    abs_diff_pred_output = '{}_diff_pred.txt'.format(base_name)
    abs_diff_bad_pred_output = '{}_diff_bad_pred.txt'.format(base_name)
    try:
        os.remove(abs_diff_pred_output)
        os.remove(abs_diff_bad_pred_output)
    except:
        pass
    for i, row in enumerate(content):
        diff = abs(float(row[W1_ROW]) - float(row[W0_ROW]))
        res = abs(1*diff*abs(float(row[REAL_ROW])-float(row[GUESS_ROW])))
        if diff > 0:
            with open(abs_diff_pred_output, 'a') as f:
                f.write('{} {}\n'.format(i, diff))
        if res > 0:
            with open(abs_diff_bad_pred_output, 'a') as f:
                f.write('{} {}\n'.format(i, res))

    generate_gnuplot(base_name)

def generate_gnuplot(path):

    gp_headers = "reset\n\
        \n\
        set style line 1 lc rgb '#8b1a0e' pt 1 ps 0.1 lt 1 lw 1 # --- red\n\
        set style line 2 lc rgb '#5e9c36' pt 8 ps 0.1 lt 1 lw 1 # --- green\n\
        set style line 3 lc rgb '#4488bb' pt 5 ps 0.1 lt 1 lw 1 # --- blue\n\
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

    abs_diff_pred_output = '{}_diff_pred.txt'.format(path)
    abs_diff_bad_pred_output = '{}_diff_bad_pred.txt'.format(path)
    diff_positive_pred_output = '{}_positive_diff_pred.txt'.format(path)
    diff_positive_bad_pred_output = '{}_diff_positive_bad_pred.txt'.format(path)
    diff_negative_pred_output = '{}_diff_negative_pred.txt'.format(path)
    diff_negative_bad_pred_output = '{}_diff_negative_bad_pred.txt'.format(path)

    plots = ["plot '{0}' u 1:2 w i ls 2 t 'Good prediction', \
            '{1}' u 1:2 w i ls 1 t 'Wrong prediction'\n".format(abs_diff_pred_output, abs_diff_bad_pred_output),

            "plot '{0}' u 1:2 w i ls 2 t 'Good prediction',\
            '{1}' u 1:2 w i ls 2 notitle,\
            '{2}' u 1:2 w i ls 1 t 'Wrong prediction',\
            '{3}' u 1:2 w i ls 1 notitle\n".format(diff_positive_pred_output, 
                diff_negative_pred_output, 
                diff_positive_bad_pred_output, 
                diff_negative_bad_pred_output),
        ]

    keys_and_ranges = ["set key top right\n\
            set yrange [0.0:0.15]\n",

            "set key top right\n\
            set yrange [-0.005:0.005]\n"
        ]

    base_name = path
    output_file = "{}_abs_diff_pred.gp".format(base_name)
    try:
        os.remove(output_file)
    except:
        pass
    with open(output_file, 'w') as f:
        f.write("#!/usr/bin/gnuplot5 \n\n")
        for i, plot in enumerate(plots):
            for o in terminals_types:
                f.write(gp_headers + '\n')
                f.write(gp_terminals(o, "{}_diff_pred_{}".format(base_name, i)) + '\n')
                f.write(keys_and_ranges[i] + '\n')
                f.write(plot + '\n')


if __name__ == '__main__':
    main()
