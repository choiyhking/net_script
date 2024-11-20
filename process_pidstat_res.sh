#!/bin/bash



echo "Select the virtualization platform."
read ">> " platform

# $1: virtualization platform
path=$HOME/net_result/${platform}/throughput/
pushd ${path}

for file in $(ls *pidstat)
do
	echo ${file}
	grep -v '^Linux' ${file} | awk '{ $2=$3=$4=""; print }' > temp
	mv temp ${file}
done

popd
