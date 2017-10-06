import sys
import os

W1_ROW = 8# 5
W0_ROW = 9# 6

def main():
    path = sys.argv[1]
    file_name = '.'.join(path.split('/')[-1].split('.')[:-1])
    print(file_name)

    generate_gnuplot(path)

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
        set grid back ls 12\n\
        set grid x y2\n"

    def gp_terminals(t_type, name):
        if t_type == 'png':
            return "set terminal pngcairo size 820,500 enhanced font 'Verdana,9'\n\
        set output '{}.png'\n".format(name)
        elif t_type == 'svg':
            return "set terminal svg size 820,500 fname 'Verdana, Helvetica, Arial, sans-serif'\n\
        set output '{}.svg'\n".format(name)
    

    terminals_types = ['png', 'svg']

    time_input = path #'{}.txt'.format(path)
    plots = ["plot '{p}' u 0:10 ls 2 pt 7 ps 0.3 axes x1y1 t 'Time per iteration',\
        '{p}' u 0:11 ls 3 w l axes x2y2 t 'Total time'".format(p=path),
        "plot '{p}' u 0:10 ls 2 pt 7 ps 0.1 w i t 'Time per iteration'".format(p=path)
        ]

    keys_and_ranges = ["set key top left\n\
            set ytics nomirror\n\
            set y2tics\n\
            set tics out\n\
            set autoscale  y\n\
            set autoscale y2\n",
            "set key top left"
        ] 

    base_name = '.'.join(path.split('.')[:-1])
    output_file = "{}_time.gp".format(base_name)
    try:
        os.remove(output_file)
    except:
        pass
    with open(output_file, 'w') as f:
        f.write("#!/usr/bin/gnuplot5 \n\n")
        for i, plot in enumerate(plots):
            #f.write("f(x) = a*x\n")
            #f.write("fit f(x) '{}' u 0:13  via a\n".format(time_input))
            #f.write('ti = sprintf("%.3ex", a)\n')
            for o in terminals_types:
                f.write(gp_terminals(o, "{}_time_{}".format(base_name, i)) + '\n')
                f.write(gp_headers + '\n')
                f.write(keys_and_ranges[i] + '\n')
                f.write(plot + '\n')

if __name__ == '__main__':
    main()
