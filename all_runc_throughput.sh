#!/bin/bash


REPEAT=10

echo "****BACKUP AND REMOVE EXISTING RESULTS****"
sudo rm -rf net_result.bak
sudo cp -r net_result net_result.bak 2> /dev/null
sudo rm -rf net_result

echo "****START <DEFAULT> EXPERIMENT****"
# default
./runc_throughput.sh -r "${REPEAT}" 

echo "****START <CPU> EXPERIMENT****"
# CPU 
for arg in 1 2 4
do
	./runc_throughput.sh -r "${REPEAT}" -c "${arg}"
done

echo "****START <MEMORY> EXPERIMENT****"
# Memory
for arg in 512m 1G 2G 3G
do
	./runc_throughput.sh -r "${REPEAT}" -m "${arg}"
done


echo "****START <STREAM> EXPERIMENT****"
# Stream
for arg in 1 5 10
do
	./runc_throughput.sh -r "${REPEAT}" -s "${arg}"
done

echo "****START <CONCURRENCY> EXPERIMENT****"
# Concurrency
for arg in 1 4 8
do
	./runc_throughput.sh -r "${REPEAT}" -n "${arg}"
done


echo "***************************************************"
echo "**** ALL EXPERIMENTS ARE SUCCESSFULLY FINISHED ****"
echo "***************************************************"
