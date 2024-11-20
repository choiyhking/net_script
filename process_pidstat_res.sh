#!/bin/bash


echo "Select the virtualization platform."
read -p ">> " platform

path=$HOME/net_script/net_result/${platform}/throughput/
result_path=$HOME/net_script/net_result_processed/${platform}/throughput/

mkdir -p ${result_path}


pushd ${path}


# Example of netperf result
# Recv_Socket_Size(B) Send_Socket_Size(B) Send_Message_Size(B) Elapsed_Time(s) Throughput(10^6bps)
# 131072  16384    512    20.01     929.71  
for file in $(ls | grep -v "pidstat")
do
	echo ${file}
	awk '{ print $5 }' > ${result_path}${file}
done

# Example of pidstat result
# Linux 6.6.31+rpt-rpi-2712 (raspberrypi) 	11/19/2024 	_aarch64_	(4 CPU)
#
# 08:06:06 PM   UID       PID    %usr %system  %guest   %wait    %CPU   CPU  Command
# 08:06:07 PM  1000      3092    3.00   90.00   30.00    1.00  123.00     2  firecracker

for file in $(ls *pidstat)
do
	echo ${file}
	grep -v '^Linux' ${file} | awk '{ $2=$3=$4=""; print }' > ${result_path}${file}
done



popd
