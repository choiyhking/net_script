#!/bin/bash


source ./tx_commons.sh
PRIVATE_KEY="vm_resource/vm.id_rsa"
SSH_OPTIONS="-o StrictHostKeyChecking=no -i ${PRIVATE_KEY} root@"

RESULT_DIR="net_result/vm/basic/"
RESULT_FILE_PREFIX="${RESULT_DIR}res_tx"
VM_WORKING_DIR="/root/net_script/"


###############
# Preparation #
###############
sudo mkdir -p ${RESULT_DIR} # pwd: $HOME/net_script/

get_options $@

#####################
# Start Experiments #
#####################
# Modify <CPU> option
if [ ! -z ${CPU} ]; then
	sudo rm ${RESULT_DIR}/*cpu_${CPU}* > /dev/null 2>&1

	vm_resource/vm_run.sh -c ${CPU} -m 4G -n 1
    echo "VM is running."
	VM_IP=$(cat vm_resource/net-vm-ip-list)
	
	echo "TCP_STREAM: Start experiments..."
	for M_SIZE in ${M_SIZES[@]}
	do
		RESULT_FILE=${RESULT_FILE_PREFIX}_cpu_${CPU}_${M_SIZE}
		ssh ${SSH_OPTIONS}${VM_IP} "cd ${VM_WORKING_DIR} && echo '${HEADER}' | tee ${RESULT_FILE} > /dev/null" 2> /dev/null

		for i in $(seq 1 ${REPEAT})
		do
			echo -e "\tRepeat #$i..."
			do_pidstat "qemu" ${RESULT_FILE}
			do_perfstat "qemu" ${RESULT_FILE}
			do_mpstat ${RESULT_FILE}
            ssh ${SSH_OPTIONS}${VM_IP} "
				cd ${VM_WORKING_DIR} && 
				netperf -H ${SERVER_IP} -l ${TIME} -- -m ${M_SIZE} | tail -n 1 >> ${RESULT_FILE} &
				wait" 2> /dev/null

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

	vm_resource/vm_run.sh -c 4 -m ${MEMORY} -n 1
    echo "VM is running."
	VM_IP=$(cat vm_resource/net-vm-ip-list)
	
	echo "TCP_STREAM: Start experiments..."
	for M_SIZE in ${M_SIZES[@]}
	do
		RESULT_FILE=${RESULT_FILE_PREFIX}_mem_${MEMORY}_${M_SIZE}
		ssh ${SSH_OPTIONS}${VM_IP} "cd ${VM_WORKING_DIR} && echo '${HEADER}' | tee ${RESULT_FILE} > /dev/null" 2> /dev/null

		for i in $(seq 1 ${REPEAT})
        do
			echo -e "\tRepeat #$i..."
			do_pidstat "qemu" ${RESULT_FILE}
			do_perfstat "qemu" ${RESULT_FILE}
			do_mpstat ${RESULT_FILE}
            ssh ${SSH_OPTIONS}${VM_IP} "
				cd ${VM_WORKING_DIR} && 
				netperf -H ${SERVER_IP} -l ${TIME} -- -m ${M_SIZE} | tail -n 1 >> ${RESULT_FILE} &
				wiat" 2> /dev/null

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
	
	vm_resource/vm_run.sh -c 4 -m 4G -n 1
    echo "VM is running."
	VM_IP=$(cat vm_resource/net-vm-ip-list)

	RESULT_FILE=${RESULT_FILE_PREFIX}_stream${STREAM_NUM}

	echo "TCP_STREAM: Start experiments..."
	for i in $(seq 1 ${REPEAT})
	do
		echo -e "\tRepeat #$i..."
		seq 1 ${STREAM_NUM} | \
		    xargs -I{} -P${STREAM_NUM} ssh ${SSH_OPTIONS}${VM_IP} "
				cd '"${VM_WORKING_DIR}"'
				[ ! -s '"${RESULT_FILE}"'_{} ] && echo '"${HEADER}"' | tee '"${RESULT_FILE}"'_{} > /dev/null
                netperf -H '"${SERVER_IP}"' -l '"${TIME}"' | tail -n 1 >> '"${RESULT_FILE}"'_{} &
				wait
                " > /dev/null 2>&1
		sleep 3
	done

# Modify <INSTANCE_NUM> option
elif [ ! -z ${INSTANCE_NUM} ]; then
	sudo rm ${RESULT_DIR}*concurrency${INSTANCE_NUM}* > /dev/null 2>&1

	vm_resource/vm_run.sh -c 1 -m 2G -n ${INSTANCE_NUM}
    echo "VMs are running."

	RESULT_FILE=${RESULT_FILE_PREFIX}_concurrency${INSTANCE_NUM}
	
	echo "TCP_STREAM: Start experiments..."
	for i in $(seq 1 ${REPEAT})
	do
		echo -e "\tRepeat #$i..."
		cat vm_resource/net-vm-ip-list | \
			xargs -I {} -P${INSTANCE_NUM} ssh ${SSH_OPTIONS}{} "
				cd '"${VM_WORKING_DIR}"'
				[ ! -s '"${RESULT_FILE}"'_"VM"{} ] && echo '"${HEADER}"' | tee '"${RESULT_FILE}"'_"VM"{} > /dev/null
				netperf -H '"${SERVER_IP}"' -l '"${TIME}"' | tail -n 1 >> '"${RESULT_FILE}"'_"VM"{} &
				wait" > /dev/null 2>&1
		sleep 3
	done

# <DEFAULT> option
else	
	sudo rm ${RESULT_DIR}*default* > /dev/null 2>&1
		
	vm_resource/vm_run.sh -c 1 -m 4G -n 1
	echo "VM is running."
	VM_IP=$(cat vm_resource/net-vm-ip-list)
	
	echo "TCP_STREAM: Start experiments..."
	for M_SIZE in ${M_SIZES[@]}
	do
	    RESULT_FILE="${RESULT_FILE_PREFIX}_default_${M_SIZE}"
		ssh ${SSH_OPTIONS}${VM_IP} "cd ${VM_WORKING_DIR} && echo '${HEADER}' | tee ${RESULT_FILE} > /dev/null" 2> /dev/null

		for i in $(seq 1 ${REPEAT})
		do
			echo -e "\tRepeat #$i..."
			do_pidstat "qemu" ${RESULT_FILE}
			do_perfstat "qemu" ${RESULT_FILE}
			do_mpstat ${RESULT_FILE}
			ssh ${SSH_OPTIONS}${VM_IP} "
				cd ${VM_WORKING_DIR} && 
				netperf -H ${SERVER_IP} -l ${TIME} -- -m ${M_SIZE} | tail -n 1 >> ${RESULT_FILE} &
				wait" > /dev/null 2>&1
			kill $(pgrep [p]idstat) > /dev/null
			sudo kill -2 $(pgrep [p]erf) > /dev/null
			kill $(pgrep [m]pstat) > /dev/null
			sleep 3
		done

		echo -e "\tMessage size(${M_SIZE}B) finished."
done
fi

echo "Copy results from VM to host."
cat vm_resource/net-vm-ip-list | \
	xargs -I {} sudo scp -q -r ${SSH_OPTIONS}{}:${VM_WORKING_DIR}${RESULT_DIR} net_result/vm/

echo "Remove existing VM resources except for original VM."
vm_resource/vm_clean.sh

echo "All experiments are completed !!"
