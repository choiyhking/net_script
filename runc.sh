#!/bin/bash

CONTAINER_NAME="runc"
IMAGE_NAME="net_ubuntu"
#RESULT_DIR="$HOME/net_result/runc/throughput"

# 옵션 파싱
# : 유효하지 않은 옵션이 주어졌을때 오류 메시지 출력
# c: 해당 옵션이 인자를 필요로 한다는 의미
while getopts ":c:m:s:n:" opt; do
  case $opt in
    c) CPU=${OPTARG} ;;
    m) MEMORY=${OPTARG} ;;
	s) STREAM_NUM=${OPTARG} ;;
	n) INSTANCE_NUM=${OPTARG} ;;
    \?) echo "Invalid option -${OPTARG}" >&2; exit 1 ;;
    :) echo "Option -${OPTARG} requires an argument." >&2; exit 1 ;;
  esac
done

#mkdir -p ${RESULT_DIR} 2>/dev/null

sudo docker start ${CONTAINER_NAME} 2>/dev/null


if [ ! -z ${CPU} ]; then
	sudo docker update --cpus=${CPU} ${CONTAINER_NAME} 2>/dev/null
	sudo docker exec ${CONTAINER_NAME} /root/net_script/do_throughput.sh runc _cpu_${CPU}_
elif [ ! -z ${MEMORY} ]; then
	sudo docker update --memory=${MEMORY} --memory-swap=${MEMORY} ${CONTAINER_NAME} 2>/dev/null
	sudo docker exec ${CONTAINER_NAME} /root/net_script/do_throughput.sh runc _mem_${MEMORY}_
elif [ ! -z ${STREAM_NUM} ]; then
	# 굳이 컨테이너에서 지울 필요 없네 HOST에서 지우자
	sudo docker exec ${CONTAINER_NAME} rm /root/net_result/throughput/*parallel* 2>/dev/null
	for i in {0..3}
	do
		seq 1 ${STREAM_NUM} | \
			xargs -I{} -P${STREAM_NUM} sudo docker exec ${CONTAINER_NAME} /root/net_script/do_throughput.sh runc _parallel_{}
	done
elif [ ! -z ${INSTANCE_NUM} ]; the
	for i in {0..3}
	do
		NEW_CONTAINER_NAME=${CONTAINER_NAME}_${i}
		sudo docker run -d --name ${NEW_CONTAINER_NAME} -v "$HOME/net_result:/root/net_result" ${IMAGE_NAME}
	done
	sleep 5
	sudo docker ps -q --filter "name=${CONTAINER_NAME}_" | xargs -I {} sudo docker exec -d {} /root/net_script/do_throughput.sh runc _concurrency_{}
	sleep 5
	sudo docker ps -q --filter "name=${CONTAINER_NAME}_" | xargs -r sudo docker stop
else	
	sudo docker exec ${CONTAINER_NAME} /root/net_script/do_throughput.sh runc _default_
fi
