#!/bin/bash


source ./tx_commons.sh
CONTAINER_NAME="net_kata"
IMAGE_NAME="net_ubuntu"

RESULT_DIR="net_result/kata/basic/"
RESULT_FILE_PREFIX="${RESULT_DIR}res_tx"
KATA_CONFIG_PATH="/opt/kata/share/defaults/kata-containers/configuration.toml"

update_resource_config() {
	local CPU=$1
	local MEMORY=$(convert_to_mb $2)

	sudo sed -i "s/^default_vcpus = [0-9]\+/default_vcpus = ${CPU}/" "${KATA_CONFIG_PATH}"
	sudo sed -i "s/^default_memory = [0-9]\+/default_memory = ${MEMORY}/" "${KATA_CONFIG_PATH}"

	sudo systemctl restart containerd.service > /dev/null
	
	echo "Resource configuration updated."
}

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

	update_resource_config "${CPU}" "4G"

	sudo docker run -d -q --name ${CONTAINER_NAME} \
		--runtime=io.containerd.kata.v2 \
		${IMAGE_NAME}
	echo "Container[kata] is running."

	sudo docker exec ${CONTAINER_NAME} mkdir -p ${RESULT_DIR} > /dev/null

	echo "TCP_STREAM: Start experiments..."
	for M_SIZE in ${M_SIZES[@]}
	do
		RESULT_FILE=${RESULT_FILE_PREFIX}_cpu_${CPU}_${M_SIZE}
		sudo docker exec ${CONTAINER_NAME} sh -c "echo '${HEADER}' | tee ${RESULT_FILE} > /dev/null"

		for i in $(seq 1 ${REPEAT})
		do
			echo -e "\tRepeat #$i..."
			do_pidstat "qemu" ${RESULT_FILE}
			do_perfstat "qemu" ${RESULT_FILE}
			do_mpstat ${RESULT_FILE}
			sudo docker exec ${CONTAINER_NAME} \
                sh -c "netperf -H ${SERVER_IP} -l ${TIME} -- -m ${M_SIZE} | tail -n 1 >> ${RESULT_FILE}"

			kill $(pgrep [p]idstat) > /dev/null
			sudo kill -2 $(pgrep [p]erf) > /dev/null
			kill $(pgrep [m]pstat) > /dev/null
			sleep 3
		done

		echo -e "\tMessage size(${M_SIZE}B) finished."
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

	echo "TCP_STREAM: Start experiments..."
	for M_SIZE in ${M_SIZES[@]}
	do
		RESULT_FILE=${RESULT_FILE_PREFIX}_mem_${MEMORY}_${M_SIZE}
		sudo docker exec ${CONTAINER_NAME} sh -c "echo '${HEADER}' | tee ${RESULT_FILE} > /dev/null"
		
		for i in $(seq 1 ${REPEAT})
        do
			echo -e "\tRepeat #$i..."
			do_pidstat "qemu" ${RESULT_FILE}
			do_perfstat "qemu" ${RESULT_FILE}
			do_mpstat ${RESULT_FILE}
			sudo docker exec ${CONTAINER_NAME} \
                sh -c "netperf -H ${SERVER_IP} -l ${TIME} -- -m ${M_SIZE} | tail -n 1 >> ${RESULT_FILE}"

			kill $(pgrep [p]idstat) > /dev/null
			sudo kill -2 $(pgrep [p]erf) > /dev/null
			kill $(pgrep [m]pstat) > /dev/null
            sleep 3
		done

		echo -e "\tMessage size(${M_SIZE}B) finished."
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

	echo "TCP_STREAM: Start experiments..."
	for i in $(seq 1 ${REPEAT} )
	do
		echo -e "\tRepeat #$i..."
		seq 1 ${STREAM_NUM} | \
		    xargs -I{} -P${STREAM_NUM} sudo docker exec ${CONTAINER_NAME} sh -c '
				if [ ! -s "'"${RESULT_FILE}"'_{}" ]; then
					echo "'"${HEADER}"'" | tee "'"${RESULT_FILE}"'_{}" > /dev/null
				fi
				netperf -H "'"${SERVER_IP}"'" -l "'"${TIME}"'" | tail -n 1 >> "'"${RESULT_FILE}"'_{}"
			'
		sleep 3
	done

# Modify <INSTANCE_NUM> option
elif [ ! -z ${INSTANCE_NUM} ]; then
	sudo rm ${RESULT_DIR}*concurrency${INSTANCE_NUM}* > /dev/null 2>&1

	update_resource_config "1" "512m"
	
	for i in $(seq 1 ${INSTANCE_NUM})
	do
		NEW_CONTAINER_NAME=${CONTAINER_NAME}_${i} # e.g., net_kata_2
		sudo docker run -d -q --name ${NEW_CONTAINER_NAME} \
			--runtime=io.containerd.kata.v2 \
			${IMAGE_NAME}
		sudo docker exec ${NEW_CONTAINER_NAME} mkdir -p ${RESULT_DIR} > /dev/null
	done
	echo "Containers[kata] are running."

	RESULT_FILE=${RESULT_FILE_PREFIX}_concurrency${INSTANCE_NUM}
	
	echo "TCP_STREAM: Start experiments..."
	for i in $(seq 1 ${REPEAT})
	do
		echo -e "\tRepeat #$i..."
		sudo docker ps -q --filter name=${CONTAINER_NAME} | \
			xargs -I {} -P${INSTANCE_NUM} sudo docker exec {} sh -c '
				if [ ! -s "'"${RESULT_FILE}"'_{}" ]; then
					echo "'"${HEADER}"'" | tee "'"${RESULT_FILE}"'_{}" > /dev/null
				fi
				netperf -H "'"${SERVER_IP}"'" -l "'"${TIME}"'" | tail -n 1 >> "'"${RESULT_FILE}"'_{}"
			'
		sleep 3
	done

# <DEFAULT> option
else	
	sudo rm ${RESULT_DIR}*default* > /dev/null 2>&1

	# (CPU, Memory)
	update_resource_config "1" "4G"
		
	sudo docker run -d -q --name ${CONTAINER_NAME} \
		--runtime=io.containerd.kata.v2 \
		${IMAGE_NAME}
	echo "Container[kata] is running."

	sudo docker exec ${CONTAINER_NAME} mkdir -p ${RESULT_DIR} > /dev/null 

	echo "TCP_STREAM: Start experiments..."
	for M_SIZE in ${M_SIZES[@]}
	do
	    RESULT_FILE="${RESULT_FILE_PREFIX}_default_${M_SIZE}"
		sudo docker exec ${CONTAINER_NAME} sh -c "echo '${HEADER}' | tee ${RESULT_FILE} > /dev/null"

		for i in $(seq 1 ${REPEAT})
		do
			echo -e "\tRepeat #$i..."
			do_pidstat "qemu" ${RESULT_FILE}
			do_perfstat "qemu" ${RESULT_FILE}
			do_mpstat ${RESULT_FILE}
			sudo docker exec ${CONTAINER_NAME} \
				sh -c "netperf -H ${SERVER_IP} -l ${TIME} -- -m ${M_SIZE} | tail -n 1 >> ${RESULT_FILE}"

			kill $(pgrep [p]idstat) > /dev/null
			sudo kill -2 $(pgrep [p]erf) > /dev/null
			kill $(pgrep [m]pstat) > /dev/null
			sleep 3
		done

		echo -e "\tMessage size(${M_SIZE}B) finished."
	done
fi

echo "Copy all results from Kata Container to host."
sudo docker ps -q --filter "name=${CONTAINER_NAME}" | \
	xargs -I {} sudo docker cp {}:"/root/net_script/net_result/kata/basic" "net_result/kata"

echo "Stop and Remove containers."
# xargs -r: if there is no argument, do not run commands
sudo docker ps -a -q --filter "name=${CONTAINER_NAME}" | xargs -r sudo docker stop > /dev/null 2>&1
sudo docker ps -a -q --filter "name=${CONTAINER_NAME}" | xargs -r sudo docker rm > /dev/null 2>&1

echo "All experiments are completed !!"
