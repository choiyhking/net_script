#!/bin/bash

echo "Enter the number of iterations (e.g., 10):"
read -p ">> " REPEAT
#REPEAT=10

echo "Enter the virtualization platform (e.g., runc, kata, fc, vm):"
read -p ">> " PLATFORM
#PLATFORM=${1}

# Remove existing results
sudo rm -rf net_result/${PLATFORM}


echo "************************************"
echo "**** START <DEFAULT> EXPERIMENT ****"
echo "************************************"
# default
./${PLATFORM}_throughput.sh -r "${REPEAT}" 

echo "********************************"
echo "**** START <CPU> EXPERIMENT ****"
echo "********************************"
# CPU 
for arg in 1 2 3 4
do
	./${PLATFORM}_throughput.sh -r "${REPEAT}" -c "${arg}"
done

echo "***********************************"
echo "**** START <MEMORY> EXPERIMENT ****"
echo "***********************************"
# Memory
for arg in 512m 1G 2G 4G 6G
do
	./${PLATFORM}_throughput.sh -r "${REPEAT}" -m "${arg}"
done

echo "***********************************"
echo "**** START <STREAM> EXPERIMENT ****"
echo "***********************************"
# Stream
for arg in 1 3 5 10
do
	./${PLATFORM}_throughput.sh -r "${REPEAT}" -s "${arg}"
done

echo "****************************************"
echo "**** START <CONCURRENCY> EXPERIMENT ****"
echo "****************************************"
# Concurrency
for arg in 1 4 8
do
	./${PLATFORM}_throughput.sh -r "${REPEAT}" -n "${arg}"
done


echo "***************************************************"
echo "**** ALL EXPERIMENTS ARE SUCCESSFULLY FINISHED ****"
echo "***************************************************"
