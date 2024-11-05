#!/bin/bash


CONTAINER_NAME="net_runc"
IMAGE_NAME="net_ubuntu" # Ubuntu 22.04 with pre-installed netperf
M_SIZES=(32 64 128 256 512 1024)
SERVER_IP="192.168.51.232"
TIME=20 # test time (sec)

RESULT_DIR="net_result/runc/throughput/"
RESULT_FILE_PREFIX="${RESULT_DIR}res_throughput"
MOUNT_PATH="$HOME/net_script/net_result:/root/net_script/net_result"
PARENT_PID=""

do_pidstat() {
	sudo sh -c "sleep 1; pidstat -p \$(pgrep [n]etperf) 1 >> ${RESULT_FILE}_pidstat 2> /dev/null" &
	PARENT_PID=$!
 	echo "pidstat success !!"
}

terminate_process() {
    local PARENT_PID=${1}

    if ps -p "${PARENT_PID}" > /dev/null; then
        kill "${PARENT_PID}"
        echo "Process ${PARENT_PID} terminated."
    else
        echo "No process found. (Already terminated)"
    fi
    
    sleep 3
}

result_parsing() {
	local RESULT_FILE=${1}
 	local HEADER="%usr %system %guest %wait %CPU CPU Command"
	
	echo ${HEADER} > temp
 	sed -i "/^${HEADER}/c\\" "${INPUT_FILE}"
	sudo sh -c "tail -n +4 ${RESULT_FILE} \
		| awk '{print \$1, \$5, \$6, \$7, \$8, \$9, \$10, \$11}' \
		>> temp && mv temp ${RESULT_FILE}"
}

do_netperf() {
	local RESULT_FILE=${1}
	local HEADER="Recv Socket Size(B) Send Socket Size(B) Send Message Size(B) Elapsed Time(s) Throughput(10^6bps)"
	local EXP=$(echo "${RESULT_FILE}" | awk -F'_' '{print $3}') # e.g., mem
	local M_SIZE=$(echo "${RESULT_FILE}" | awk -F'_' '{print $NF}' | sed 's/\.txt//') # e.g., 256

	if [ ! -s "${RESULT_FILE}" ]; then # if it's first time
        	sudo sh -c "echo ${HEADER} > ${RESULT_FILE}"
	 	echo "header success !!"
    	fi	
  
  	if [[ "${EXP}" == stream* || "${EXP}" == concurrency* ]]; then
    		sudo sh -c "docker exec ${CONTAINER_NAME} netperf -H ${SERVER_IP} -l ${TIME} | tail -n 1 >> ${RESULT_FILE}"

	else
        	sudo docker exec ${CONTAINER_NAME} netperf -H ${SERVER_IP} -l ${TIME} -- -m ${M_SIZE} | sudo tail -n 1 >> ${RESULT_FILE}
	fi

 	echo "netperf success !!"
}


sudo mkdir -p ${RESULT_DIR}

echo "Building a new image..."
sudo docker rmi ${IMAGE_NAME}
sudo docker build --build-arg CACHE_BUST=$(date +%s) -t ${IMAGE_NAME} . 


# options
while getopts ":r:c:m:s:n:" opt; do
  case $opt in
    r) REPEAT=${OPTARG} ;; 
    c) CPU=${OPTARG} ;;
    m) MEMORY=${OPTARG} ;;
    s) STREAM_NUM=${OPTARG} ;;
    n) INSTANCE_NUM=${OPTARG} ;;
    \?) echo "Invalid option -${OPTARG}" >&2; exit 1 ;;
    :) echo "Option -${OPTARG} requires an argument." >&2; exit 1 ;;
  esac
done

# REPEAT option must be specified
if [ -z "$REPEAT" ]; then
  echo "Error: -r (repeat) option is required." >&2
  exit 1
fi



# ./do_throughput.sh <result file name> <repeat #>

echo "Run container and Start experiments..."
if [ ! -z ${CPU} ]; then
	sudo rm ${RESULT_DIR}/*cpu_${CPU}* > /dev/null 2>&1

	sudo docker run -d --name ${CONTAINER_NAME} \
		-v "${MOUNT_PATH}" \
		--cpus=${CPU} \
		${IMAGE_NAME} > /dev/null 2>&1
    
	for M_SIZE in ${M_SIZES[@]}
	do
		RESULT_FILE=${RESULT_FILE_PREFIX}_cpu_${CPU}_${M_SIZE}
  		do_pidstat
		sudo docker exec ${CONTAINER_NAME} ./do_throughput.sh ${RESULT_FILE} ${REPEAT}
  		result_parsing "${RESULT_FILE}_pidstat"
		terminate_process "${PARENT_PID}"
	done
	
elif [ ! -z ${MEMORY} ]; then
	sudo rm ${RESULT_DIR}*mem_${MEMORY}* > /dev/null 2>&1
	
	sudo docker run -d --name ${CONTAINER_NAME} \
		-v "${MOUNT_PATH}" \
		--memory=${MEMORY} \
		--memory-swap=${MEMORY} \
		${IMAGE_NAME} > /dev/null 2>&1
    
	for M_SIZE in ${M_SIZES[@]}
	do
		RESULT_FILE=${RESULT_FILE_PREFIX}_mem_${MEMORY}_${M_SIZE}
  		do_pidstat
		sudo docker exec ${CONTAINER_NAME} ./do_throughput.sh ${RESULT_FILE} ${REPEAT}
  		result_parsing "${RESULT_FILE}_pidstat"
		terminate_process "${PARENT_PID}"
	done

elif [ ! -z ${STREAM_NUM} ]; then
	sudo rm ${RESULT_DIR}/*stream* > /dev/null 2>&1
	
	sudo docker run -d --name ${CONTAINER_NAME} -v "${MOUNT_PATH}" \
		--cpus=4 \
		--memory=2G \
		--memory-swap=2G \
		${IMAGE_NAME} > /dev/null 2>&1

	RESULT_FILE=${RESULT_FILE_PREFIX}_stream${STREAM_NUM}
	for i in $(seq 1 ${REPEAT})
	do
		seq 1 ${STREAM_NUM} | \
			xargs -I{} -P${STREAM_NUM} sudo docker exec ${CONTAINER_NAME} ./do_throughput.sh ${RESULT_FILE}_{}
	done

elif [ ! -z ${INSTANCE_NUM} ]; then
	sudo rm ${RESULT_DIR}*concurrency* > /dev/null 2>&1
	
	for i in $(seq 1 ${INSTANCE_NUM})
	do
		NEW_CONTAINER_NAME=${CONTAINER_NAME}_${i}
		sudo docker run -d --name ${NEW_CONTAINER_NAME} -v "${MOUNT_PATH}" \
		--cpus=1 \
		--memory=512m \
		--memory-swap=512m \
		${IMAGE_NAME} > /dev/null 2>&1
	done

	for i in $(seq 1 ${REPEAT})
	do
		RESULT_FILE=${RESULT_FILE_PREFIX}_concurrency${INSTANCE_NAME}
		sudo docker ps -q --filter "name=${CONTAINER_NAME}_" | \
			xargs -I {} -P${INSTANCE_NUM} sudo docker exec {} ./do_throughput.sh ${RESULT_FILE}_{}
	done
	
else	
	sudo rm ${RESULT_DIR}*default* > /dev/null 2>&1

	sudo docker run -d --name ${CONTAINER_NAME} -v "${MOUNT_PATH}" \
		--cpus=1 \
		--memory=512m \
		--memory-swap=512m \
		${IMAGE_NAME} > /dev/null 2>&1
	
	for M_SIZE in ${M_SIZES[@]}
	do
	    	RESULT_FILE="${RESULT_FILE_PREFIX}_default_${M_SIZE}"
      		for i in $(seq 1 ${REPEAT})
		do
  			do_pidstat
     			do_netperf "${RESULT_FILE}"
  			result_parsing "${RESULT_FILE}_pidstat"
    		done 
	done
fi

echo "Stop and Remove containers..."
sudo docker ps -a -q --filter "name=${CONTAINER_NAME}" | xargs -r sudo docker stop > /dev/null 2>&1
sudo docker ps -a -q --filter "name=${CONTAINER_NAME}" | xargs -r sudo docker rm > /dev/null 2>&1

echo "Experiments are completed !!"
