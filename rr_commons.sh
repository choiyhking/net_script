#!/bin/bash


SERVER_IP="192.168.51.232"
TIME="21" # netperf test time (sec)
#REQUEST_SIZES=(1 32 256 1024 4096)
#RESPONSE_SIZES=(1 128 512 2048 8192)
REQUEST_SIZES=(1)
RESPONSE_SIZES=(1)
HEADER="throughput(trans/s),min_latency(us),max_latency(us),mean_latency(us),stddev_latency(us)"


get_options() {
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
