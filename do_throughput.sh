#!/bin/bash

SERVER_IP="192.168.51.232"
RESULT_DIR="$HOME/result/throughput/"
RESULT_FILE_PREFIX="res_throughput_"
REPEAT=3

mkdir -p ${RESULT_DIR} 2>/dev/null
rm ${RESULT_DIR}${RESULT_FILE_PREFIX}* 2>/dev/null

for M_SIZE in 64 128 256 512 1024 2048 4096
do
	RESULT_FILE="${RESULT_DIR}${RESULT_FILE_PREFIX}${M_SIZE}.txt"
	echo "Recv Socket Size(B)  Send Socket Size(B)  Send Message Size(B)  Elapsed Time(s)  Throughput(10^6bps)" \
		> ${RESULT_FILE}
	for i in $(seq 1 ${REPEAT})
	do
		netperf -H ${SERVER_IP} -l 10 -- -m ${M_SIZE} | tail -n 1 >> ${RESULT_FILE}
	done
done
