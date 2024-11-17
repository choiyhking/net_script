#!/bin/bash



VM_NAME="original-net-vm"
ISO="ubuntu-24.04.1-live-server-arm64.iso"
OS_VARIANT="ubuntu22.04"
QCOW_PATH="$HOME/net_script/vm_resource/"



echo "Enter the number of vCPUs:"
read -p ">> " CPU

echo "Enter the size of memory (minimum is 2048 MiB):"
read -p ">> " MEMORY

echo "Enter the size of disk(GB) (e.g., 10):"
read -p ">> " DISK



echo "Remove all existing VMs and resources."
sudo virsh list --all --name | xargs -I {} sudo virsh shutdown {} 2> /dev/null
sudo virsh list --all --name | xargs -I {} sudo virsh undefine {} --nvram --remove-all-storage 2> /dev/null


# Check original ISO image
if [ ! -f "${ISO}" ]; then
	echo "ISO image is missing. Downloading..."
	wget -q -O ${ISO} "https://cdimage.ubuntu.com/releases/noble/release/ubuntu-24.04.1-live-server-arm64.iso"
fi


echo "Creating QEMU/KVM virtual machine..."
sudo virt-install --name=${VM_NAME} \
	--vcpus=${CPU} \
	--memory=${MEMORY} \
	--cdrom=${ISO} \
	--os-variant=${OS_VARIANT} \
	--disk path=${QCOW_PATH}${VM_NAME}.qcow2,size=${DISK},format=qcow2 \
	--noautoconsole

echo "QEMU/KVM virtual machine is created."

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
echo "[To-Do] RUN \"sudo passwd root\""
echo "[To-Do] If you don't want to use swap, RUN \"echo \"vm.swappiness=0\" | sudo tee -a /etc/sysctl.conf\""
echo "After that, RUN \"./vm_first_run_2.sh\""
printf '%*s\n' $(tput cols) | tr ' ' '*'	
printf '%*s\n' $(tput cols) | tr ' ' '*'	
