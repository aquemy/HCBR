#!/usr/bin/gnuplot5 

reset
        
        set style line 1 lc rgb '#8b1a0e' pt 1 ps 0.1 lt 1 lw 2 # --- red
        set style line 2 lc rgb '#5e9c36' pt 8 ps 0.1 lt 1 lw 2 # --- green
        set style line 3 lc rgb '#4488bb' pt 5 ps 0.1 lt 1 lw 2 # --- blue
        
        set style line 11 lc rgb '#808080' lt 1
        set border 3 back ls 11
        set tics nomirror
        set style line 12 lc rgb '#808080' lt 0 lw 1
        set grid back ls 12

set terminal pngcairo size 820,500 enhanced font 'Verdana,9'
        set output 'output_run_8_confusion_matrix_0.png'

set key top left

plot 'output_run_8_confusion_matrix.txt' u 0:1 w l ls 3 t 'Total',             'output_run_8_confusion_matrix.txt' u 0:2 w l ls 2 t 'Positive',             'output_run_8_confusion_matrix.txt' u 0:5 w l ls 2 dashtype 2 t 'True Positive',             'output_run_8_confusion_matrix.txt' u 0:7 w l ls 2 dashtype 3 t 'False Positive',             'output_run_8_confusion_matrix.txt' u 0:3 w l ls 1 t 'Negative',             'output_run_8_confusion_matrix.txt' u 0:6 w l ls 1 dashtype 2 t 'True Negative',             'output_run_8_confusion_matrix.txt' u 0:8 w l ls 1 dashtype 3 t 'False Negative'

reset
        
        set style line 1 lc rgb '#8b1a0e' pt 1 ps 0.1 lt 1 lw 2 # --- red
        set style line 2 lc rgb '#5e9c36' pt 8 ps 0.1 lt 1 lw 2 # --- green
        set style line 3 lc rgb '#4488bb' pt 5 ps 0.1 lt 1 lw 2 # --- blue
        
        set style line 11 lc rgb '#808080' lt 1
        set border 3 back ls 11
        set tics nomirror
        set style line 12 lc rgb '#808080' lt 0 lw 1
        set grid back ls 12

set terminal svg size 820,500 fname 'Verdana, Helvetica, Arial, sans-serif'
        set output 'output_run_8_confusion_matrix_0.svg'

set key top left

plot 'output_run_8_confusion_matrix.txt' u 0:1 w l ls 3 t 'Total',             'output_run_8_confusion_matrix.txt' u 0:2 w l ls 2 t 'Positive',             'output_run_8_confusion_matrix.txt' u 0:5 w l ls 2 dashtype 2 t 'True Positive',             'output_run_8_confusion_matrix.txt' u 0:7 w l ls 2 dashtype 3 t 'False Positive',             'output_run_8_confusion_matrix.txt' u 0:3 w l ls 1 t 'Negative',             'output_run_8_confusion_matrix.txt' u 0:6 w l ls 1 dashtype 2 t 'True Negative',             'output_run_8_confusion_matrix.txt' u 0:8 w l ls 1 dashtype 3 t 'False Negative'

reset
        
        set style line 1 lc rgb '#8b1a0e' pt 1 ps 0.1 lt 1 lw 2 # --- red
        set style line 2 lc rgb '#5e9c36' pt 8 ps 0.1 lt 1 lw 2 # --- green
        set style line 3 lc rgb '#4488bb' pt 5 ps 0.1 lt 1 lw 2 # --- blue
        
        set style line 11 lc rgb '#808080' lt 1
        set border 3 back ls 11
        set tics nomirror
        set style line 12 lc rgb '#808080' lt 0 lw 1
        set grid back ls 12

set terminal pngcairo size 820,500 enhanced font 'Verdana,9'
        set output 'output_run_8_confusion_matrix_1.png'

set key bottom right
            set yrange [0:1]

plot 'output_run_8_confusion_matrix.txt' u 0:17 w l ls 3 t 'Accuracy',             'output_run_8_confusion_matrix.txt' u 0:4 w l ls 3 dashtype 2 t 'Prevalence',             'output_run_8_confusion_matrix.txt' u 0:9 w l ls 2 t 'True Positive Rate',             'output_run_8_confusion_matrix.txt' u 0:10 w l ls 1 t 'True Negative Rate',             'output_run_8_confusion_matrix.txt' u 0:11 w l ls 2 lw 1 dashtype 2 t 'Positive Prediction Value',             'output_run_8_confusion_matrix.txt' u 0:12 w l ls 1 lw 1 dashtype 2 t 'Negative Prediction Value'

reset
        
        set style line 1 lc rgb '#8b1a0e' pt 1 ps 0.1 lt 1 lw 2 # --- red
        set style line 2 lc rgb '#5e9c36' pt 8 ps 0.1 lt 1 lw 2 # --- green
        set style line 3 lc rgb '#4488bb' pt 5 ps 0.1 lt 1 lw 2 # --- blue
        
        set style line 11 lc rgb '#808080' lt 1
        set border 3 back ls 11
        set tics nomirror
        set style line 12 lc rgb '#808080' lt 0 lw 1
        set grid back ls 12

set terminal svg size 820,500 fname 'Verdana, Helvetica, Arial, sans-serif'
        set output 'output_run_8_confusion_matrix_1.svg'

set key bottom right
            set yrange [0:1]

plot 'output_run_8_confusion_matrix.txt' u 0:17 w l ls 3 t 'Accuracy',             'output_run_8_confusion_matrix.txt' u 0:4 w l ls 3 dashtype 2 t 'Prevalence',             'output_run_8_confusion_matrix.txt' u 0:9 w l ls 2 t 'True Positive Rate',             'output_run_8_confusion_matrix.txt' u 0:10 w l ls 1 t 'True Negative Rate',             'output_run_8_confusion_matrix.txt' u 0:11 w l ls 2 lw 1 dashtype 2 t 'Positive Prediction Value',             'output_run_8_confusion_matrix.txt' u 0:12 w l ls 1 lw 1 dashtype 2 t 'Negative Prediction Value'

reset
        
        set style line 1 lc rgb '#8b1a0e' pt 1 ps 0.1 lt 1 lw 2 # --- red
        set style line 2 lc rgb '#5e9c36' pt 8 ps 0.1 lt 1 lw 2 # --- green
        set style line 3 lc rgb '#4488bb' pt 5 ps 0.1 lt 1 lw 2 # --- blue
        
        set style line 11 lc rgb '#808080' lt 1
        set border 3 back ls 11
        set tics nomirror
        set style line 12 lc rgb '#808080' lt 0 lw 1
        set grid back ls 12

set terminal pngcairo size 820,500 enhanced font 'Verdana,9'
        set output 'output_run_8_confusion_matrix_2.png'

set key bottom right
            set yrange [0:1]

plot 'output_run_8_confusion_matrix.txt' u 0:17 w l ls 3 t 'Accuracy',             'output_run_8_confusion_matrix.txt' u 0:18 w l ls 1 t 'F1 Score',             'output_run_8_confusion_matrix.txt' u 0:19 w l ls 2 t 'Matthews correlation coefficient'

reset
        
        set style line 1 lc rgb '#8b1a0e' pt 1 ps 0.1 lt 1 lw 2 # --- red
        set style line 2 lc rgb '#5e9c36' pt 8 ps 0.1 lt 1 lw 2 # --- green
        set style line 3 lc rgb '#4488bb' pt 5 ps 0.1 lt 1 lw 2 # --- blue
        
        set style line 11 lc rgb '#808080' lt 1
        set border 3 back ls 11
        set tics nomirror
        set style line 12 lc rgb '#808080' lt 0 lw 1
        set grid back ls 12

set terminal svg size 820,500 fname 'Verdana, Helvetica, Arial, sans-serif'
        set output 'output_run_8_confusion_matrix_2.svg'

set key bottom right
            set yrange [0:1]

plot 'output_run_8_confusion_matrix.txt' u 0:17 w l ls 3 t 'Accuracy',             'output_run_8_confusion_matrix.txt' u 0:18 w l ls 1 t 'F1 Score',             'output_run_8_confusion_matrix.txt' u 0:19 w l ls 2 t 'Matthews correlation coefficient'

