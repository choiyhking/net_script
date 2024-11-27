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
	
	awk '!/CPU/ && NF { 
        for (i=1; i<=NF; i++) sum[i]+=$i; 
        count++ 
     } 
     END { 
        for (i=1; i<=NF; i++) 
            printf "%.2f\t", sum[i]/count 
		print ""
     }' $1 >> $2
}

do_mpstat_process() {
	# $1: file
	# $2: dest
	
	awk '!/CPU/ && NF { 
        for (i=1; i<=NF; i++) sum[i]+=$i; 
        count++ 
     } 
     END { 
        for (i=1; i<=NF; i++) 
            printf "%.2f\t", sum[i]/count 
		print ""
     }' $1 >> $2
}

do_rr_process(){
	# $1: file
	# $2: dest

    awk 'BEGIN { FS="," } NR > 1 {
		for (i=1; i<=NF; i++) sum[i]+=$i 
        count++
    }
    END {
        for (i=1; i<=NF; i++) {
            avg=sum[i]/count
            printf "%.2f", avg
            if (i < NF) {
                printf "\t"
            }
        }
        print ""
    }' $1 >> $2
}


#PLATFORMS=("runc" "kata" "fc" "vm")
PLATFORMS=("runc")

OPTS=("default" \
	  "cpu_1" "cpu_2" "cpu_3" "cpu_4" \
	  "mem_512m" "mem_1G" "mem_2G" "mem_4G" "mem_6G" \
	  "stream1" "stream3" "stream5" "stream10" \
	  "concurrency1" "concurrency2" "concurrency3" "concurrency4" "concurrency8")

echo "Remove existing filtered results."
sudo rm -rf filtered_net_result

for platform in ${PLATFORMS[@]}
do
	echo "Platform: ${platform}"
	path=$HOME/net_script/net_result/${platform}/basic/
	res_path=$HOME/net_script/filtered_net_result/${platform}/basic/

	mkdir -p ${res_path}

	pushd ${path} > /dev/null

	for option in ${OPTS[@]}
	do
		# Processing "netperf" results
		for file in $(ls | grep "${option}_" | grep -v "pidstat" | grep -v "mpstat" | sort -t '_' -k4n -k5n)
		do
			echo "Processing file: ${file}"
			dest="${res_path}final_${option}_netperf.txt"
			do_netperf_process ${file} ${dest}
		done
		
		# Processing "pidstat" results
		for file in $(ls | grep "pidstat" | grep "${option}_" | sort -t '_' -k4n -k5n)
		do
			echo "Processing file: ${file}"
			dest="${res_path}final_${option}_pidstat.txt"
			do_pidstat_process ${file} ${dest}
		done
		
		# Processing "mpstat" results
		for file in $(ls | grep "mpstat" | grep "${option}_" | sort -t '_' -k4n -k5n)
		do
			echo "Processing file: ${file}"
			dest="${res_path}final_${option}_mpstat.txt"
			do_mpstat_process ${file} ${dest}
		done
	done

	# Processing "TCP_RR" results
	for file in $(ls | grep "_rr_" | sort -t "_" -k3n)
	do
		echo "Processing file: ${file}"
		dest="${res_path}final_rr.txt"
		do_rr_process ${file} ${dest}
	done

	popd > /dev/null
done
