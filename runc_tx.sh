#!/bin/bash


source ./tx_commons.sh
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
sudo docker rm -f $(sudo docker ps -aq) 2> /dev/null 

echo "Building a new image..."
sudo docker rmi ${IMAGE_NAME} > /dev/null 2>&1
sudo docker build -q --build-arg CACHE_BUST=$(date +%s) -t ${IMAGE_NAME} .

get_options $@


#####################
# Start Experiments #
#####################
# Modify <CPU> option
if [ ! -z ${CPU} ]; then
	sudo rm ${RESULT_DIR}/*cpu_${CPU}* > /dev/null 2>&1

	# Set memory with the half size of host physical memory
	sudo docker run -d -q --name ${CONTAINER_NAME} \
		-v ${MOUNT_PATH} \
		--cpus=${CPU} \
		--memory=4G \
		--memory-swap=4G \
		${IMAGE_NAME}
	echo "Container[runc] is running."

	echo "TCP_STREAM: Start experiments..."
	for M_SIZE in ${M_SIZES[@]}
	do
		RESULT_FILE=${RESULT_FILE_PREFIX}_cpu_${CPU}_${M_SIZE}
		echo "${HEADER}" | sudo tee ${RESULT_FILE} > /dev/null

		for i in $(seq 1 ${REPEAT})
		do
			echo -e "\tRepeat #$i..."
			do_pidstat "netperf" ${RESULT_FILE}
			do_perfstat "netperf" ${RESULT_FILE}
			do_mpstat ${RESULT_FILE}
			sudo docker exec ${CONTAINER_NAME} \
                sh -c "netperf -H ${SERVER_IP} -l ${TIME} -- -m ${M_SIZE} | tail -n 1 >> ${RESULT_FILE}"
			kill $(pgrep [m]pstat) > /dev/null
			sleep 3
		done

		echo -e "\tMessage size(${M_SIZE}B) finished."
	done

# Modify <Memory> option
elif [ ! -z ${MEMORY} ]; then
	sudo rm ${RESULT_DIR}*mem_${MEMORY}* > /dev/null 2>&1
	
	sudo docker run -d -q --name ${CONTAINER_NAME} \
		-v ${MOUNT_PATH} \
		--cpus=4 \
		--memory=${MEMORY} \
		--memory-swap=${MEMORY} \
		${IMAGE_NAME}
	echo "Container[runc] is running"
	
	echo "TCP_STREAM: Start experiments..."
	for M_SIZE in ${M_SIZES[@]}
	do
		RESULT_FILE=${RESULT_FILE_PREFIX}_mem_${MEMORY}_${M_SIZE}
		echo "${HEADER}" | sudo tee ${RESULT_FILE} > /dev/null
		
		for i in $(seq 1 ${REPEAT})
        do
			echo -e "\tRepeat #$i..."
			do_pidsdtat "netperf" ${RESULT_FILE}
			do_perfstat "netperf" ${RESULT_FILE}
			do_mpstat ${RESULT_FILE}
			sudo docker exec ${CONTAINER_NAME} \
                sh -c "netperf -H ${SERVER_IP} -l ${TIME} -- -m ${M_SIZE} | tail -n 1 >> ${RESULT_FILE}"
            sleep 3
			kill $(pgrep [m]pstat) > /dev/null
		done

		echo -e "\tMessage size(${M_SIZE}B) finished."
	done

# Modify <STREAM_NUM> option
elif [ ! -z ${STREAM_NUM} ]; then
	sudo rm ${RESULT_DIR}/*stream${STREAM_NUM}* > /dev/null 2>&1
	
	sudo docker run -d -q --name ${CONTAINER_NAME} \
		-v ${MOUNT_PATH} \
		--cpus=4 \
		--memory=4G \
		--memory-swap=4G \
		${IMAGE_NAME}
	echo "Container[runc] is running."

	RESULT_FILE=${RESULT_FILE_PREFIX}_stream${STREAM_NUM}
	
	echo "TCP_STREAM: Start experiments..."
	for i in $(seq 1 ${REPEAT})
	do
		echo -e "\tRepeat #$i..."
		seq 1 ${STREAM_NUM} | \
			xargs -I{} -P${STREAM_NUM} sh -c "
				if [ ! -s ${RESULT_FILE}_{} ]; then
					echo '${HEADER}' | sudo tee ${RESULT_FILE}_{} > /dev/null
				fi
				sudo docker exec ${CONTAINER_NAME} sh -c 'netperf -H ${SERVER_IP} -l ${TIME} | tail -n 1 >> ${RESULT_FILE}_{}'
            "		
		sleep 3
	done

# Modify <INSTANCE_NUM> option
elif [ ! -z ${INSTANCE_NUM} ]; then
	sudo rm ${RESULT_DIR}*concurrency${INSTANCE_NUM}* > /dev/null 2>&1
	
	for i in $(seq 1 ${INSTANCE_NUM})
	do
		NEW_CONTAINER_NAME=${CONTAINER_NAME}_${i} # e.g., net_runc_2
		sudo docker run -d -q --name ${NEW_CONTAINER_NAME} \
			-v ${MOUNT_PATH} \
			--cpus=1 \
			--memory=512m \
			--memory-swap=512m \
			${IMAGE_NAME}
	done
	echo "Containers[runc] are running."

	RESULT_FILE=${RESULT_FILE_PREFIX}_concurrency${INSTANCE_NUM}
	echo "TCP_STREAM: Start experiments..."

	for i in $(seq 1 ${REPEAT})
	do
		echo -e "\tRepeat #$i..."
		sudo docker ps -q --filter "name=${CONTAINER_NAME}_" | \
			xargs -I {} -P${INSTANCE_NUM} sh -c "
				if [ ! -s ${RESULT_FILE}_{} ]; then
					echo '${HEADER}' | sudo tee ${RESULT_FILE}_{} > /dev/null
				fi
				sudo docker exec {} sh -c 'netperf -H ${SERVER_IP} -l ${TIME} | tail -n 1 >> ${RESULT_FILE}_{}'
			"
		sleep 3
	done

# <DEFAULT> option
else	
	sudo rm ${RESULT_DIR}*default* > /dev/null 2>&1

	sudo docker run -d -q --name ${CONTAINER_NAME} \
		-v ${MOUNT_PATH} \
		--cpus=1 \
		--memory=4G \
		--memory-swap=4G \
		${IMAGE_NAME}
	echo "Container[runc] is running."

	echo "TCP_STREAM: Start experiments..."
	for M_SIZE in ${M_SIZES[@]}
	do
	    RESULT_FILE="${RESULT_FILE_PREFIX}_default_${M_SIZE}"
		echo "${HEADER}" | sudo tee ${RESULT_FILE} > /dev/null

		for i in $(seq 1 ${REPEAT})
		do
			echo -e "\tRepeat #$i..."
			do_pidstat "netperf" ${RESULT_FILE}
			do_perfstat "netperf" ${RESULT_FILE}
			do_mpstat ${RESULT_FILE}
			# This doesn't work: docker exec -it my_container "echo a && echo b"
			sudo docker exec ${CONTAINER_NAME} \
				sh -c "netperf -H ${SERVER_IP} -l ${TIME} -- -m ${M_SIZE} | tail -n 1 >> ${RESULT_FILE}"
			kill $(pgrep [m]pstat) > /dev/null
			sleep 3
		done
		echo -e "\tMessage size(${M_SIZE}B) finished."
	done
fi

echo "Stop and Remove containers."
# xargs -r: if there is no argument, do not run commands
sudo docker ps -a -q --filter "name=${CONTAINER_NAME}" | xargs -r sudo docker stop > /dev/null 2>&1
sudo docker ps -a -q --filter "name=${CONTAINER_NAME}" | xargs -r sudo docker rm > /dev/null 2>&1

echo "All experiments are completed !!"
