#!/bin/bash


VM_NAME="original-net-vm"
STATIC_IP="192.168.122.100"
USER="root"
PRIVATE_KEY="vm.id_rsa"
SSH_OPTIONS="-q -o StrictHostKeyChecking=no -i ${PRIVATE_KEY}"

IP=$(sudo virsh domifaddr ${VM_NAME} | awk '/ipv4/ {print $4}' | cut -d'/' -f1)


ssh-keygen -t rsa 

echo "Copy the public key to vm_resource directory."
cp $HOME/.ssh/id_rsa vm.id_rsa

echo "Send id_rsa.pub to VM's ~/.ssh/authorized_keys."
ssh-copy-id ${USER}@${IP} 2> /dev/null

echo "Initializing the VM..."
ssh ${SSH_OPTIONS} ${USER}@${IP} "
	apt update
	apt install -y git netperf
	git clone https://github.com/choiyhking/net_script.git
    mkdir -p net_script/net_result/vm/basic	
" > /dev/null	


sed -i "s/[0-9\.]\+\/24/"${STATIC_IP}"\/24/g" 50-cloud-init.yaml
scp ${SSH_OPTIONS} 50-cloud-init.yaml ${USER}@${IP}:/etc/netplan/ 2> /dev/null

# After "netplan apply", guest's IP will be changed.
# Then ssh session will be freezed.
# To resolve this, add "timeout" to automatically stop the session after 5 seconds.
timeout 5 ssh ${SSH_OPTIONS} ${USER}@${IP} "netplan apply"
sudo virsh shutdown ${VM_NAME}

echo ${STATIC_IP} > "${VM_NAME}-ip"
