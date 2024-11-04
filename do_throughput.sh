#!/bin/bash


# ${1}: result file name
# <....res>_<throughput>_<experimental option name>_<experimental option argument>_<message size>.txt
# e.g., $HOME/net_result/runc/throughput/res_throughput_mem_1G_256.txt
RESULT_FILE=${1}
EXP=$(echo "${RESULT_FILE}" | awk -F'_' '{print $3}')
M_SIZE=$(echo "${RESULT_FILE}" | awk -F'_' '{print $NF}' | sed 's/\.txt//')


# ${2}: repeat number
# e.g., 3, 10
REPEAT=${2}

# test time (sec)
TIME=20

SERVER_IP="192.168.51.232"
HEADER="Recv Socket Size(B)  Send Socket Size(B)  Send Message Size(B)  Elapsed Time(s)  Throughput(10^6bps)"

RESULT_DIR="$HOME/net_result/runc/throughput/"
mkdir -p ${RESULT_DIR}


if [[ "${EXP}" == stream* || "${EXP}" == concurrency* ]]; then
	if [ ! -s "${RESULT_FILE}" ]; then # if it's first time
		echo "${HEADER}" > ${RESULT_FILE}
	fi

	netperf -H ${SERVER_IP} -l ${TIME} | tail -n 1 >> ${RESULT_FILE} # with default message size
		
else
	echo "${HEADER}" > ${RESULT_FILE}
	
	for i in $(seq 1 ${REPEAT})
	do
		netperf -H ${SERVER_IP} -l ${TIME} -- -m ${M_SIZE} | tail -n 1 >> ${RESULT_FILE}
done

fi
