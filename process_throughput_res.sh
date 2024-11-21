#!/bin/bash


# Functions
do_netperf_process() {
	# $1: file
	# $2: dest
	awk 'NR > 1 {printf "%s\t", $5} END {print ""}' $1 >> $2
}

do_pidstat_process() {
	# $1: file
	# $2: dest
	# 5th: %usr, 6th: %system, 7th: %guest, 8th: %wait, 9th: %CPU
	awk '!/^Linux/ && !/UID/ && NF { 
        for (i=5; i<=9; i++) sum[i]+=$i; 
        count++ 
     } 
     END { 
        for (i=5; i<=9; i++) 
            printf "%.2f\t", sum[i]/count 
		print ""
     }' $1 >> $2
}


PLATFORMS=("runc" "kata" "fc" "vm")

OPTS=("default" \
	  "cpu_1" "cpu_2" "cpu_3" "cpu_4" \
	  "mem_512m" "mem_1G" "mem_2G" "mem_4G" "mem_6G" \
	  "stream1" "stream3" "stream5" "stream10" \
	  "concurrency1" "concurrency2" "concurrency3" "concurrency4" "concurrency8")

echo "Remove existing results."
sudo rm -rf filtered_net_result

for platform in ${PLATFORMS[@]}
do
	echo "Platform: ${platform}"
	path=$HOME/net_script/net_result/${platform}/throughput/
	res_path=$HOME/net_script/filtered_net_result/${platform}/throughput/

	mkdir -p ${res_path}

	pushd ${path} > /dev/null

	for option in ${OPTS[@]}
	do
		# Processing "netperf" results
		for file in $(ls | grep "${option}_" | grep -v "pidstat" | sort -t '_' -k4n -k5n)
		do
			echo "Processing file: ${file}"
			dest="${res_path}final_$option.txt"
			do_netperf_process ${file} ${dest}
		done
		
		# Processing "pidstat" results
		for file in $(ls | grep "pidstat" | grep "${option}_" | sort -t '_' -k4n -k5n)
		do
			echo "Processing file: ${file}"
			dest="${res_path}final_${option}_pidstat.txt"
			do_pidstat_process ${file} ${dest}
		done
	done

	popd > /dev/null
done
