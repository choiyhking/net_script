#!/bin/bash


# $1: virtualization platform
path=net_result/$1/throughput/
pushd ${path}

for file in $(ls *pidstat)
do
	echo ${file}
	grep -v '^Linux' ${file} | awk '{ $2=$3=$4=""; print }' > temp
	mv temp ${file}
done

popd
