#!/bin/bash


source ./rr_commons.sh
PRIVATE_KEY="fc_resource/ubuntu-22.04.id_rsa"
SSH_OPTIONS="-o StrictHostKeyChecking=no -i ${PRIVATE_KEY} root@"

RESULT_DIR="net_result/fc/basic/"
RESULT_FILE_PREFIX="${RESULT_DIR}res_rr"
FC_WORKING_DIR="/root/net_script/"


###############
# Preparation #
###############
sudo mkdir -p ${RESULT_DIR} # pwd: $HOME/net_script/

echo "Remove existing Firecracker resources."
fc_resource/fc_clean.sh

get_options $@

#####################
# Start Experiments #
#####################
sudo rm ${RESULT_DIR}*_rr_* > /dev/null 2>&1

fc_resource/fc_run.sh -c 2 -m 4096 -n 1
echo "Firecracker microVM is running."
VM_IP=$(awk '/Guest IP/ {print $3}' fc_resource/fc_info_list)

echo "TCP_RR: Start experiments..."
for i in ${!REQUEST_SIZES[@]}; do
    REQ_SIZE=${REQUEST_SIZES[$i]}
    RESP_SIZE=${RESPONSE_SIZES[$i]}

    RESULT_FILE="${RESULT_FILE_PREFIX}_${REQ_SIZE},${RESP_SIZE}"	
	ssh ${SSH_OPTIONS}${VM_IP} "cd ${FC_WORKING_DIR} && echo '${HEADER}' | tee ${RESULT_FILE} > /dev/null" 2> /dev/null

	for i in $(seq 1 ${REPEAT})
	do
		echo -e "\tRepeat #$i..."
		ssh ${SSH_OPTIONS}${VM_IP} "
			cd ${FC_WORKING_DIR} && 
			
			(netperf -H ${SERVER_IP} -t TCP_RR -l ${TIME} -- -r ${REQ_SIZE},${RESP_SIZE} \
            -o throughput,min_latency,max_latency,mean_latency,stddev_latency \
            | tail -n 1 >> ${RESULT_FILE}) &
			
			wait" > /dev/null 2>&1
		sleep 3
		echo -e "\tRequest, Response(${REQ_SIZE}B, ${RESP_SIZE}B) finished."
	done
done

echo "Copy results from Firecracker microVM to host."
awk '/Guest IP/ {print $3}' fc_resource/fc_info_list | \
		xargs -I {} sudo scp -q -r ${SSH_OPTIONS}{}:${FC_WORKING_DIR}${RESULT_DIR} net_result/fc/

echo "Remove existing Firecracker resources."
fc_resource/fc_clean.sh

echo "All experiments are completed !!"
