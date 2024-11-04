#!/bin/bash

# ${1}: virtualization platform
# e.g., native, runc, kata, fc, vm
PLATFORM=${1}


# ${2}: experimental options
# e.g., _stream5_2, _concurrency5_3, _cpu_2_, _mem_512_, _default_
EXP=${2}

# ${3}: repeat number
# e.g., 3, 10
REPEAT=${3}

# ${4}: message size
# e.g., 64, 128, 256
M_SIZE=${4}


SERVER_IP="192.168.51.232"
RESULT_DIR="$HOME/net_result/${PLATFORM}/throughput/"
RESULT_FILE_PREFIX="res_throughput"
HEADER="Recv Socket Size(B)  Send Socket Size(B)  Send Message Size(B)  Elapsed Time(s)  Throughput(10^6bps)"
TIME=20


mkdir -p ${RESULT_DIR}

if [[ "${EXP}" == "_stream*" || "${EXP}" == "_concurrency*" ]]; then
	RESULT_FILE=${RESULT_DIR}${RESULT_FILE_PREFIX}${EXP}.txt
	if [ ! -s "${RESULT_FILE}" ]; then # if empty
		echo "${HEADER}" > ${RESULT_FILE}
	fi

	netperf -H ${SERVER_IP} -l ${TIME} | tail -n 1 >> ${RESULT_FILE} # with default message size
		
else
	RESULT_FILE=${RESULT_DIR}${RESULT_FILE_PREFIX}${EXP}${M_SIZE}.txt
	echo "${HEADER}" > ${RESULT_FILE}
	
	for i in $(seq 1 ${REPEAT})
	do
		netperf -H ${SERVER_IP} -l ${TIME} -- -m ${M_SIZE} | tail -n 1 >> ${RESULT_FILE}
	done
fi
