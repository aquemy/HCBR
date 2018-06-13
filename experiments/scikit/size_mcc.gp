#!/usr/bin/gnuplot5 

set terminal pngcairo size 600,500 enhanced font 'Verdana,9'
set output 'mcc_by_examples.png'

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
plot 'adult.size.txt' u 1:9  t 'adult' w lp ps 2 lw 2, 'audiology.size.txt' u 1:9  t 'audiology' w lp ps 2 lw 2, 'breast.size.txt' u 1:9  t 'breast' w lp ps 2 lw 2, 'heart.size.txt' u 1:9  t 'heart' w lp ps 2 lw 2, 'mushrooms.size.txt' u 1:9  t 'mushrooms' w lp ps 2 lw 2, 'phishing.size.txt' u 1:9  t 'phishing' w lp ps 2 lw 2, 'skin.size.txt' u 1:9  t 'skin' w lp ps 2 lw 2, 'splice.size.txt' u 1:9  t 'splice' w lp  ps 2 lw 2



set terminal pngcairo size 600,500 enhanced font 'Verdana,9' ps 2 lw 2
set output 'mcc_by_examples_adult.png'

plot 'adult.size.txt' u 1:9 w lp t 'HCBR', 'AdaBoost_adult_training_size.txt' u 1:3  w lp t 'AdaBoost', 'Nearest Neighbors_adult_training_size.txt' u 1:3  w lp t 'Nearest Neighbors', 'Linear SVM_adult_training_size.txt' u 1:3  w lp t 'Linear SVM', 'RBF SVM_adult_training_size.txt' u 1:3  w lp t 'RBF SVM', 'Decision Tree_adult_training_size.txt' u 1:3  w lp t 'Decision Tree', 'Random Forest_adult_training_size.txt' u 1:3  w lp t 'Random Forest', 'Neural Net_adult_training_size.txt' u 1:3  w lp t 'Neural Net', 'Naive Bayes_adult_training_size.txt' u 1:3  w lp t 'Naive Bayes', 'QDA_adult_training_size.txt' u 1:3  w lp t 'QDA'



set terminal pngcairo size 600,500 enhanced font 'Verdana,9'
set output 'mcc_by_examples_breast.png'
set yrange [0.6:1.0]
plot 'breast.size.txt' u 1:9 w lp t 'HCBR', 'AdaBoost_breast_training_size.txt' u 1:3  w lp t 'AdaBoost', 'Nearest Neighbors_breast_training_size.txt' u 1:3  w lp t 'Nearest Neighbors', 'Linear SVM_breast_training_size.txt' u 1:3  w lp t 'Linear SVM', 'RBF SVM_breast_training_size.txt' u 1:3  w lp t 'RBF SVM', 'Decision Tree_breast_training_size.txt' u 1:3  w lp t 'Decision Tree', 'Random Forest_breast_training_size.txt' u 1:3  w lp t 'Random Forest', 'Neural Net_breast_training_size.txt' u 1:3  w lp t 'Neural Net', 'Naive Bayes_breast_training_size.txt' u 1:3  w lp t 'Naive Bayes', 'QDA_breast_training_size.txt' u 1:3  w lp t 'QDA'





set terminal pngcairo size 600,500 enhanced font 'Verdana,9'
set output 'mcc_by_examples_heart.png'
set yrange [0.0:0.7]
plot 'heart.size.txt' u 1:9 w lp t 'HCBR', 'AdaBoost_heart_training_size.txt' u 1:3  w lp t 'AdaBoost', 'Nearest Neighbors_heart_training_size.txt' u 1:3  w lp t 'Nearest Neighbors', 'Linear SVM_heart_training_size.txt' u 1:3  w lp t 'Linear SVM', 'RBF SVM_heart_training_size.txt' u 1:3  w lp t 'RBF SVM', 'Decision Tree_heart_training_size.txt' u 1:3  w lp t 'Decision Tree', 'Random Forest_heart_training_size.txt' u 1:3  w lp t 'Random Forest', 'Neural Net_heart_training_size.txt' u 1:3  w lp t 'Neural Net', 'Naive Bayes_heart_training_size.txt' u 1:3  w lp t 'Naive Bayes', 'QDA_heart_training_size.txt' u 1:3  w lp t 'QDA'




set terminal pngcairo size 600,500 enhanced font 'Verdana,9'
set output 'mcc_by_examples_mushrooms.png'
set yrange [0.84:1]
plot 'mushrooms.size.txt' u 1:9 w lp t 'HCBR', 'AdaBoost_mushrooms_training_size.txt' u 1:3  w lp t 'AdaBoost', 'Nearest Neighbors_mushrooms_training_size.txt' u 1:3  w lp t 'Nearest Neighbors', 'Linear SVM_mushrooms_training_size.txt' u 1:3  w lp t 'Linear SVM', 'RBF SVM_mushrooms_training_size.txt' u 1:3  w lp t 'RBF SVM', 'Decision Tree_mushrooms_training_size.txt' u 1:3  w lp t 'Decision Tree', 'Random Forest_mushrooms_training_size.txt' u 1:3  w lp t 'Random Forest', 'Neural Net_mushrooms_training_size.txt' u 1:3  w lp t 'Neural Net', 'Naive Bayes_mushrooms_training_size.txt' u 1:3  w lp t 'Naive Bayes', 'QDA_mushrooms_training_size.txt' u 1:3  w lp t 'QDA'



set terminal pngcairo size 600,500 enhanced font 'Verdana,9'
set output 'mcc_by_examples_phishing.png'
set yrange [0.42:0.97]
plot 'phishing.size.txt' u 1:9 w lp t 'HCBR', 'AdaBoost_phishing_training_size.txt' u 1:3  w lp t 'AdaBoost', 'Nearest Neighbors_phishing_training_size.txt' u 1:3  w lp t 'Nearest Neighbors', 'Linear SVM_phishing_training_size.txt' u 1:3  w lp t 'Linear SVM', 'RBF SVM_phishing_training_size.txt' u 1:3  w lp t 'RBF SVM', 'Decision Tree_phishing_training_size.txt' u 1:3  w lp t 'Decision Tree', 'Random Forest_phishing_training_size.txt' u 1:3  w lp t 'Random Forest', 'Neural Net_phishing_training_size.txt' u 1:3  w lp t 'Neural Net', 'Naive Bayes_phishing_training_size.txt' u 1:3  w lp t 'Naive Bayes', 'QDA_phishing_training_size.txt' u 1:3  w lp t 'QDA'



set terminal pngcairo size 600,500 enhanced font 'Verdana,9'
set output 'mcc_by_examples_skin.png'
set yrange [0.:1]
plot 'skin.size.txt' u 1:9 w lp t 'HCBR', 'AdaBoost_skin_training_size.txt' u 1:3  w lp t 'AdaBoost', 'Nearest Neighbors_skin_training_size.txt' u 1:3  w lp t 'Nearest Neighbors', 'Linear SVM_skin_training_size.txt' u 1:3  w lp t 'Linear SVM', 'RBF SVM_skin_training_size.txt' u 1:3  w lp t 'RBF SVM', 'Decision Tree_skin_training_size.txt' u 1:3  w lp t 'Decision Tree', 'Random Forest_skin_training_size.txt' u 1:3  w lp t 'Random Forest', 'Neural Net_skin_training_size.txt' u 1:3  w lp t 'Neural Net', 'Naive Bayes_skin_training_size.txt' u 1:3  w lp t 'Naive Bayes', 'QDA_skin_training_size.txt' u 1:3  w lp t 'QDA'



set terminal pngcairo size 600,500 enhanced font 'Verdana,9'
set output 'mcc_by_examples_splice.png'
set yrange [0.2:1]
plot 'splice.size.txt' u 1:9 w lp t 'HCBR', 'AdaBoost_splice_training_size.txt' u 1:3  w lp t 'AdaBoost', 'Nearest Neighbors_splice_training_size.txt' u 1:3  w lp t 'Nearest Neighbors', 'Linear SVM_splice_training_size.txt' u 1:3  w lp t 'Linear SVM', 'RBF SVM_splice_training_size.txt' u 1:3  w lp t 'RBF SVM', 'Decision Tree_splice_training_size.txt' u 1:3  w lp t 'Decision Tree', 'Random Forest_splice_training_size.txt' u 1:3  w lp t 'Random Forest', 'Neural Net_splice_training_size.txt' u 1:3  w lp t 'Neural Net', 'Naive Bayes_splice_training_size.txt' u 1:3  w lp t 'Naive Bayes', 'QDA_splice_training_size.txt' u 1:3  w lp t 'QDA'


