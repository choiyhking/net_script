#!/bin/bash



source ./tx_common_vars.sh
PRIVATE_KEY="fc_resource/ubuntu-22.04.id_rsa"
SSH_OPTIONS="-o StrictHostKeyChecking=no -i ${PRIVATE_KEY} root@"

RESULT_DIR="net_result/fc/basic/"
RESULT_FILE_PREFIX="${RESULT_DIR}res_tx"
FC_WORKING_DIR="/root/net_script/"


# Functions
# process: firecracker
do_pidstat() {
	local RESULT_FILE=${1}
	(sleep 1; pidstat -p $(pgrep [f]irecracker) 1 2> /dev/null | sudo tee -a "${RESULT_FILE}_pidstat" > /dev/null) &
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

echo "Remove existing Firecracker resources."
fc_resource/fc_clean.sh

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
# Modify <CPU> option
if [ ! -z ${CPU} ]; then
	sudo rm ${RESULT_DIR}/*cpu_${CPU}* > /dev/null 2>&1


	fc_resource/fc_run.sh -c ${CPU} -m 4096 -n 1
    echo "Firecracker microVM is running."

	VM_IP=$(awk '/Guest IP/ {print $3}' fc_resource/fc_info_list)
	
	echo "Start experiments..."
	for M_SIZE in ${M_SIZES[@]}
	do
		RESULT_FILE=${RESULT_FILE_PREFIX}_cpu_${CPU}_${M_SIZE}
		ssh ${SSH_OPTIONS}${VM_IP} "cd ${FC_WORKING_DIR} && echo '${HEADER}' | tee ${RESULT_FILE} > /dev/null" 2> /dev/null

		for i in $(seq 1 ${REPEAT})
		do
			echo -e "\tRepeat #${i}..."
			do_pidstat ${RESULT_FILE}
            ssh ${SSH_OPTIONS}${VM_IP} "
				cd ${FC_WORKING_DIR} && 
				netperf -H ${SERVER_IP} -l ${TIME} -- -m ${M_SIZE} | tail -n 1 >> ${RESULT_FILE} &
				wait" 2> /dev/null

			kill $(pgrep [p]idstat) > /dev/null
			sleep 3
		done

		echo -e "\tMessage size[${M_SIZE}B] finished."
	done

# Modify <Memory> option
elif [ ! -z ${MEMORY} ]; then
	sudo rm ${RESULT_DIR}*mem_${MEMORY}* > /dev/null 2>&1

	
	fc_resource/fc_run.sh -c 4 -m $(convert_to_mb ${MEMORY}) -n 1
    echo "Firecracker microVM is running."
	
	VM_IP=$(awk '/Guest IP/ {print $3}' fc_resource/fc_info_list)
	
	echo "Start experiments..."
	for M_SIZE in ${M_SIZES[@]}
	do
		RESULT_FILE=${RESULT_FILE_PREFIX}_mem_${MEMORY}_${M_SIZE}
		ssh ${SSH_OPTIONS}${VM_IP} "cd ${FC_WORKING_DIR} && echo '${HEADER}' | tee ${RESULT_FILE} > /dev/null" 2> /dev/null

		for i in $(seq 1 ${REPEAT})
        do
			echo -e "\tRepeat #${i}..."
			do_pidstat ${RESULT_FILE}
            ssh ${SSH_OPTIONS}${VM_IP} "
				cd ${FC_WORKING_DIR} && 
				netperf -H ${SERVER_IP} -l ${TIME} -- -m ${M_SIZE} | tail -n 1 >> ${RESULT_FILE} &
				wiat" 2> /dev/null

			kill $(pgrep [p]idstat) > /dev/null
            sleep 3
		done

		echo -e "\tMessage size[${M_SIZE}B] finished."
	done

# Modify <STREAM_NUM> option
elif [ ! -z ${STREAM_NUM} ]; then
	sudo rm ${RESULT_DIR}/*stream${STREAM_NUM}* > /dev/null 2>&1
	
	fc_resource/fc_run.sh -c 4 -m 4096 -n 1
    echo "Firecracker microVM is running."

	VM_IP=$(awk '/Guest IP/ {print $3}' fc_resource/fc_info_list)

	RESULT_FILE=${RESULT_FILE_PREFIX}_stream${STREAM_NUM}

	echo "Start experiments..."
	for i in $(seq 1 ${REPEAT})
	do
		echo -e "\tRepeat ${i}..."
		seq 1 ${STREAM_NUM} | \
		    xargs -I{} -P${STREAM_NUM} ssh ${SSH_OPTIONS}${VM_IP} "
				cd '"${FC_WORKING_DIR}"'
				[ ! -s '"${RESULT_FILE}"'_{} ] && echo '"${HEADER}"' | tee '"${RESULT_FILE}"'_{} > /dev/null
                netperf -H '"${SERVER_IP}"' -l '"${TIME}"' | tail -n 1 >> '"${RESULT_FILE}"'_{} &
				wait
                " > /dev/null 2>&1
		sleep 3
	done

# Modify <INSTANCE_NUM> option
elif [ ! -z ${INSTANCE_NUM} ]; then
	sudo rm ${RESULT_DIR}*concurrency${INSTANCE_NUM}* > /dev/null 2>&1

	fc_resource/fc_run.sh -c 1 -m 512 -n ${INSTANCE_NUM}
    echo "Firecracker microVMs are running."

	RESULT_FILE=${RESULT_FILE_PREFIX}_concurrency${INSTANCE_NUM}
	
	echo "Start experiments..."
	for i in $(seq 1 ${REPEAT})
	do
		echo -e "\tRepeat ${i}..."
		awk '/Guest IP/ {print $3}' fc_resource/fc_info_list | \
			xargs -I {} -P${INSTANCE_NUM} ssh ${SSH_OPTIONS}{} "
				cd '"${FC_WORKING_DIR}"'
				[ ! -s '"${RESULT_FILE}"'_"VM"{} ] && echo '"${HEADER}"' | tee '"${RESULT_FILE}"'_"VM"{} > /dev/null
				netperf -H '"${SERVER_IP}"' -l '"${TIME}"' | tail -n 1 >> '"${RESULT_FILE}"'_"VM"{} &
				wait" > /dev/null 2>&1
		sleep 3
	done

# <DEFAULT> option
else	
	sudo rm ${RESULT_DIR}*default* > /dev/null 2>&1
	
	fc_resource/fc_run.sh -c 1 -m 4096 -n 1
	echo "Firecracker microVM is running."
	VM_IP=$(awk '/Guest IP/ {print $3}' fc_resource/fc_info_list)
	
	echo "Start experiments..."
	for M_SIZE in ${M_SIZES[@]}
	do
	    RESULT_FILE="${RESULT_FILE_PREFIX}_default_${M_SIZE}"
		ssh ${SSH_OPTIONS}${VM_IP} "cd ${FC_WORKING_DIR} && echo '${HEADER}' | tee ${RESULT_FILE} > /dev/null" 2> /dev/null

		for i in $(seq 1 ${REPEAT})
		do
			echo -e "\tRepeat ${i}..."
			do_pidstat ${RESULT_FILE}
			ssh ${SSH_OPTIONS}${VM_IP} "
				cd ${FC_WORKING_DIR} && 
				netperf -H ${SERVER_IP} -l ${TIME} -- -m ${M_SIZE} | tail -n 1 >> ${RESULT_FILE} &
				wait" > /dev/null 2>&1
			kill $(pgrep [p]idstat) > /dev/null
			sleep 3
		done

		echo -e "\tMessage size[${M_SIZE}B] finished."
	done
fi

echo "Copy results from Firecracker microVM to host."
awk '/Guest IP/ {print $3}' fc_resource/fc_info_list | \
		xargs -I {} sudo scp -q -r ${SSH_OPTIONS}{}:${FC_WORKING_DIR}${RESULT_DIR} net_result/fc/

echo "Remove existing Firecracker resources."
fc_resource/fc_clean.sh

echo "All experiments are completed !!"