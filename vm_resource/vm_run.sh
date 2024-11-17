#!/bin/bash


USER="root"
PRIVATE_KEY="vm.id_rsa"
SSH_OPTIONS="-o StrictHostKeyChecking=no -i ${PRIVATE_KEY}"
SUDO_PW="1"
ORIGINAL_HOSTNAME="original-net-vm"

cd "$(dirname "$0")"

# Functions
sudo_prefix() {
	echo ${SUDO_PW} | sudo -S "$@"
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

wait_for_vm_state() {
	local target=${1}
	local VM=${2}
	while true; do
		STATE=$(sudo virsh domstate ${VM})
		if [[ ${STATE} == ${target} ]]; then
			echo "${VM} is now ${target}."
			break
		fi
		sleep 2
	done
}

change_vm_state() {
	# ${1}: command (e.g., start)
	# ${2}: VM name
	declare -A state_map=(
	    [start]="running"
	    [shutdown]="shut off"
	)

	sudo virsh $1 $2

	target_state=${state_map[$1]}
	while true; do
		cur_state=$(sudo virsh domstate $2 2>/dev/null)

		if [[ ${cur_state} == ${target_state} ]]; then
		    echo "VM '$2' reached state '$target_state'."
		    break
		fi

		echo "Current state: $cur_state. Waiting for '$target_state'..."
		sudo virsh $1 $2
		sleep 2
    	done
		

}


update_resource_config() {
	# ${1}: VM name
	
	local CONFIG=${1}-config.xml
	sudo virsh dumpxml ${1} > ${CONFIG}
	sudo sed -i "s/<vcpu placement='static'>[0-9]\+<\/vcpu>/<vcpu placement='static'>"${CPU}"<\/vcpu>/" ${CONFIG}
	sudo sed -i "s/<memory unit='KiB'>[0-9]\+<\/memory>/<memory unit='KiB'>"$(convert_to_kb ${MEMORY})"<\/memory>/" ${CONFIG}
	
	sudo virsh define ${CONFIG}

	sudo virsh destroy ${1}
	sudo virsh start ${1} && sleep 30
}

update_network_config() {
	# ${1}: old guest IP
	# ${2}: new geuset IP
	# ${3}: new host name

	sed -i "s/[0-9\.]\+\/24/"${2}"\/24/g" 50-cloud-init.yaml	
	

	scp ${SSH_OPTIONS} 50-cloud-init.yaml ${USER}@${1}:/etc/netplan/
	ssh ${SSH_OPTIONS} ${USER}@${1} " 
		sed -i 's/${ORIGINAL_HOSTNAME}/${3}/g' /etc/hosts
		hostnamectl set-hostname ${3}
	"
}





# Get options
while getopts "n:" opt; do
  case $opt in
    n) VM_NUM=${OPTARG} ;;
    \?) echo "Invalid option -${OPTARG}" >&2; exit 1 ;;
    :) echo "Option -${OPTARG} requires an argument." >&2; exit 1 ;;
  esac
done

# Check if all required options are provided
if [ -z "${VM_NUM}" ]; then
  echo "Error: Options -n(VM #) is required." >&2
  exit 1
fi



BASE_VM="original-net-vm"
VM_NAME_PREFIX="net-vm-"
QCOW_PATH="$HOME/net_script/vm_resource/"


echo "Remove existing VMs and resources except for orginal VM."
./vm_clean.sh

for ((i=1; i<=${VM_NUM}; i++))
do
	OLD_GUEST_IP=$(cat "${BASE_VM}-ip")
	echo ${OLD_GUEST_IP}
	VM_NAME=${VM_NAME_PREFIX}${i}
	sudo virt-clone --original ${BASE_VM} --name ${VM_NAME} --file ${QCOW_PATH}${VM_NAME}.qcow2
	sudo virsh start ${VM_NAME} && sleep 60
	#update_resource_config ${VM_NAME} ${CPU}
	#echo -e "Resource configuration updated." 	

	NEW_GUEST_IP="192.168.122.$((100 + ${i}))"
	echo ${NEW_GUEST_IP} >> net-vm-ip-list
	#test
	update_network_config ${OLD_GUEST_IP} ${NEW_GUEST_IP} ${VM_NAME}
	sudo virsh reboot ${VM_NAME}
done

# shutdown이 너무 오래 걸림
#
