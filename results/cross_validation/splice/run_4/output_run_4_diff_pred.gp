#!/usr/bin/gnuplot5 

reset
        
        set style line 1 lc rgb '#8b1a0e' pt 1 ps 0.1 lt 1 lw 1 # --- red
        set style line 2 lc rgb '#5e9c36' pt 8 ps 0.1 lt 1 lw 1 # --- green
        set style line 3 lc rgb '#4488bb' pt 5 ps 0.1 lt 1 lw 1 # --- blue
        
        set style line 11 lc rgb '#808080' lt 1
        set border 3 back ls 11
        set tics nomirror
        set style line 12 lc rgb '#808080' lt 0 lw 1
        set grid back ls 12

set terminal pngcairo size 820,500 enhanced font 'Verdana,9'
        set output 'output_run_4_diff_pred_0.png'

set key top right
            #set yrange [0.0:2]

plot 'output_run_4_diff_pred.txt' u 1:2 w i ls 2 t 'Good prediction',             'output_run_4_diff_bad_pred.txt' u 1:2 w i ls 1 t 'Wrong prediction'

reset
        
        set style line 1 lc rgb '#8b1a0e' pt 1 ps 0.1 lt 1 lw 1 # --- red
        set style line 2 lc rgb '#5e9c36' pt 8 ps 0.1 lt 1 lw 1 # --- green
        set style line 3 lc rgb '#4488bb' pt 5 ps 0.1 lt 1 lw 1 # --- blue
        
        set style line 11 lc rgb '#808080' lt 1
        set border 3 back ls 11
        set tics nomirror
        set style line 12 lc rgb '#808080' lt 0 lw 1
        set grid back ls 12

set terminal svg size 820,500 fname 'Verdana, Helvetica, Arial, sans-serif'
        set output 'output_run_4_diff_pred_0.svg'

set key top right
            #set yrange [0.0:2]

plot 'output_run_4_diff_pred.txt' u 1:2 w i ls 2 t 'Good prediction',             'output_run_4_diff_bad_pred.txt' u 1:2 w i ls 1 t 'Wrong prediction'

reset
        
        set style line 1 lc rgb '#8b1a0e' pt 1 ps 0.1 lt 1 lw 1 # --- red
        set style line 2 lc rgb '#5e9c36' pt 8 ps 0.1 lt 1 lw 1 # --- green
        set style line 3 lc rgb '#4488bb' pt 5 ps 0.1 lt 1 lw 1 # --- blue
        
        set style line 11 lc rgb '#808080' lt 1
        set border 3 back ls 11
        set tics nomirror
        set style line 12 lc rgb '#808080' lt 0 lw 1
        set grid back ls 12

set terminal pngcairo size 820,500 enhanced font 'Verdana,9'
        set output 'output_run_4_diff_pred_1.png'

set key top right
           # set yrange [-0.003:0.003]

plot 'output_run_4_positive_diff_pred.txt' u 1:2 w i ls 2 t 'Good prediction',            'output_run_4_diff_negative_pred.txt' u 1:2 w i ls 2 notitle,            'output_run_4_diff_positive_bad_pred.txt' u 1:2 w i ls 1 t 'Wrong prediction',            'output_run_4_diff_negative_bad_pred.txt' u 1:2 w i ls 1 notitle

reset
        
        set style line 1 lc rgb '#8b1a0e' pt 1 ps 0.1 lt 1 lw 1 # --- red
        set style line 2 lc rgb '#5e9c36' pt 8 ps 0.1 lt 1 lw 1 # --- green
        set style line 3 lc rgb '#4488bb' pt 5 ps 0.1 lt 1 lw 1 # --- blue
        
        set style line 11 lc rgb '#808080' lt 1
        set border 3 back ls 11
        set tics nomirror
        set style line 12 lc rgb '#808080' lt 0 lw 1
        set grid back ls 12

set terminal svg size 820,500 fname 'Verdana, Helvetica, Arial, sans-serif'
        set output 'output_run_4_diff_pred_1.svg'

set key top right
           # set yrange [-0.003:0.003]

plot 'output_run_4_positive_diff_pred.txt' u 1:2 w i ls 2 t 'Good prediction',            'output_run_4_diff_negative_pred.txt' u 1:2 w i ls 2 notitle,            'output_run_4_diff_positive_bad_pred.txt' u 1:2 w i ls 1 t 'Wrong prediction',            'output_run_4_diff_negative_bad_pred.txt' u 1:2 w i ls 1 notitle

