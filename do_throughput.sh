#!/bin/bash

# ${1}: virtualization platform. 
# e.g., native, runc, kata, fc, vm

# ${2}: experimental options. 
# e.g., _stream_10, _concurrency5_runc_3, _cpu_2_, _mem_512_, _default_


SERVER_IP="192.168.51.232"
RESULT_DIR="$HOME/net_result/${1}/throughput/"
RESULT_FILE_PREFIX="res_throughput"
REPEAT=3
HEADER="Recv Socket Size(B)  Send Socket Size(B)  Send Message Size(B)  Elapsed Time(s)  Throughput(10^6bps)"

mkdir -p ${RESULT_DIR} 2>/dev/null
touch "${2}"
case "${2}" in
	_stream*|_concurrency*)
		RESULT_FILE=${RESULT_DIR}${RESULT_FILE_PREFIX}${2}.txt
		if [ ! -s "${RESULT_FILE}" ]; then
			echo "${HEADER}" > ${RESULT_FILE}
		fi
		netperf -H ${SERVER_IP} -l 10 | tail -n 1 >> ${RESULT_FILE}
		;;

	_cpu*)
        rm ${RESULT_DIR}*${2}* 2>/dev/null
		;&
	
	_mem*)
        rm ${RESULT_DIR}*${2}* 2>/dev/null
		;&

	_default*)
		rm ${RESULT_DIR}*default* 2>/dev/null
		;&

	*)
		for M_SIZE in 32 64 128 256 512 1024 2048 4096
		do
			RESULT_FILE=${RESULT_DIR}${RESULT_FILE_PREFIX}${2}${M_SIZE}
		   	echo "${HEADER}" > ${RESULT_FILE}
			for i in $(seq 1 ${REPEAT})
			do
				netperf -H ${SERVER_IP} -l 10 -- -m ${M_SIZE} | tail -n 1 >> ${RESULT_FILE}
			done
   			mv ${RESULT_FILE} ${RESULT_FILE}.txt
		done
		;;
esac
