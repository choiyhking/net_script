#!/bin/bash


# Move to current script's directory
cd "$(dirname "$0")"

for VM in $(sudo virsh list --all --name | grep ^net-vm-); do
    sudo virsh destroy ${VM}
    sudo virsh undefine ${VM} --remove-all-storage --nvram 2> /dev/null
done

# qcow2, config.xml, ip list
for file in $(find . -maxdepth 1 -type f -name "net-vm-*"); do
	rm -f ${file} > /dev/null 2>&1
done


sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
# 1: delete page cache
# 2: delete directory entry and inode cache
# 3: delete page cache, directory entry, inode cache

