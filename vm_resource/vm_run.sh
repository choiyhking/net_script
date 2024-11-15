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

update_resource_config() {
	# ${1}: VM name
	
	local CONFIG=${1}_config.xml
	sudo virsh dumpxml ${1} > ${CONFIG}
	sudo sed -i 's/<vcpu placement="static">1<\/vcpu>/<vcpu placement="static">'"${CPU}"'<\/vcpu>/' ${CONFIG}
	sudo sed -i 's/<memory unit="KiB">1048576<\/memory>/<memory unit="KiB">'"${MEMORY}"'<\/memory>/' ${CONFIG}
	
	sudo virsh define ${CONFIG}

	sudo virsh shutdown ${1}
	sudo virsh start ${1}
	
}

update_network_config() {
	# ${1}: old guest IP
	# ${2}: new geuset IP
	# ${3}: new host name
	
	cat <<EOF > temp
	network:
 	  version: 2
  	  renderer: networkd
  	  ethernets:/
    	    enp1s0:
      	      dhcp4: no
      	      addresses:
                - ${2}/24
              routes:
                - to: default
                  via: 192.168.122.1
              nameservers:
                addresses: [155.230.10.2, 8.8.8.8]"
EOF

	scp ${SSH_OPTIONS} temp ${USER}@${1}:/etc/netplan/50-cloud-init.yaml
	ssh ${SSH_OPTIONS} ${USER}@${1} "
		sed -i 's/${ORIGINAL_HOSTNAME}/${3}/g' /etc/hosts
		netplan apply
	"
}

# Get options
while getopts ":c:m:n:" opt; do
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

# Check iso image file
if [ ! -f "${ISO}" ]; then
	echo "ISO image is missing. Downloading..."
	wget -q -O ${ISO} "https://cdimage.ubuntu.com/releases/noble/release/ubuntu-24.04.1-live-server-arm64.iso"
fi



BASE_VM="original-net-vm"
VM_NAME_PREFIX="net-vm-"
QCOW_PATH="$HOME/net_script/vm_resource/"

for ((i=1; i<=${VM_NUM}; i++))
do
	VM_NAME=${VM_NAME_PREFIX}${i}
	sudo virsh shutdown ${BASE_VM} > /dev/null 2>&1
	sudo virt-clone --original ${BASE_VM} --name ${VM_NAME} --file ${QCOW_PATH}${VM_NAME}.qcow2 > /dev/null 2>&1

	echo -e "\tVirtual machine is created."
	update_resource_config ${VM_NAME} ${CPU}
	echo -e "\tResource configuration updated." 

	OLD_GUEST_IP=$(sudo virsh domifaddr ${VM_NAME} | awk '/ipv4/ {print $4}' | cut -d'/' -f1)
	NEW_GUEST_IP="192.168.122.${i}"
	guest_network_setup ${OLD_GUEST_IP} ${NEW_GUEST_IP} ${VM_NAME}
	# ip, mac, gateway, ... 

done
