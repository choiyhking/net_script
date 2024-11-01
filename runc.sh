#!/bin/bash

CONTAINER_NAME="runc"
IMAGE_NAME="net_ubuntu"
REPEAT=3

sudo docker build --no-cache -q -t ${IMAGE_NAME} .


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

if [ ! -z ${CPU} ]; then
	sudo docker run -d --name ${CONTAINER_NAME} \
		-v "$HOME/net_result:/root/net_result" \
		--cpus=${CPU} \
		${IMAGE_NAME}
	sudo docker exec ${CONTAINER_NAME} /root/net_script/do_throughput.sh runc _cpu_${CPU}_
	sudo docker stop ${CONTAINER_NAME}
	sudo docker rm ${CONTAINER_NAME}
	
elif [ ! -z ${MEMORY} ]; then
	sudo docker run -d --name ${CONTAINER_NAME} \
		-v "$HOME/net_result:/root/net_result" \
		--memory=${MEMORY} \
		--memory-swap=${MEMORY} \
		${IMAGE_NAME}
	sudo docker exec ${CONTAINER_NAME} /root/net_script/do_throughput.sh runc _mem_${MEMORY}_
	sudo docker stop ${CONTAINER_NAME}
	sudo docker rm ${CONTAINER_NAME}

elif [ ! -z ${STREAM_NUM} ]; then
	sudo rm $HOME/net_result/runc/throughput/*stream*
	sudo docker run -d --name ${CONTAINER_NAME} -v "$HOME/net_result:/root/net_result" ${IMAGE_NAME}
	for i in $(seq 1 ${REPEAT})
	do
		seq 1 ${STREAM_NUM} | \
			xargs -I{} -P${STREAM_NUM} sudo docker exec ${CONTAINER_NAME} /root/net_script/do_throughput.sh runc _stream${STREAM_NUM}_{}
	done
	sudo docker ps -q --filter "name=${CONTAINER_NAME}" | xargs -r sudo docker stop
	sudo docker ps -q --filter "name=${CONTAINER_NAME}" | xargs -r sudo docker rm

elif [ ! -z ${INSTANCE_NUM} ]; then
	sudo rm $HOME/net_result/runc/throughput/*concurrency*
	for i in $(seq 1 ${INSTANCE_NUM})
	do
		NEW_CONTAINER_NAME=${CONTAINER_NAME}_${i}
		sudo docker run -d --name ${CONTAINER_NAME} -v "$HOME/net_result:/root/net_result" ${IMAGE_NAME}
	done
	for i in $(seq 1 ${REPEAT})
	do
		sudo docker ps -q --filter "name=${CONTAINER_NAME}_" | \
			xargs -I {} sudo docker exec -d {} /root/net_script/do_throughput.sh runc _concurrency${INSTANCE_NUM}_{}
	done
	sudo docker ps -q --filter "name=${CONTAINER_NAME}_" | xargs -r sudo docker stop
	sudo docker ps -q --filter "name=${CONTAINER_NAME}_" | xargs -r sudo docker rm

else	
	sudo docker run -d --name ${CONTAINER_NAME} -v "$HOME/net_result:/root/net_result" ${IMAGE_NAME}
	sudo docker exec ${CONTAINER_NAME} /root/net_script/do_throughput.sh runc _default_
	sudo docker stop ${CONTAINER_NAME}
	sudo docker rm ${CONTAINER_NAME}
fi
