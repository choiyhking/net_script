#!/bin/bash

# ${1}: virtualization platform
# ${2}: experimental options
# ${3}: exec pid

sleep 5
EXEC_PID=${3}

RESULT_DIR="$HOME/net_result/${1}/throughput/"
RESULT_FILE_PREFIX="res_throughput"
RESULT_FILE=${RESULT_DIR}${RESULT_FILE_PREFIX}${2}CPU.txt

echo "Start CPU measurement..."
sudo sh -c "pidstat -p $(pgrep netperf) 1 10 > ${RESULT_FILE}" &
PIDSTAT_PID=$!

wait ${EXEC_PID}
kill ${PIDSTAT_PID} 2>/dev/null

echo "CPU usage measurement completed !!"
