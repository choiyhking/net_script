#!/bin/bash


source ./rr_commons.sh
RESULT_DIR="net_result/native/basic/"


###############
# Preparation #
###############
sudo mkdir -p ${RESULT_DIR} # pwd: $HOME/net_script/

get_options

#####################
# Start Experiments #
#####################
echo "TCP_RR: Start experiments..."
RESULT_FILE_PREFIX="${RESULT_DIR}res_rr"

sudo rm ${RESULT_DIR}*rr* > /dev/null 2>&1

for i in ${!REQUEST_SIZES[@]}; do
	REQ_SIZE=${REQUEST_SIZES[$i]}
	RESP_SIZE=${RESPONSE_SIZES[$i]}
	
	RESULT_FILE="${RESULT_FILE_PREFIX}_${REQ_SIZE},${RESP_SIZE}"
	echo "${HEADER}" | sudo tee ${RESULT_FILE} > /dev/null
	
	for i in $(seq 1 ${REPEAT})
	do
		echo -e "\tRepeat #$i..."
		netperf -H ${SERVER_IP} -t TCP_RR -l ${TIME} -- -r ${REQ_SIZE},${RESP_SIZE} \
			-o throughput,min_latency,max_latency,mean_latency,stddev_latency \
			| tail -n 1 | sudo tee -a ${RESULT_FILE} > /dev/null
		sleep 3
	done
	echo -e "\tRequest,Response(${REQ_SIZE}B, ${RESP_SIZE}B) finished."
done

echo "All experiments are completed !!"
