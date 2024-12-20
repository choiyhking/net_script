#!/bin/bash


echo "Select the virtualization platform (e.g., runc, kata, fc, vm):"
read -p ">> " PLATFORM

echo "Enter the number of iterations (e.g., 10):"
read -p ">> " REPEAT

source ./tx_commons.sh
echo "Current configurations: "
echo -e "\tTest time (sec): ${TIME}"
echo -e "\tMessage sizes (B): ${M_SIZES[@]}"
echo "Continue? (y/n)"
read -p ">> " ANS

if [ ${ANS} != "y" ]; then
    exit 0
fi

# Remove existing results
sudo rm -rf net_result/${PLATFORM}/basic/*_tx_*


echo "************************************"
echo "**** START <DEFAULT> EXPERIMENT ****"
echo "************************************"
# Default
./${PLATFORM}_tx.sh -r ${REPEAT}
echo ""


echo "********************************"
echo "**** START <CPU> EXPERIMENT ****"
echo "********************************"
# CPU 
for arg in 1 2 3 4
do
	echo "CPU: ${arg}"
	./${PLATFORM}_tx.sh -r ${REPEAT} -c ${arg}
done
echo ""


echo "***********************************"
echo "**** START <MEMORY> EXPERIMENT ****"
echo "***********************************"
# Memory
if [[ ${PLATFORM} == "vm" ]]; then ARGS="2G 4G 6G"; else ARGS="512m 1G 2G 4G 6G"; fi

for arg in ${ARGS}
do
	echo "MEMORY: ${arg}"
	./${PLATFORM}_tx.sh -r ${REPEAT} -m ${arg}
done
echo ""


echo "***********************************"
echo "**** START <STREAM> EXPERIMENT ****"
echo "***********************************"
# Stream
for arg in 1 3 5 10
do
	echo "STREAM: ${arg}"
	./${PLATFORM}_tx.sh -r ${REPEAT} -s ${arg}
done
echo ""


echo "****************************************"
echo "**** START <CONCURRENCY> EXPERIMENT ****"
echo "****************************************"
# Concurrency
if [[ ${PLATFORM} == "vm" ]]; then ARGS="1 2 3"; else ARGS="1 2 3 4 8"; fi

for arg in ${ARGS}
do
	echo "CONCURRENCY: ${arg}"
	./${PLATFORM}_tx.sh -r ${REPEAT} -n ${arg}
done
echo ""


echo "***************************************************"
echo "**** ALL EXPERIMENTS ARE SUCCESSFULLY FINISHED ****"
echo "***************************************************"
