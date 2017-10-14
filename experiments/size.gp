#!/usr/bin/gnuplot5 

set terminal pngcairo size 600,500 enhanced font 'Verdana,9'
set output 'accuracy_by_examples.png'

set style line 1 lc rgb '#8b1a0e' pt 1 ps 0.4 lt 1 lw 2 # --- red
set style line 2 lc rgb '#5e9c36' pt 8 ps 0.4 lt 1 lw 2 # --- green
set style line 3 lc rgb '#4488bb' pt 5 ps 0.4 lt 1 lw 2 # --- blue
set style line 11 lc rgb '#808080' lt 1
set border 3 back ls 11
set tics nomirror
set style line 12 lc rgb '#808080' lt 0 lw 1
set grid back ls 12
set key bottom right
set ytics nomirror
set tics out
set xtics font ", 12"
set ytics font ", 12"
set key font ", 12"
#set yrange autoscale
set pointintervalbox 3
plot 'adult.size.txt' u 1:8  t 'adult' w lp ps 2 lw 2, 'audiology.size.txt' u 1:8  t 'audiology' w lp ps 2 lw 2, 'breast.size.txt' u 1:8  t 'breast' w lp ps 2 lw 2, 'heart.size.txt' u 1:8  t 'heart' w lp ps 2 lw 2, 'mushrooms.size.txt' u 1:8  t 'mushrooms' w lp ps 2 lw 2, 'phishing.size.txt' u 1:8  t 'phishing' w lp ps 2 lw 2, 'skin.size.txt' u 1:8  t 'skin' w lp ps 2 lw 2, 'splice.size.txt' u 1:8  t 'splice' w lp  ps 2 lw 2


set terminal pngcairo size 600,500 enhanced font 'Verdana,9'
set output 'accuracy_time_phishing.png'

set style line 1 lc rgb '#8b1a0e' pt 1 ps 0.4 lt 1 lw 2 # --- red
set style line 2 lc rgb '#5e9c36' pt 8 ps 0.4 lt 1 lw 2 # --- green
set style line 3 lc rgb '#4488bb' pt 5 ps 0.4 lt 1 lw 2 # --- blue
set style line 11 lc rgb '#808080' lt 1
set border 3 back ls 11
set tics nomirror
set style line 12 lc rgb '#808080' lt 0 lw 1
set grid back ls 12
set key bottom right
set ytics nomirror
set tics out
set xtics font ", 12"
set ytics font ", 12"
set key font ", 12"
#set yrange autoscale
set grid x y2
set ytics nomirror
set y2tics
set tics out
set y2tics font ", 12"
set autoscale y2
set autoscale y
set pointintervalbox 3
stats 'phishing.size.txt' u 1:8 nooutput
delta_v(x) = ( vD = x - old_v, old_v = x, vD)
old_v = NaN
plot 'phishing.size.txt' u 1:8  t 'phishing' w lp ps 2 lw 2,  'phishing.size.txt' u 1:($3 + $4 + $5) w lp ps 2 lw 2  axis x1y2 t 'Time', '' u 1:(delta_v($8))  w lp ps 2 lw 2, '' u 1:((delta_v($8)) / (delta_v($3 + $4 + $5)))  w lp ps 2 lw 2

#, STATS_min_y

reset
set terminal pngcairo size 600,500 enhanced font 'Verdana,9'
set output 'time_proportion_mushrooms.png'

set style line 1 lc rgb '#8b1a0e' pt 1 ps 0.4 lt 1 lw 2 # --- red
set style line 2 lc rgb '#5e9c36' pt 8 ps 0.4 lt 1 lw 2 # --- green
set style line 3 lc rgb '#4488bb' pt 5 ps 0.4 lt 1 lw 2 # --- blue
set style line 11 lc rgb '#808080' lt 1
set border 3 back ls 11
set tics nomirror
set style line 12 lc rgb '#808080' lt 0 lw 1
set grid back ls 12
set key center right
set ytics nomirror
set tics out
set xtics font ", 12"
set ytics font ", 12"
set key font ", 12"
#set yrange autoscale
set pointintervalbox 3
plot 'mushrooms.size.txt' u 1:($3 / ($3 + $4 + $5 + $6)) w lp ps 2 lw 2 t 'Building' , '' u 1:($4 / ($3 + $4 + $5 + $6)) w lp ps 2 lw 2 t 'Strength', '' u 1:($5 / ($3 + $4 + $5 + $6)) w lp ps 2 lw 2 t 'Training', '' u 1:($6 / ($3 + $4 + $5 + $6)) w lp ps 2 lw 2 t 'Prediction'



reset
set terminal pngcairo size 600,500 enhanced font 'Verdana,9'
set output 'time_proportion_adult.png'

set style line 1 lc rgb '#8b1a0e' pt 1 ps 0.4 lt 1 lw 2 # --- red
set style line 2 lc rgb '#5e9c36' pt 8 ps 0.4 lt 1 lw 2 # --- green
set style line 3 lc rgb '#4488bb' pt 5 ps 0.4 lt 1 lw 2 # --- blue
set style line 11 lc rgb '#808080' lt 1
set border 3 back ls 11
set tics nomirror
set style line 12 lc rgb '#808080' lt 0 lw 1
set grid back ls 12
set key center right
set ytics nomirror
set tics out
set xtics font ", 12"
set ytics font ", 12"
set key font ", 12"
#set yrange autoscale
set pointintervalbox 3
plot 'adult.size.txt' u 1:($3 / ($3 + $4 + $5 + $6)) w lp ps 2 lw 2 t 'Building' , '' u 1:($4 / ($3 + $4 + $5 + $6)) w lp ps 2 lw 2 t 'Strength', '' u 1:($5 / ($3 + $4 + $5 + $6)) w lp ps 2 lw 2 t 'Training', '' u 1:($6 / ($3 + $4 + $5 + $6)) w lp ps 2 lw 2 t 'Prediction'


reset
set terminal pngcairo size 600,500 enhanced font 'Verdana,9'
set output 'time_proportion_adult_2.png'

set style line 1 lc rgb '#8b1a0e' pt 1 ps 0.4 lt 1 lw 2 # --- red
set style line 2 lc rgb '#5e9c36' pt 8 ps 0.4 lt 1 lw 2 # --- green
set style line 3 lc rgb '#4488bb' pt 5 ps 0.4 lt 1 lw 2 # --- blue
set style line 11 lc rgb '#808080' lt 1
set border 3 back ls 11
set tics nomirror
set style line 12 lc rgb '#808080' lt 0 lw 1
set grid back ls 12
set key center right
set ytics nomirror
set tics out
set xtics font ", 12"
set ytics font ", 12"
set key font ", 12"
#set yrange autoscale
set pointintervalbox 3
plot 'adult.size.txt' u 1:($3 / ($3 + $4 + $5)) w lp ps 2 lw 2 t 'Building' , '' u 1:($4 / ($3 + $4 + $5)) w lp ps 2 lw 2 t 'Strength', '' u 1:($5 / ($3 + $4 + $5)) w lp ps 2 lw 2 t 'Training'



reset
set terminal pngcairo size 600,500 enhanced font 'Verdana,9'
set output 'time_proportion_mushrooms_2.png'

set style line 1 lc rgb '#8b1a0e' pt 1 ps 0.4 lt 1 lw 2 # --- red
set style line 2 lc rgb '#5e9c36' pt 8 ps 0.4 lt 1 lw 2 # --- green
set style line 3 lc rgb '#4488bb' pt 5 ps 0.4 lt 1 lw 2 # --- blue
set style line 11 lc rgb '#808080' lt 1
set border 3 back ls 11
set tics nomirror
set style line 12 lc rgb '#808080' lt 0 lw 1
set grid back ls 12
set key center right
set ytics nomirror
set tics out
set xtics font ", 12"
set ytics font ", 12"
set key font ", 12"
#set yrange autoscale
set pointintervalbox 3
plot 'mushrooms.size.txt' u 1:($3 / ($3 + $4 + $5)) w lp ps 2 lw 2 t 'Building' , '' u 1:($4 / ($3 + $4 + $5)) w lp ps 2 lw 2 t 'Strength', '' u 1:($5 / ($3 + $4 + $5)) w lp ps 2 lw 2 t 'Training'


reset
set terminal pngcairo size 600,500 enhanced font 'Verdana,9'
set output 'time_k.png'

set style line 1 lc rgb '#8b1a0e' pt 1 ps 0.4 lt 1 lw 2 # --- red
set style line 2 lc rgb '#5e9c36' pt 8 ps 0.4 lt 1 lw 2 # --- green
set style line 3 lc rgb '#4488bb' pt 5 ps 0.4 lt 1 lw 2 # --- blue
set style line 11 lc rgb '#808080' lt 1
set border 3 back ls 11
set tics nomirror
set style line 12 lc rgb '#808080' lt 0 lw 1
set grid back ls 12
set key top left
set ytics nomirror
set xtics font ", 12"
set ytics font ", 12"
set key font ", 12"
set grid back ls 12
set grid x y2
set ytics nomirror
set y2tics
set tics out
set y2tics font ", 12"
set autoscale y2
set autoscale y
set datafile separator ","
plot 'k_sizes.csv' u 1:7  w l lw 2  axis x1y2 t 'Building', '' u 1:30  w l lw 2 t 'Strength'
#7 - building time
#30 - strength time

reset
set terminal pngcairo size 600,500 enhanced font 'Verdana,9'
set output 'time_n.png'

set style line 1 lc rgb '#8b1a0e' pt 1 ps 0.4 lt 1 lw 2 # --- red
set style line 2 lc rgb '#5e9c36' pt 8 ps 0.4 lt 1 lw 2 # --- green
set style line 3 lc rgb '#4488bb' pt 5 ps 0.4 lt 1 lw 2 # --- blue
set style line 11 lc rgb '#808080' lt 1
set border 3 back ls 11
set tics nomirror
set style line 12 lc rgb '#808080' lt 0 lw 1
set grid back ls 12
set key top left
set ytics nomirror
set xtics font ", 12"
set ytics font ", 12"

set key font ", 12"
set grid back ls 12
set grid x y2
set ytics nomirror
set y2tics
set tics out
set y2tics font ", 12"
set autoscale y2
set autoscale y
set datafile separator ","
set xrange [0:500]
plot 'n_sizes_k100.csv' u 6:7  w l lw 2  axis x1y2 t 'Building', '' u 6:30  w l lw 2 t 'Strength'
#7 - building time
#30 - strength time


reset
set terminal pngcairo size 600,500 enhanced font 'Verdana,9'
set output 'time_kn.png'

set style line 1 lc rgb '#8b1a0e' pt 1 ps 0.4 lt 1 lw 2 # --- red
set style line 2 lc rgb '#5e9c36' pt 8 ps 0.4 lt 1 lw 2 # --- green
set style line 3 lc rgb '#4488bb' pt 5 ps 0.4 lt 1 lw 2 # --- blue
set style line 11 lc rgb '#808080' lt 1
set border 3 back ls 11
set tics nomirror
set style line 12 lc rgb '#808080' lt 0 lw 1
set grid back ls 12
set key top left
set ytics nomirror
set xtics font ", 12"
set ytics font ", 12"

set key font ", 12"
set grid back ls 12
set grid x y2
set ytics nomirror
set y2tics
set tics out
set y2tics font ", 12"
set autoscale y2
set autoscale y
set datafile separator ","
plot 'sizes_kn.csv' u 6:7  w l lw 2  axis x1y2 t 'Building', '' u 6:30  w l lw 2 t 'Strength'