#!/bin/bash

# ${1}: virtualization platform. e.g., native, runc, kata, fc, vm
# ${2}: experimental options. e.g., _parallel_10, _cpu_2_, _mem_512_, _default_


SERVER_IP="192.168.51.232"
RESULT_DIR="$HOME/net_result/${1}/throughput/"
RESULT_FILE_PREFIX="res_throughput"
RESULT_FILE="${RESULT_DIR}${RESULT_FILE_PREFIX}"
REPEAT=3
HEADER="Recv Socket Size(B)  Send Socket Size(B)  Send Message Size(B)  Elapsed Time(s)  Throughput(10^6bps)"

mkdir -p ${RESULT_DIR} 2>/dev/null

case "${2}" in
	_parallel*)
        rm *${2}* 2>/dev/null
		NEW_RESULT_FILE=${RESULT_FILE}${2}
		echo "${HEADER}" > ${NEW_RESULT_FILE}
		netperf -H ${SERVER_IP} -l 10 | tail -n 1 >> ${NEW_RESULT_FILE}
	        mv ${NEW_RESULT_FILE} ${NEW_RESULT_FILE}.txt
		;;
	_cpu*)
        rm *${2}* 2>/dev/null
		;;&
	_mem*)
        #rm *${2}* 2>/dev/null
		;;&
	_default*)
		rm *${2}* 2>/dev/null
		;;&
	*)
		for M_SIZE in 64 128 256 512 1024 2048 4096
		do
			NEW_RESULT_FILE=${RESULT_FILE}${2}${M_SIZE}
		   	echo "${HEADER}" > ${NEW_RESULT_FILE}
			for i in $(seq 1 ${REPEAT})
			do
				netperf -H ${SERVER_IP} -l 10 -- -m ${M_SIZE} | tail -n 1 >> ${NEW_RESULT_FILE}
			done
   			mv ${NEW_RESULT_FILE} ${NEW_RESULT_FILE}.txt
		done
		;;
esac
