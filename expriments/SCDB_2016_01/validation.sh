#!/bin/bash

mkdir res

for i in `seq 0 500 8500`;
do
    echo $i
    ../../build/hcbr -o ../../data/SCDB_2016_01_outcomes.txt -c ../../data/SCDB_2016_01_cases.txt -l 500 -k -n $i > ./res/starting_${i}_first_500.txt
done

