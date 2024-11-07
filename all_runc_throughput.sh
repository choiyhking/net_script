#!/bin/bash

echo "Backup and Remove existing results..."
sudo cp -r net_result net_result.bak
sudo rm -rf net_result

REPEAT=10

echo "Start \"default\" experiment..."
# default
./runc_throughput.sh -r ${REPEAT}

echo "Start \"CPU\" experiment..."
# CPU 
for arg in 1 2 4
do
	./runc_throughput.sh -r ${REPEAT} -c ${arg}
done

echo "Start \"Memory\" experiment..."
# Memory
for arg in 512m 1G 2G
do
	./runc_throughput.sh -r ${REPEAT} -m ${arg}
done

echo "Start \"Stream\" experiment..."
# Stream
for arg in 1 5 10
do
	./runc_throughput.sh -r ${REPEAT} -s ${arg}
done

echo "Start \"Concurrency\" experiment..."
# Concurrency
for arg in 1 4 8
do
	./runc_throughput.sh -r ${REPEAT} -n ${arg}
done

echo "All experiments finished !!"
