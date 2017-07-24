#!/bin/bash

mkdir res

for i in `seq 100 10 200`;
do
    echo $i
    ../../build/hcbr -o ../../data/SCDB_2016_01_outcomes.txt -c ../../data/SCDB_2016_01_cases.txt -l $i > ./res/first_${i}.txt
done    

for i in `seq 300 100 1000`;
do
    echo $i
    ../../build/hcbr -o ../../data/SCDB_2016_01_outcomes.txt -c ../../data/SCDB_2016_01_cases.txt -l $i > ./res/first${i}.txt
done

