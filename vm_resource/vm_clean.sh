#!/bin/bash

wait_for_vm_state() {
        # ${1}: command
        # ${2}: VM name

        if [[ ${1} == "start" ]]; then
            sudo virsh start ${2} 2> /dev/null

            while ! sudo virsh domstate ${2} | grep -q "running"; do
                sleep 2 
            done

        elif [[ ${1} == "shutdown" ]]; then
            sudo virsh shutdown ${2} 2> /dev/null
            
            while sudo virsh domstate ${2} | grep -q "running"; do
                sleep 2 
            done
        fi
}

# Move to current script's directory
cd "$(dirname "$0")"

for VM in $(sudo virsh list --all --name | grep ^net-vm-[^-]*$); do
    wait_for_vmstate shutdown ${VM}
    sudo virsh undefine ${VM} --remove-all-storage --nvram 2> /dev/null
done

rm -f net-vm-*.xml > /dev/null 2>&1
rm -f net-vm-*.qcow2 > /dev/null 2>&1

for file in $(find . -maxdepth 1 -type f -name "net-vm-*"); do
	rm -f ${file} > /dev/null 2>&1
done

