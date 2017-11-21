#!/bin/bash

exe="../../../build/hcbr_learning"
paramFile="hcbr.status"
seed=$5

# Run number
runNb=0
if [ -f "./results/hcbr/runNumber" ]; then
    runNb=`cat ./results/hcbr/runNumber`
    runNb=$((runNb+1))
fi

echo "$runNb" > ./results/hcbr/runNumber

resDir="./results/hcbr/run$runNb"

for i in `seq 6 10`   #Parameter reading $#`
do
shift
done
stringparam=`echo  $* | sed 's/= /=/g'`
stringparam=${stringparam/-i 0/""}
stringparam=${stringparam/-i 1/-i}
stringparam=${stringparam/-z 0/""}
stringparam=${stringparam/-z 1/-z}
stringparam=${stringparam/-r 0/""}
stringparam=${stringparam/-r 1/-r}
echo $stringparam > test.txt


echo "$exe -s -x $seed $stringparam > test_wrapper.txt"
echo "$exe -s -x $seed $stringparam > test_wrapper.txt" > command_line.txt
$exe -s -x $seed $stringparam 1> res_run.txt 2> log_run.txt

# Get the last archive according to timestamp

#lastArch=`ls ./$resDir | grep archTime | cut -d . -f 2 | sort -n | tail -n1`
#echo $lastArch "|" `ls -got ./$resDir | grep archTime | head -1 | awk '{print $7}'` >> ARCHIVES.txt
#../pisa/normalize ${instance%.*}_bounds.txt ./$resDir/archTime.$lastArch ./$resDir/normalized_$maxTime.txt
#../pisa/hyp_ind ../pisa/hyp_ind_param.txt ./$resDir/normalized_$maxTime.txt  ${instance%.*}_ref.txt ./$resDir/hypervolume_$maxTime

#best_sol=`awk 'NR==1 {print $1}' ./$resDir/hypervolume_$maxTime`
cp res_run.txt res_run_$seed.txt
echo `tail -n 1 ./training.run_0.log.csv`
res=`tail -n 1 ./training.run_0.log.csv | cut -d "," -f 2` #15`
res=`tail -n 1 ./hcbr.global.log.csv | cut -d "," -f 61` #47`
res=-${res:1:-1}
maxTime=`tail -n 1 ./log_run.txt`

echo "Result for ParamILS: -1, $maxTime, -1, $res, $seed" # Output for ParamILS

