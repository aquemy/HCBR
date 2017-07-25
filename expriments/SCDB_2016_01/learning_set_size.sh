#!/bin/bash

t=$(date +%s)
out=res_${t}
mkdir $out

for i in `seq 100 10 200`;
do
    echo $i
    ../../build/hcbr -o ../../data/SCDB_2016_01_caseCentered_Citation_outcomes.txt -c ../../data/SCDB_2016_01_caseCentered_Citation_casebase.txt -l $i > ./${out}/first_${i}.txt
done    

for i in `seq 300 100 1000`;
do
    echo $i
    ../../build/hcbr -o ../../data/SCDB_2016_01_caseCentered_Citation_outcomes.txt -c ../../data/SCDB_2016_01_caseCentered_Citation_casebase.txt -l $i > ./${out}/first_${i}.txt
done
