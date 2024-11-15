#!/bin/bash



# Move to current script's directory
cd "$(dirname "$0")"


for VM in $(sudo virsh list --name | grep net-vm); do
    #sudo virsh shutdown ${VM}
    sudo virsh destroy ${VM}
    sudo virsh undefine ${VM} --remove-all-storage --nvram
done

rm -f net-vm-*.xml > /dev/null 2>&1
