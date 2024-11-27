#!/bin/bash


source ./rr_common_vars.sh
CONTAINER_NAME="net_runc"
IMAGE_NAME="net_ubuntu"

RESULT_DIR="net_result/runc/basic/"
RESULT_FILE_PREFIX="${RESULT_DIR}res_tx"
MOUNT_PATH="$HOME/net_script/net_result:/root/net_script/net_result" # host_path : container_path

###############
# Preparation #
###############
sudo mkdir -p ${RESULT_DIR} # pwd: $HOME/net_script/

echo "Remove existing containers."
# -f: force
# -q: quiet
sudo docker rm -f $(sudo docker ps -aq) 2> /dev/null
 
echo "Building a new image..."
sudo docker rmi ${IMAGE_NAME} > /dev/null 2>&1
sudo docker build -q --build-arg CACHE_BUST=$(date +%s) -t ${IMAGE_NAME} .


# Get options
while getopts ":r:" opt; do
  case $opt in
    r) REPEAT=${OPTARG} ;; 
    \?) echo "Invalid option -${OPTARG}" >&2; exit 1 ;;
    :) echo "Option -${OPTARG} requires an argument." >&2; exit 1 ;;
  esac
done

# "REPEAT" option must be specified
# -z: check NULL -> return true
if [ -z "$REPEAT" ]; then
  echo "Error: -r (repeat) option is required." >&2
  exit 1
fi


#####################
# Start Experiments #
#####################
echo "TCP_RR: Start experiments..."
RESULT_FILE_PREFIX="${RESULT_DIR}res_rr"

sudo rm ${RESULT_DIR}*rr* > /dev/null 2>&1

 sudo docker run -d -q --name ${CONTAINER_NAME} \
         -v ${MOUNT_PATH} \
         --cpus=1 \
         --memory=4G \
         --memory-swap=4G \
         ${IMAGE_NAME}
     echo "Container[runc] is running."

for i in ${!REQUEST_SIZES[@]}; do
	REQ_SIZE=${REQUEST_SIZES[$i]}
	RESP_SIZE=${RESPONSE_SIZES[$i]}
	
	RESULT_FILE="${RESULT_FILE_PREFIX}_${REQ_SIZE},${RESP_SIZE}"
	echo "${HEADER}" | sudo tee ${RESULT_FILE} > /dev/null
	
	for i in $(seq 1 ${REPEAT})
	do
		echo -e "\tRepeat #$i..."
		sudo docker exec ${CONTAINER_NAME} \
			sh -c "netperf -H ${SERVER_IP} -t TCP_RR -l ${TIME} -- -r ${REQ_SIZE},${RESP_SIZE} \
			-o throughput,min_latency,max_latency,mean_latency,stddev_latency \
			| tail -n 1 >> ${RESULT_FILE}"
		sleep 3
	done
	echo -e "\tRequest,Response(${REQ_SIZE}B, ${RESP_SIZE}B) finished."
done

echo "Stop and Remove containers."
# xargs -r: if there is no argument, do not run commands
sudo docker ps -a -q --filter "name=${CONTAINER_NAME}" | xargs -r sudo docker stop > /dev/null 2>&1
sudo docker ps -a -q --filter "name=${CONTAINER_NAME}" | xargs -r sudo docker rm > /dev/null 2>&1

echo "All experiments are completed !!"