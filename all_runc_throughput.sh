#!/bin/bash


REPEAT=10

#echo "********************************************"
#echo "**** BACKUP AND REMOVE EXISTING RESULTS ****"
#echo "********************************************"
#sudo rm -rf net_result.backup
#sudo cp -r net_result net_result.backup 2> /dev/null
#sudo rm -rf net_result

echo "************************************"
echo "**** START <DEFAULT> EXPERIMENT ****"
echo "************************************"
# default
./runc_throughput.sh -r "${REPEAT}" 

echo "********************************"
echo "**** START <CPU> EXPERIMENT ****"
echo "********************************"
# CPU 
for arg in 1 2 3 4
do
	./runc_throughput.sh -r "${REPEAT}" -c "${arg}"
done

echo "***********************************"
echo "**** START <MEMORY> EXPERIMENT ****"
echo "***********************************"
# Memory
for arg in 512m 1G 2G 4G 6G
do
	./runc_throughput.sh -r "${REPEAT}" -m "${arg}"
done


echo "***********************************"
echo "**** START <STREAM> EXPERIMENT ****"
echo "***********************************"
# Stream
for arg in 1 3 5 10
do
	./runc_throughput.sh -r "${REPEAT}" -s "${arg}"
done

echo "****************************************"
echo "**** START <CONCURRENCY> EXPERIMENT ****"
echo "****************************************"
# Concurrency
for arg in 1 4 8
do
	./runc_throughput.sh -r "${REPEAT}" -n "${arg}"
done


echo "***************************************************"
echo "**** ALL EXPERIMENTS ARE SUCCESSFULLY FINISHED ****"
echo "***************************************************"
