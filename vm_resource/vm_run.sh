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
	
	scp ${SSH_OPTIONS} 50-cloud-init.yaml ${USER}@${1}:/etc/netplan/
	ssh ${SSH_OPTIONS} ${USER}@${1} " 
		sed -i 's/${BASE_VM}/${3}/g' /etc/hosts
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


echo "Remove existing VMs and resources except for orginal VM."
./vm_clean.sh

for ((i=1; i<=${VM_NUM}; i++))
do
	echo "Creating VM #${i}..."

	OLD_GUEST_IP=$(cat "${BASE_VM}-ip")
	VM_NAME=${VM_NAME_PREFIX}${i}

	sudo virt-clone --original ${BASE_VM} --name ${VM_NAME} --file ${QCOW_PATH}${VM_NAME}.qcow2
	sleep 5 && sudo virsh start ${VM_NAME} && sleep 100

	# Guest IP starts from 192.168.122.101
	NEW_GUEST_IP="192.168.122.$((100 + ${i}))"
	echo ${NEW_GUEST_IP} >> net-vm-ip-list
	
	echo "Update VM's network configuration."
	update_network_config ${OLD_GUEST_IP} ${NEW_GUEST_IP} ${VM_NAME}
	#sudo virsh reboot ${VM_NAME} && sleep 60
done
