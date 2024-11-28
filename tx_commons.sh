#!/bin/bash


SERVER_IP="192.168.51.232"
TIME="5" # netperf test time (sec)
#TIME="21" # netperf test time (sec)
M_SIZES=(1 4) 
#M_SIZES=(1 4 8 16 32 64 128 256 512 1024) 
HEADER="Recv_Socket_Size(B) Send_Socket_Size(B) Send_Message_Size(B) Elapsed_Time(s) Throughput(10^6bps)"

do_pidstat() {
	local target=$(echo "$1" | sed 's/^\(.\)/[\1]/')
    local result_file=$2

    # Sleep to give netperf time to start
    (sleep 1; pidstat -p $(pgrep ${target}) 1 2> /dev/null | \
		awk '{print $5, $6, $7, $8, $9}' | sudo tee -a "${result_file}_pidstat" > /dev/null) &
}

do_mpstat() {
    local result_file=$1

    (sleep 1; mpstat 1 | awk '{print $4, $6, $7, $8, $9, $11, $13}' \
        | sudo tee -a "${result_file}_mpstat" > /dev/null) &
}

do_perfstat() {
	local target=$(echo "$1" | sed 's/^\(.\)/[\1]/')
	local result_file=$2

	(sleep 1; sudo perf stat -x, -p $(pgrep ${target}) \
	 -e cycles:u,cycles:k,instructions:u,instructions:k,cache-misses:u,cache-misses:k,page-faults:u,page-faults:k,context-switches:u,context-switches:k \
	 2>&1 | sudo tee -a "${result_file}_perfstat" > /dev/null; \
	 echo "" | sudo tee -a "${result_file}_perfstat" > /dev/null) &

}

get_options() {
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
}

convert_to_mb() {
    local input=$1
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
