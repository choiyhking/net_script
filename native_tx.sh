#!/bin/bash


source ./tx_commons.sh
RESULT_DIR="net_result/native/basic/"


###############
# Preparation #
###############
sudo mkdir -p ${RESULT_DIR} # pwd: $HOME/net_script/

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
RESULT_FILE_PREFIX="${RESULT_DIR}res_tx"

sudo rm ${RESULT_DIR}*default* > /dev/null 2>&1

echo "TCP_STREAM: Start experiments..."
for M_SIZE in ${M_SIZES[@]}
do
	RESULT_FILE="${RESULT_FILE_PREFIX}_default_${M_SIZE}"
	echo "${HEADER}" | sudo tee ${RESULT_FILE} > /dev/null

	for i in $(seq 1 ${REPEAT})
	do
		echo -e "\tRepeat #${i}..."
		do_pidstat "netperf" ${RESULT_FILE}
		do_mpstat ${RESULT_FILE}
		do_perfstat "netperf" ${RESULT_FILE}
		netperf -H ${SERVER_IP} -l ${TIME} -- -m ${M_SIZE} | tail -n 1 | sudo tee -a ${RESULT_FILE} > /dev/null
		kill $(pgrep [m]pstat)
		sleep 3
	done
	echo -e "\tMessage size(${M_SIZE}B) finished."
done

echo "All experiments are completed !!"
