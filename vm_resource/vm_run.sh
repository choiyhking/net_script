#!/bin/bash



BASE_VM="original-net-vm"
VM_NAME_PREFIX="net-vm-"
USER="root"
QCOW_PATH="$HOME/net_script/vm_resource/"
PRIVATE_KEY="vm.id_rsa"
SSH_OPTIONS="-o StrictHostKeyChecking=no -i ${PRIVATE_KEY}"

cd "$(dirname "$0")"


# Functions
update_network_config() {
	# ${1}: old guest IP
	# ${2}: new geuset IP
	# ${3}: new host name

	sed -i "s/[0-9\.]\+\/24/"${2}"\/24/g" 50-cloud-init.yaml	
	
	scp ${SSH_OPTIONS} 50-cloud-init.yaml ${USER}@${1}:/etc/netplan/ 2> /dev/null
	ssh ${SSH_OPTIONS} ${USER}@${1} " 
		sed -i 's/${BASE_VM}/${3}/g' /etc/hosts
		hostnamectl set-hostname ${3}
	" 2> /dev/null
}

convert_to_kb() {
    local input=${1}
    local result

    if [[ "${input}" =~ ^([0-9]+)G$ ]]; then
        result=$(( ${BASH_REMATCH[1]} * 1024 * 1024))
    elif [[ "${input}" =~ ^([0-9]+)m$ ]]; then
	result=$(( ${BASH_REMATCH[1]} * 1024 ))
    else
        result=${input}
    fi

    echo "${result}"
}

update_resource_config() {
	# ${1}: VM name
	
	CONFIG=${1}-config.xml
	sudo virsh dumpxml ${1} > ${CONFIG}


	sudo sed -i "s/<vcpu placement='static'>[0-9]\+<\/vcpu>/<vcpu placement='static'>"${CPU}"<\/vcpu>/" ${CONFIG}
	sudo sed -i "s/<memory unit='KiB'>[0-9]\+<\/memory>/<memory unit='KiB'>"$(convert_to_kb ${MEMORY})"<\/memory>/" ${CONFIG}
	sudo sed -i "s/<currentMemory unit='KiB'>[0-9]\+<\/currentMemory>/<currentMemory unit='KiB'>"$(convert_to_kb ${MEMORY})"<\/currentMemory>/" ${CONFIG}

	sudo virsh define ${CONFIG}
}

wait_for_boot() {
    # $1: VM IP
	#while ! nc -z $1 22 2> /dev/null; do
		#echo "Waiting for VM to boot..."
		#sleep 10
	#done
	#echo "VM is booted!"

	while ! ssh -q ${USER}@$1 "exit 0"; do
		echo "Waiting for SSH service to be ready..."
		sleep 2
	done
	echo "VM is booted!"
}

# Get options
while getopts "c:m:n:" opt; do
  case $opt in
    c) CPU=${OPTARG} ;;
    m) MEMORY=${OPTARG} ;;
    n) VM_NUM=${OPTARG} ;;
    \?) echo "Invalid option -${OPTARG}" >&2; exit 1 ;;
    :) echo "Option -${OPTARG} requires an argument." >&2; exit 1 ;;
  esac
done


# Check if all required options are provided
if [ -z "${CPU}" ] || [ -z "${MEMORY}" ] || [ -z "${VM_NUM}" ]; then
	echo "Error: Options -c(CPU), -m(Memory), and -n(VM #) are required." >&2
  exit 1
fi


echo "Remove existing VMs and resources except for orginal VM."
./vm_clean.sh

# Ubuntu 24.04 System Requirements
# Minimum RAM: 1GB, Suggested: 3GB
# Minimum storage: 5GB, Suggested: 25GB

for ((i=1; i<=${VM_NUM}; i++))
do
	echo "Creating VM #${i}..."

	OLD_GUEST_IP=$(cat "${BASE_VM}-ip")
	VM_NAME=${VM_NAME_PREFIX}${i}

	sudo virt-clone --original ${BASE_VM} --name ${VM_NAME} \
		--file ${QCOW_PATH}${VM_NAME}.qcow2
	
	echo "Update VM's resource configuration."
	update_resource_config ${VM_NAME}
	
	sudo virsh start ${VM_NAME} && wait_for_boot ${OLD_GUEST_IP}
	# Guest IP starts from 192.168.122.101
	NEW_GUEST_IP="192.168.122.$((100 + ${i}))"
	echo ${NEW_GUEST_IP} >> net-vm-ip-list
	
	echo "Update VM's network configuration."
	update_network_config ${OLD_GUEST_IP} ${NEW_GUEST_IP} ${VM_NAME}

	sudo virsh reboot ${VM_NAME} && wait_for_boot ${OLD_GUEST_IP}
done

