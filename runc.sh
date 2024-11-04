#!/bin/bash

CONTAINER_NAME="net_runc"
IMAGE_NAME="net_ubuntu" # Ubuntu 22.04 with pre-installed netperf
REPEAT=10

echo "Building a new image..."
sudo docker rmi ${IMAGE_NAME}
#sudo docker build -t ${IMAGE_NAME} .
sudo docker build --build-arg CACHE_BUST=$(date +%s) -t ${IMAGE_NAME} .


# options
# ":" means that there must be values
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

echo "Run container and Start experiments..."
if [ ! -z ${CPU} ]; then
	sudo docker run -d --name ${CONTAINER_NAME} \
		-v "$HOME/net_result:/root/net_result" \
		--cpus=${CPU} \
		${IMAGE_NAME}
	sudo docker exec ${CONTAINER_NAME} /root/net_script/do_throughput.sh runc _cpu_${CPU}_
	
elif [ ! -z ${MEMORY} ]; then
	sudo docker run -d --name ${CONTAINER_NAME} \
		-v "$HOME/net_result:/root/net_result" \
		--memory=${MEMORY} \
		--memory-swap=${MEMORY} \
		${IMAGE_NAME}
	sudo docker exec ${CONTAINER_NAME} /root/net_script/do_throughput.sh runc _mem_${MEMORY}_

elif [ ! -z ${STREAM_NUM} ]; then
	sudo rm $HOME/net_result/runc/throughput/*stream* 2>/dev/null
	
	sudo docker run -d --name ${CONTAINER_NAME} -v "$HOME/net_result:/root/net_result" \
		--cpus=2 \
		--memory=1G \
		--memory-swap=1G \
		${IMAGE_NAME}
	
	for i in $(seq 1 ${REPEAT})
	do
		seq 1 ${STREAM_NUM} | \
			xargs -I{} -P${STREAM_NUM} sudo docker exec ${CONTAINER_NAME} /root/net_script/do_throughput.sh runc _stream${STREAM_NUM}_{}
	done

elif [ ! -z ${INSTANCE_NUM} ]; then
	sudo rm $HOME/net_result/runc/throughput/*concurrency* 2>/dev/null
	
	for i in $(seq 1 ${INSTANCE_NUM})
	do
		NEW_CONTAINER_NAME=${CONTAINER_NAME}_${i}
		sudo docker run -d --name ${NEW_CONTAINER_NAME} -v "$HOME/net_result:/root/net_result" \
		--cpus=1 \
		--memory=512m \
		--memory-swap=512m \
		${IMAGE_NAME}
	done

	for i in $(seq 1 ${REPEAT})
	do
		sudo docker ps -q --filter "name=${CONTAINER_NAME}_" | \
			xargs -I {} -P${INSTANCE_NUM} sudo docker exec -d {} /root/net_script/do_throughput.sh runc _concurrency${INSTANCE_NUM}_{}
	done
	
else	
	# default CPU, Memory(w/ no swap)
	sudo docker run -d --name ${CONTAINER_NAME} -v "$HOME/net_result:/root/net_result" \
		--cpus=1 \
		--memory=512m \
		--memory-swap=512m \
		${IMAGE_NAME}

	sudo docker exec ${CONTAINER_NAME} /root/net_script/do_throughput.sh runc _default_
fi

echo "Stop and Remove containers..."
sudo docker ps -a -q --filter "name=${CONTAINER_NAME}" | xargs -r sudo docker stop
sudo docker ps -a -q --filter "name=${CONTAINER_NAME}" | xargs -r sudo docker rm

echo "Experiments Finished !!"
