#!/bin/bash


killall firecracker 2> /dev/null

COUNT=$(find /sys/class/net/fc* 2> /dev/null | wc -l)
for ((i=1; i<=COUNT; i++))
do
	sudo ip link del "fc-${i}-tap0" 2> /dev/null 
done

rm -rf /tmp/firecracker.socket

rm -f ubuntu-22.04.ext4.*
