#!/bin/bash


source ./rr_commons.sh
PRIVATE_KEY="vm_resource/vm.id_rsa"
SSH_OPTIONS="-o StrictHostKeyChecking=no -i ${PRIVATE_KEY} root@"

RESULT_DIR="net_result/vm/basic/"
RESULT_FILE_PREFIX="${RESULT_DIR}res_rr"
VM_WORKING_DIR="/root/net_script/"


###############
# Preparation #
###############
sudo mkdir -p ${RESULT_DIR} # pwd: $HOME/net_script/

get_options

#####################
# Start Experiments #
#####################
sudo rm ${RESULT_DIR}*rr* > /dev/null 2>&1
	
vm_resource/vm_run.sh -c 1 -m 4G -n 1
echo "VM is running."
VM_IP=$(cat vm_resource/net-vm-ip-list)

	
echo "TCP_RR: Start experiments..."
for i in ${!REQUEST_SIZES[@]}; do
    REQ_SIZE=${REQUEST_SIZES[$i]}
    RESP_SIZE=${RESPONSE_SIZES[$i]}

    RESULT_FILE="${RESULT_FILE_PREFIX}_${REQ_SIZE},${RESP_SIZE}"
	ssh ${SSH_OPTIONS}${VM_IP} "cd ${VM_WORKING_DIR} && echo '${HEADER}' | tee ${RESULT_FILE} > /dev/null" 2> /dev/null

		for i in $(seq 1 ${REPEAT})
		do
			echo -e "\tRepeat ${i}..."
			ssh ${SSH_OPTIONS}${VM_IP} "
				cd ${VM_WORKING_DIR} && 

				netperf -H ${SERVER_IP} -t TCP_RR -l ${TIME} -- -r ${REQ_SIZE},${RESP_SIZE} \
				-o throughput,min_latency,max_latency,mean_latency,stddev_latency \
				| tail -n 1 >> ${RESULT_FILE}

				wait" > /dev/null 2>&1
			sleep 3
		done
	
		echo -e "\tRequest,Response(${REQ_SIZE}B, ${RESP_SIZE}B) finished."
done

echo "Copy results from VM to host."
cat vm_resource/net-vm-ip-list | \
	xargs -I {} sudo scp -q -r ${SSH_OPTIONS}{}:${VM_WORKING_DIR}${RESULT_DIR} net_result/vm/

echo "Remove existing VM resources except for original VM."
vm_resource/vm_clean.sh

echo "All experiments are completed !!"
