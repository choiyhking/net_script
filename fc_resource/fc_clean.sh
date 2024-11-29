#!/bin/bash


# Move to current script's directory
cd "$(dirname $0)"

pgrep [f]irecracker | xargs kill -9 > /dev/null 2>&1

# e.g., fc-1-tap0
COUNT=$(find /sys/class/net/fc* 2> /dev/null | wc -l) # the number of fc tap devices
for ((i=1; i<=COUNT; i++))
do
	sudo ip link del "fc-${i}-tap0" 2> /dev/null 
done

rm -rf /tmp/firecracker.socket > /dev/null 2>&1
rm -f fc_info_list > /dev/null 2>&1
rm -f ubuntu-22.04.ext4.* > /dev/null 2>&1
