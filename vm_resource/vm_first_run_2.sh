#!/bin/bash



VM_NAME="original-net-vm"
USER="root"
IP=$(sudo virsh domifaddr ${VM_NAME} | awk '/ipv4/ {print $4}' | cut -d'/' -f1)
PRIVATE_KEY="vm.id_rsa"
SSH_OPTIONS="-o StrictHostKeyChecking=no -i ${PRIVATE_KEY}"



ssh-keygen -t rsa 

echo "Copy public key to vm_resource directory."
cp $HOME/.ssh/id_rsa vm.id_rsa

echo "Add id_rsa.pub to VM's ~/.ssh/authorized_keys."
ssh-copy-id ${USER}@${IP}

ssh ${SSH_OPTIONS} ${USER}@${IP} "
	apt update
	apt install -y git netperf
	git clone https://github.com/choiyhking/net_script.git
       	mkdir -p net_script/net_result/vm/throughput
"	
