#!/bin/bash


SERVER_IP="192.168.51.232"
#M_SIZES=(32 64 128 256 512 1024) # array
M_SIZES=(32 64) # array
TIME="20" # netperf test time (sec)
PRIVATE_KEY="fc_resource/ubuntu-22.04.id_rsa"
SSH_OPTIONS="-i ${PRIVATE_KEY} root@"

RESULT_DIR="net_result/fc/throughput/"
RESULT_FILE_PREFIX="${RESULT_DIR}res_throughput"
FC_WORKING_DIR="/root/net_script/"
HEADER="Recv_Socket_Size(B) Send_Socket_Size(B) Send_Message_Size(B) Elapsed_Time(s) Throughput(10^6bps)"


# Functions
do_pidstat() {
	local RESULT_FILE=${1}
	(sleep 1; pidstat -p $(pgrep [f]irecracker) 1 2> /dev/null | sudo tee -a "${RESULT_FILE}_pidstat" > /dev/null) &
}

#update_resource_config() {
#	local CPU=${1}
#	local MEMORY=$(convert_to_mb ${2})
#
#	sudo sed -i 's/"vcpu_count": [0-9]\+/"vcpu_count": '"${CPU}"'/' "${FC_CONFIG_FILE}"
#	sudo sed -i 's/"mem_size_mib": [0-9]\+/"mem_size_mib": '"${MEMORY}"'/' "${FC_CONFIG_FILE}"
#	
#	echo "Resource configuration updated."
#}

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

echo "Remove existing firecracker resources..."
fc_resource/fc_clean.sh

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


	fc_resource/fc_run.sh -c ${CPU} -m 4096 -n 1
    echo "MicroVm[firecracker] is running."

	VM_IP=$(awk '/GUEST IP/ {print $3}' fc_resource/fc_info_list)

	for M_SIZE in ${M_SIZES[@]}
	do
		RESULT_FILE=${RESULT_FILE_PREFIX}_cpu_${CPU}_${M_SIZE}
		ssh ${SSH_OPTIONS}${VM_IP} "cd ${FC_WORKING_DIR} && echo '${HEADER}' | tee ${RESULT_FILE} > /dev/null" 2> /dev/null

		for i in $(seq 1 ${REPEAT})
		do
			echo "Repeat #${i}..."
			do_pidstat ${RESULT_FILE}
            ssh ${SSH_OPTIONS}${VM_IP} "
				cd ${FC_WORKING_DIR} && 
				netperf -H ${SERVER_IP} -l ${TIME} -- -m ${M_SIZE} | tail -n 1 >> ${RESULT_FILE} &
				wait" 2> /dev/null

			kill $(pgrep [p]idstat) > /dev/null
			sleep 3
		done

		echo "Message size[${M_SIZE}B] finished."
	done

# Modify <Memory> option
elif [ ! -z ${MEMORY} ]; then
	sudo rm ${RESULT_DIR}*mem_${MEMORY}* > /dev/null 2>&1
	
	fc_resource/fc_run.sh -c 4 -m ${MEMORY} -n 1
    echo "MicroVm[firecracker] is running."
	
	VM_IP=$(awk '/GUEST IP/ {print $3}' fc_resource/fc_info_list)
	
	for M_SIZE in ${M_SIZES[@]}
	do
		RESULT_FILE=${RESULT_FILE_PREFIX}_mem_${MEMORY}_${M_SIZE}
		ssh ${SSH_OPTIONS}${VM_IP} "cd ${FC_WORKING_DIR} && echo '${HEADER}' | tee ${RESULT_FILE} > /dev/null" 2> /dev/null

		for i in $(seq 1 ${REPEAT})
        do
			echo "Repeat #${i}..."
			do_pidstat ${RESULT_FILE}
            ssh ${SSH_OPTIONS}${VM_IP} "
				cd ${FC_WORKING_DIR} && 
				netperf -H ${SERVER_IP} -l ${TIME} -- -m ${M_SIZE} | tail -n 1 >> ${RESULT_FILE} &
				wiat" 2> /dev/null

			kill $(pgrep [p]idstat) > /dev/null
            sleep 3
		done

		echo "Message size[${M_SIZE}B] finished."
	done

# Modify <STREAM_NUM> option
elif [ ! -z ${STREAM_NUM} ]; then
	sudo rm ${RESULT_DIR}/*stream${STREAM_NUM}* > /dev/null 2>&1
	
	fc_resource/fc_run.sh -c 4 -m 4096 -n 1
    echo "MicroVm[firecracker] is running."

	VM_IP=$(awk '/GUEST IP/ {print $3}' fc_resource/fc_info_list)

	RESULT_FILE=${RESULT_FILE_PREFIX}_stream${STREAM_NUM}
	
	for i in $(seq 1 ${REPEAT})
	do
		echo "Repeat ${i}..."
		seq 1 ${STREAM_NUM} | \
		    xargs -I{} -P${STREAM_NUM} ssh ${SSH_OPTIONS}${VM_IP} sh -c "
				'if [ ! -s \"${RESULT_FILE}\"_{} ]; then
					echo \"${HEADER}\" | tee \"${RESULT_FILE}\"_{} > /dev/null
				fi
			netperf -H ${SERVER_IP} -l "${TIME} | tail -n 1 >> '"${RESULT_FILE}"'_{} &
			wait'"
		sleep 3
	done

# Modify <INSTANCE_NUM> option
elif [ ! -z ${INSTANCE_NUM} ]; then
	sudo rm ${RESULT_DIR}*concurrency${INSTANCE_NUM}* > /dev/null 2>&1

	fc_resource/fc_run.sh -c 1 -m 512 -n ${INSTANCE_NUM}
    echo "MicroVm[firecracker] is running."


	RESULT_FILE=${RESULT_FILE_PREFIX}_concurrency${INSTANCE_NUM}
	for i in $(seq 1 ${REPEAT})
	do
		echo "Repeat ${i}..."
		awk '/GUEST IP/ {print $3}' fc_resource/fc_info_list | \
			xargs -I {} -P${INSTANCE_NUM} ssh ${SSH_OPTIONS}{} sh -c '
				if [ ! -s '"${RESULT_FILE}"'_{} ]; then
					echo '"${HEADER}"' | tee '"${RESULT_FILE}"'_{} > /dev/null
				fi
			netperf -H '"${SERVER_IP}"' -l '"${TIME}"' | tail -n 1 >> '"${RESULT_FILE}"'_{}'
		sleep 3
	done

# <DEFAULT> option
else	
	sudo rm ${RESULT_DIR}*default* > /dev/null 2>&1

		
	fc_resource/fc_run.sh -c 1 -m 512 -n 1
	echo "MicroVm[firecracker] is running."
	
	#VM_IP=$(sed -n "1p" fc_resource/fc_ip_list)
	VM_IP=$(awk '/GUEST IP/ {print $3}' fc_resource/fc_info_list)


	for M_SIZE in ${M_SIZES[@]}
	do
	    RESULT_FILE="${RESULT_FILE_PREFIX}_default_${M_SIZE}"
		ssh ${SSH_OPTIONS}${VM_IP} "cd ${FC_WORKING_DIR} && echo '${HEADER}' | tee ${RESULT_FILE} > /dev/null" 2> /dev/null

		for i in $(seq 1 ${REPEAT})
		do
			echo "Repeat #${i}..."
			do_pidstat ${RESULT_FILE}
#ssh -tt ${SSH_OPTIONS}${VM_IP} "cd ${FC_WORKING_DIR} && netperf -H ${SERVER_IP} -l ${TIME} -- -m ${M_SIZE} | tail -n 1 >> ${RESULT_FILE}" > /dev/null 2>&1
			ssh ${SSH_OPTIONS}${VM_IP} "
				cd ${FC_WORKING_DIR} && 
				netperf -H ${SERVER_IP} -l ${TIME} -- -m ${M_SIZE} | tail -n 1 >> ${RESULT_FILE} &
				wait" > /dev/null 2>&1
			echo "hi"

			kill $(pgrep [p]idstat) > /dev/null
			sleep 3
		done

		echo "Message size[${M_SIZE}B] finished."
	done
fi

# Copy all result files from Firecracker microVM to host
echo "Copy results from Firecracker microVM to host."
sudo scp -q -r ${SSH_OPTIONS}${VM_IP}:${FC_WORKING_DIR}${RESULT_DIR} net_result/fc/



echo "Remove existing firecracker resources..."
#fc_resource/fc_clean.sh

echo "All experiments are completed !!"
