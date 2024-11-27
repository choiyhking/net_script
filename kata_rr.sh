#!/bin/bash


source ./rr_common_vars.sh
CONTAINER_NAME="net_kata"
IMAGE_NAME="net_ubuntu"

RESULT_DIR="net_result/kata/basic/"
RESULT_FILE_PREFIX="${RESULT_DIR}res_rr"
KATA_CONFIG_PATH="/opt/kata/share/defaults/kata-containers/configuration.toml"


# Functions
update_resource_config() {
	local CPU=${1}
	local MEMORY=$(convert_to_mb ${2})

	sudo sed -i "s/^default_vcpus = [0-9]\+/default_vcpus = ${CPU}/" "${KATA_CONFIG_PATH}"
	sudo sed -i "s/^default_memory = [0-9]\+/default_memory = ${MEMORY}/" "${KATA_CONFIG_PATH}"

	sudo systemctl restart containerd.service > /dev/null
	
	echo -e "\tResource configuration updated."
}

convert_to_mb() {
    local input=${1}
    local result

	# e.g., 1G -> 1024
    if [[ "${input}" =~ ^([0-9]+)G$ ]]; then
        result=$(( ${BASH_REMATCH[1]} * 1024 ))
	# e.g., 512m -> 512
    elif [[ "${input}" =~ ^([0-9]+)m$ ]]; then
        result=${BASH_REMATCH[1]}
    else
        result=${input}
    fi

    echo "${result}"
}


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
sudo rm ${RESULT_DIR}*rr* > /dev/null 2>&1

# (CPU, Memory)
update_resource_config "1" "4G"
	
sudo docker run -d -q --name ${CONTAINER_NAME} \
	--runtime=io.containerd.kata.v2 \
	${IMAGE_NAME}
echo "Container[kata] is running."

sudo docker exec ${CONTAINER_NAME} mkdir -p ${RESULT_DIR} > /dev/null 

echo "TCP_RR: Start experiments..."
for i in ${!REQUEST_SIZES[@]}; do
    REQ_SIZE=${REQUEST_SIZES[$i]}
    RESP_SIZE=${RESPONSE_SIZES[$i]}

	RESULT_FILE="${RESULT_FILE_PREFIX}_${REQ_SIZE},${RESP_SIZE}"
	sudo docker exec ${CONTAINER_NAME} sh -c "echo '${HEADER}' | tee ${RESULT_FILE} > /dev/null"

	for i in $(seq 1 ${REPEAT})
	do
		echo -e "\tRepeat #${i}..."
		sudo docker exec ${CONTAINER_NAME} \
			sh -c "netperf -H ${SERVER_IP} -t TCP_RR -l ${TIME} -- -r ${REQ_SIZE},${RESP_SIZE} \
            -o throughput,min_latency,max_latency,mean_latency,stddev_latency \
            | tail -n 1 >> ${RESULT_FILE}"
		sleep 3
	done

	echo -e "\tRequest,Response(${REQ_SIZE}B, ${RESP_SIZE}B) finished."
done

echo "Copy all results from Kata Container to host."
sudo docker ps -q --filter "name=${CONTAINER_NAME}" | \
	xargs -I {} sudo docker cp {}:"/root/net_script/net_result/kata/basic" "net_result/kata"

echo "Stop and Remove containers."
# xargs -r: if there is no argument, do not run commands
sudo docker ps -a -q --filter "name=${CONTAINER_NAME}" | xargs -r sudo docker stop > /dev/null 2>&1
sudo docker ps -a -q --filter "name=${CONTAINER_NAME}" | xargs -r sudo docker rm > /dev/null 2>&1

echo "All experiments are completed !!"