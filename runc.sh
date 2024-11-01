#!/bin/bash

CONTAINER_NAME="runc"
#RESULT_DIR="$HOME/net_result/runc/throughput"

# 옵션 파싱
# : 유효하지 않은 옵션이 주어졌을때 오류 메시지 출력
# c: 해당 옵션이 인자를 필요로 한다는 의미
while getopts ":c:m:s:" opt; do
  case $opt in
    c) CPU=${OPTARG} ;;
    m) MEMORY=${OPTARG} ;;
	s) STREAM_NUM=${OPTARG} ;;
    \?) echo "Invalid option -${OPTARG}" >&2; exit 1 ;;
    :) echo "Option -${OPTARG} requires an argument." >&2; exit 1 ;;
  esac
done

#mkdir -p ${RESULT_DIR} 2>/dev/null

sudo docker start ${CONTAINER_NAME} 2>/dev/null

SCRIPT_PATH=/root/net_script/

if [ ! -z ${CPU} ]; then
	sudo docker update --cpus=${CPU} ${CONTAINER_NAME} 2>/dev/null
	sudo docker exec ${CONTAINER_NAME} ${SCRIPT_PATH}do_throughput.sh runc _cpu_${CPU}_
elif [ ! -z ${MEMORY} ]; then
	sudo docker update --memory=${MEMORY} --memory-swap=${MEMORY} ${CONTAINER_NAME} 2>/dev/null
	sudo docker exec ${CONTAINER_NAME} ${SCRIPT_PATH}do_throughput.sh runc _mem_${MEMORY}_
elif [ ! -z ${STREAM_NUM} ]; then
	seq 1 ${STREAM_NUM} | \
		xargs -I{} -P${STREAM_NUM} sudo docker exec ${CONTAINER_NAME} ${SCRIPT_PATH}do_throughput.sh runc _parallel_{}
else	
	sudo docker exec ${CONTAINER_NAME} ${SCRIPT_PATH}do_throughput.sh runc _default_
fi
