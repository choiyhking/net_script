#!/bin/bash


SERVER_IP="192.168.51.232"
M_SIZES=(32 64 128 256 512 1024) # array
TIME="20" # netperf test time (sec)


RESULT_DIR="net_result/fc/throughput/"
RESULT_FILE_PREFIX="${RESULT_DIR}res_throughput"
FC_WORKING_DIR="/root/net_script/"
FC_CONFIG_FILE="fc_config.json"
HEADER="Recv_Socket_Size(B) Send_Socket_Size(B) Send_Message_Size(B) Elapsed_Time(s) Throughput(10^6bps)"


# Functions
do_pidstat() {
	local RESULT_FILE=${1}
	(sleep 1; pidstat -p $(pgrep [q]emu) 1 2> /dev/null | sudo tee -a "${RESULT_FILE}_pidstat" > /dev/null) &
}

update_resource_config() {
	local CPU=${1}
	local MEMORY=$(convert_to_mb ${2})

	sudo sed -i 's/"vcpu_count": [0-9]\+/"vcpu_count": '"${CPU}"'/' "${FC_CONFIG_FILE}"
	sudo sed -i 's/"mem_size_mib": [0-9]\+/"mem_size_mib": '"${MEMORY}"'/' "${FC_CONFIG_FILE}"
	
	echo "Resource configuration updated."
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

#echo "Remove existing containers..."
# -f: force
# -q: quiet
#sudo docker rm -f $(sudo docker ps -aq) 2> /dev/null

#echo "Building a new image..."
#sudo docker rmi ${IMAGE_NAME} > /dev/null 2>&1
#sudo docker build -q --build-arg CACHE_BUST=$(date +%s) -t ${IMAGE_NAME} .


# Get options
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


# "REPEAT" option must be specified
# -z: check NULL -> return true
if [ -z "$REPEAT" ]; then
  echo "Error: -r (repeat) option is required." >&2
  exit 1
fi


#####################
# Start Experiments #
#####################
echo "Start experiments..."
# Modify <CPU> option
if [ ! -z ${CPU} ]; then
	sudo rm ${RESULT_DIR}/*cpu_${CPU}* > /dev/null 2>&1

	update_resource_config "${CPU}" "4G"

	sudo docker run -d -q --name ${CONTAINER_NAME} \
		--runtime=io.containerd.kata.v2 \
		${IMAGE_NAME}
	echo "Container[kata] is running."

	sudo docker exec ${CONTAINER_NAME} mkdir -p ${RESULT_DIR} > /dev/null

	for M_SIZE in ${M_SIZES[@]}
	do
		RESULT_FILE=${RESULT_FILE_PREFIX}_cpu_${CPU}_${M_SIZE}
		sudo docker exec ${CONTAINER_NAME} sh -c "echo '${HEADER}' | tee ${RESULT_FILE} > /dev/null"

		for i in $(seq 1 ${REPEAT})
		do
			echo "Repeat #${i}..."
			do_pidstat ${RESULT_FILE}
			sudo docker exec ${CONTAINER_NAME} \
                sh -c "netperf -H ${SERVER_IP} -l ${TIME} -- -m ${M_SIZE} | tail -n 1 >> ${RESULT_FILE}"

			kill $(pgrep [p]idstat) > /dev/null
			sleep 3
		done

		echo "Message size[${M_SIZE}B] finished."
	done

# Modify <Memory> option
elif [ ! -z ${MEMORY} ]; then
	sudo rm ${RESULT_DIR}*mem_${MEMORY}* > /dev/null 2>&1
	
	update_resource_config "4" "${MEMORY}"

	sudo docker run -d -q --name ${CONTAINER_NAME} \
		--runtime=io.containerd.kata.v2 \
		${IMAGE_NAME}
	echo "Container[kata] is running"
	
	sudo docker exec ${CONTAINER_NAME} mkdir -p ${RESULT_DIR} > /dev/null
	
	for M_SIZE in ${M_SIZES[@]}
	do
		RESULT_FILE=${RESULT_FILE_PREFIX}_mem_${MEMORY}_${M_SIZE}
		sudo docker exec ${CONTAINER_NAME} sh -c "echo '${HEADER}' | tee ${RESULT_FILE} > /dev/null"
		
		for i in $(seq 1 ${REPEAT})
        do
			echo "Repeat #${i}..."
			do_pidstat ${RESULT_FILE}
			sudo docker exec ${CONTAINER_NAME} \
                sh -c "netperf -H ${SERVER_IP} -l ${TIME} -- -m ${M_SIZE} | tail -n 1 >> ${RESULT_FILE}"

			kill $(pgrep [p]idstat) > /dev/null
            sleep 3
		done

		echo "Message size[${M_SIZE}B] finished."
	done

# Modify <STREAM_NUM> option
elif [ ! -z ${STREAM_NUM} ]; then
	sudo rm ${RESULT_DIR}/*stream${STREAM_NUM}* > /dev/null 2>&1
	
	update_resource_config "4" "4G"

	sudo docker run -d --name ${CONTAINER_NAME} \
		--runtime=io.containerd.kata.v2 \
		${IMAGE_NAME}
	echo "Container[kata] is running."

	RESULT_FILE=${RESULT_FILE_PREFIX}_stream${STREAM_NUM}
	sudo docker exec ${CONTAINER_NAME} mkdir -p ${RESULT_DIR} > /dev/null
	
	for i in $(seq 1 ${REPEAT} )
	do
		echo "Repeat ${i}..."
		seq 1 ${STREAM_NUM} | \
		    xargs -I{} -P${STREAM_NUM} sudo docker exec ${CONTAINER_NAME} sh -c '
				if [ ! -s '"${RESULT_FILE}"'_{} ]; then
					echo '"${HEADER}"' | tee '"${RESULT_FILE}"'_{} > /dev/null
				fi
			netperf -H '"${SERVER_IP}"' -l '"${TIME}"' | tail -n 1 >> '"${RESULT_FILE}"'_{}'
		sleep 3
	done

# Modify <INSTANCE_NUM> option
elif [ ! -z ${INSTANCE_NUM} ]; then
	sudo rm ${RESULT_DIR}*concurrency${INSTANCE_NUM}* > /dev/null 2>&1

	update_resource_config "1" "512m"
	
	for i in $(seq 1 ${INSTANCE_NUM})
	do
		NEW_CONTAINER_NAME=${CONTAINER_NAME}_${i} # e.g., net_runc_2
		sudo docker run -d -q --name ${NEW_CONTAINER_NAME} \
			--runtime=io.containerd.kata.v2 \
			${IMAGE_NAME}
		sudo docker exec ${NEW_CONTAINER_NAME} mkdir -p ${RESULT_DIR} > /dev/null
	done
	echo "Containers[kata] are running."

	RESULT_FILE=${RESULT_FILE_PREFIX}_concurrency${INSTANCE_NUM}

	for i in $(seq 1 ${REPEAT})
	do
		echo "Repeat ${i}..."
		sudo docker ps -q --filter name=${CONTAINER_NAME} | \
			xargs -I {} -P${INSTANCE_NUM} sudo docker exec {} sh -c '
				if [ ! -s '"${RESULT_FILE}"'_{} ]; then
					echo '"${HEADER}"' | tee '"${RESULT_FILE}"'_{} > /dev/null
				fi
			netperf -H '"${SERVER_IP}"' -l '"${TIME}"' | tail -n 1 >> '"${RESULT_FILE}"'_{}'
		sleep 3
	done

# <DEFAULT> option
else	
	sudo rm ${RESULT_DIR}*default* > /dev/null 2>&1

	# (CPU, Memory)
	update_resource_config "1" "2048"
		
#./fc_run.sh > /dev/null &
	sleep 2
	echo "MicroVm[firecracker] is running."

	ssh -i ubuntu-22.04.id_rsa root@172.16.0.2 "cd ${FC_WORKING_DIR} && rm ${RESULT_DIR}*default* > /dev/null 2>&1 && mkdir -p ${RESULT_DIR}" 2> /dev/null
	# 여기도 지우는거 넣어야	


	for M_SIZE in ${M_SIZES[@]}
	do
	    RESULT_FILE="${RESULT_FILE_PREFIX}_default_${M_SIZE}"
		ssh -i ubuntu-22.04.id_rsa root@172.16.0.2 "cd ${FC_WORKING_DIR} && echo '${HEADER}' | tee ${RESULT_FILE} > /dev/null" 2> /dev/null

		for i in $(seq 1 ${REPEAT})
		do
			echo "Repeat #${i}..."
			#do_pidstat ${RESULT_FILE}
			ssh -i ubuntu-22.04.id_rsa root@172.16.0.2 "cd ${FC_WORKING_DIR} && netperf -H ${SERVER_IP} -l ${TIME} -- -m ${M_SIZE} | tail -n 1 >> ${RESULT_FILE}" 2> /dev/null

			#kill $(pgrep [p]idstat) > /dev/null
			sleep 3
		done

		echo "Message size[${M_SIZE}B] finished."
	done
fi

# Copy all result files from Kata Container to host
sudo docker ps -q --filter "name=${CONTAINER_NAME}" | \
	xargs -I {} sudo docker cp {}:"/root/net_script/net_result/kata/throughput" "net_result/kata"

echo "Stop and Remove containers..."
# xargs -r: if there is no argument, do not run commands
sudo docker ps -a -q --filter "name=${CONTAINER_NAME}" | xargs -r sudo docker stop > /dev/null 2>&1
sudo docker ps -a -q --filter "name=${CONTAINER_NAME}" | xargs -r sudo docker rm > /dev/null 2>&1

echo "All experiments are completed !!"
