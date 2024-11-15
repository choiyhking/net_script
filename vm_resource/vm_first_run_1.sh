#!/bin/bash


cd "$(dirname "$0")"

ISO="ubuntu-24.04.1-live-server-arm64.iso"
PRIVATE_KEY="vm.id_rsa"
SSH_OPTIONS="-o StrictHostKeyChecking=no -i ${PRIVATE_KEY} root@"

# Functions


echo "Enter the number of vCPUs:"
read -p ">> " CPU

echo "Enter the size of memory (minimum is 2048 MiB):"
read -p ">> " MEMORY

 
echo "Remove all existing VMs and resources."
sudo virsh list --all --name | xargs -I {} sudo virsh shutdown {} 2> /dev/null
sudo virsh list --all --name | xargs -I {} sudo virsh undefine {} --nvram --remove-all-storage 2> /dev/null


# Check original ISO image
if [ ! -f "${ISO}" ]; then
	echo "ISO image is missing. Downloading..."
	wget -q -O ${ISO} "https://cdimage.ubuntu.com/releases/noble/release/ubuntu-24.04.1-live-server-arm64.iso"
fi

VM_NAME="original-net-vm"
QCOW_PATH="$HOME/net_script/vm_resource/"

echo "Creating Firecracker microVM..."
sudo virt-install --name=${VM_NAME} \
	--vcpus=${CPU} \
	--memory=${MEMORY} \
	--cdrom=${ISO} \
	--os-variant=ubuntu22.04 \
	--disk path=${QCOW_PATH}${VM_NAME}.qcow2,size=10,format=qcow2 \
	--noautoconsole

echo -e "\tQEMU/KVM virtual machine is created."

echo ""
printf '%*s\n' $(tput cols) | tr ' ' '*'	
printf '%*s\n' $(tput cols) | tr ' ' '*'	
echo "You have to manually configure the initial options of VM."
echo "RUN \"sudo virsh console ${VM_NAME}\""
echo "[To-Do] Username: vm"
echo "[To-Do] Hostname: ${VM_NAME}"
echo "[To-Do] Check \"Install OpenSSH Server\""
echo "[To-Do] RUN \"sudo sed -i '/^#PermitRootLogin/c\PermitRootLogin yes' /etc/ssh/sshd_config\""
echo "[To-Do] RUN \"sudo systemctl enable ssh && sudo systemctl start ssh\""
echo "After that, RUN \"./fc_first_run_2.sh\""
printf '%*s\n' $(tput cols) | tr ' ' '*'	
printf '%*s\n' $(tput cols) | tr ' ' '*'	


