#!/usr/bin/gnuplot5 


set terminal pngcairo size 600,500 enhanced font 'Verdana,13'
set output 'learning_curve_breast.png'


set style line 11 lc rgb '#808080' lt 1
set border 3 back ls 11
set tics nomirror
set style line 12 lc rgb '#808080' lt 0 lw 1
set grid back ls 12
set key bottom right
set ytics nomirror
set tics out
set xtics font ", 16"
set ytics font ", 16"
set key font ", 16"
set style fill transparent solid 0.5
set yrange [0.86:1]
plot 'breast.size.txt' u 1:($8 - $11):($8 + $11) lc rgb '#8b1a0e' with filledcurves closed notitle, '' u 1:($10 - $12):($10 + $12) lc rgb '#5e9c36' with filledcurves closed notitle,  '' u 1:8  t 'test' w lp ps 2 lw 2.5 lc rgb '#8b1a0e',  '' u 1:10 t 'training'  w lp ps 2 lw 2.5 lc black, 


reset

set terminal pngcairo size 600,500 enhanced font 'Verdana,13'
set output 'learning_curve_adult.png'


set style line 11 lc rgb '#808080' lt 1
set border 3 back ls 11
set tics nomirror
set style line 12 lc rgb '#808080' lt 0 lw 1
set grid back ls 12
set key top right
set ytics nomirror
set tics out
set xtics font ", 16"
set ytics font ", 16"
set key font ", 16"
set style fill transparent solid 0.5
plot 'adult.size.txt' u 1:($8 - $11):($8 + $11) lc rgb '#8b1a0e' with filledcurves closed notitle, '' u 1:($10 - $12):($10 + $12) lc rgb '#5e9c36' with filledcurves closed notitle,  '' u 1:8  t 'test' w lp ps 2 lw 2.5 lc rgb '#8b1a0e',  '' u 1:10 t 'training'  w lp ps 2 lw 2.5 lc black, 


reset

set terminal pngcairo size 600,500 enhanced font 'Verdana,9'
set output 'learning_curve_heart.png'


set style line 11 lc rgb '#808080' lt 1
set border 3 back ls 11
set tics nomirror
set style line 12 lc rgb '#808080' lt 0 lw 1
set grid back ls 12
set key top right
set ytics nomirror
set tics out
set xtics font ", 16"
set ytics font ", 16"
set key font ", 16"
set yrange[0.5:1]
set style fill transparent solid 0.5
plot 'heart.size.txt' u 1:($8 - $11):($8 + $11) lc rgb '#8b1a0e' with filledcurves closed notitle, '' u 1:($10 - $12):($10 + $12) lc rgb '#5e9c36' with filledcurves closed notitle,  '' u 1:8  t 'test' w lp ps 2 lw 2.5 lc rgb '#8b1a0e',  '' u 1:10 t 'training'  w lp ps 2 lw 2.5 lc black, 


reset 

set terminal pngcairo size 600,500 enhanced font 'Verdana,9'
set output 'learning_curve_phishing.png'


set style line 11 lc rgb '#808080' lt 1
set border 3 back ls 11
set tics nomirror
set style line 12 lc rgb '#808080' lt 0 lw 1
set grid back ls 12
set key bottom right
set ytics nomirror
set tics out
set xtics font ", 16"
set ytics font ", 16"
set key font ", 16"
set yrange[0.75:1]
set style fill transparent solid 0.5
plot 'phishing.size.txt' u 1:($8 - $11):($8 + $11) lc rgb '#8b1a0e' with filledcurves closed notitle, '' u 1:($10 - $12):($10 + $12) lc rgb '#5e9c36' with filledcurves closed notitle,  '' u 1:8  t 'test' w lp ps 2 lw 2.5 lc rgb '#8b1a0e',  '' u 1:10 t 'training'  w lp ps 2 lw 2.5 lc black, 




set terminal pngcairo size 600,500 enhanced font 'Verdana,9'
set output 'learning_curve_splice.png'

set style line 1 lc rgb '#8b1a0e' pt 1 ps 0.4 lt 1 lw 2 # --- red

set style line 11 lc rgb '#808080' lt 1
set border 3 back ls 11
set tics nomirror
set style line 12 lc rgb '#808080' lt 0 lw 1
set grid back ls 12
set key bottom right
set ytics nomirror
set tics out
set xtics font ", 16"
set ytics font ", 16"
set key font ", 16"
set yrange[0.75:1]
set style fill transparent solid 0.5
plot 'splice.size.txt' u 1:($8 - $11):($8 + $11) lc rgb '#8b1a0e' with filledcurves closed notitle, '' u 1:($10 - $12):($10 + $12) lc rgb '#5e9c36' with filledcurves closed notitle,  '' u 1:8  t 'test' w lp ps 2 lw 2.5 lc rgb '#8b1a0e',  '' u 1:10 t 'training'  w lp ps 2 lw 2.5 lc black, 



set terminal pngcairo size 600,500 enhanced font 'Verdana,9'
set output 'learning_curve_mushrooms.png'


set style line 11 lc rgb '#808080' lt 1
set border 3 back ls 11
set tics nomirror
set style line 12 lc rgb '#808080' lt 0 lw 1
set grid back ls 12
set key bottom right
set ytics nomirror
set tics out
set xtics font ", 16"
set ytics font ", 16"
set key font ", 16"
set yrange[0.95:1]
set style fill transparent solid 0.5
plot 'mushrooms.size.txt' u 1:($8 - $11):($8 + $11) lc rgb '#8b1a0e' with filledcurves closed notitle, '' u 1:($10 - $12):($10 + $12) lc rgb '#5e9c36' with filledcurves closed notitle,  '' u 1:8  t 'test' w lp ps 2 lw 2.5 lc rgb '#8b1a0e',  '' u 1:10 t 'training'  w lp ps 2 lw 2.5 lc black, 




set terminal pngcairo size 600,500 enhanced font 'Verdana,9'
set output 'learning_curve_skin.png'


set style line 11 lc rgb '#808080' lt 1
set border 3 back ls 11
set tics nomirror
set style line 12 lc rgb '#808080' lt 0 lw 1
set grid back ls 12
set key bottom right
set ytics nomirror
set tics out
set xtics font ", 16"
set ytics font ", 16"
set key font ", 16"
set yrange[0.70:1]
set style fill transparent solid 0.5
plot 'skin.size.txt' u 1:($8 - $11):($8 + $11) lc rgb '#8b1a0e' with filledcurves closed notitle, '' u 1:($10 - $12):($10 + $12) lc rgb '#5e9c36' with filledcurves closed notitle,  '' u 1:8  t 'test' w lp ps 2 lw 2.5 lc rgb '#8b1a0e',  '' u 1:10 t 'training'  w lp ps 2 lw 2.5 lc black, 

