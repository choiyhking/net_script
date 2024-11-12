#!/bin/bash



VM_NUM=${1}

HOST_IFACE="eth0"
NETWORK_IP_PREFIX="172.16.0."
NETWORK_IP_LAST_OCTET="0"
SUBNET_MASK="/30"
SUBNET_SIZE=4
ROOTFS="ubuntu-22.04.ext4" # Original rootfs. Do not use this directly !!. Only copy allowed.


# Functions
host_network_setup(){
	# ${1}: tap device
	# ${2}: tap IP

	sudo ip link del "${1}" 2> /dev/null || true
	sudo ip tuntap add dev "${1}" mode tap
	sudo ip addr add "${2}${SUBNET_MASK}" dev "${1}"
	sudo ip link set dev "${1}" up

	# Set up microVM internet access (specific to tap device)
	sudo iptables -D FORWARD -i "${1}" -o "${HOST_IFACE}" -j ACCEPT > /dev/null 2>&1
	sudo iptables -I FORWARD 1 -i "${1}" -o "${HOST_IFACE}" -j ACCEPT > /dev/null 2>&1

	echo "Host network set-up is finished."
}

guest_network_setup() {
	# ${1}: guest IP
	# ${2}: tap IP
	
	ssh -q -i ubuntu-22.04.id_rsa root@${1} sh -c "cat <<EOF | tee /etc/systemd/network/my-network-config.network > /dev/null
[Match] 
Name=${HOST_IFACE} 

[Network] 
Address=${1}${SUBNET_MASK} 
Gateway=${2} 
EOF
"

	ssh -q -i ubuntu-22.04.id_rsa root@${1} <<EOF
	echo nameserver 155.230.10.2 > /etc/resolv.conf
	mkdir /var/lib/dpkg > /dev/null 2>&1
	touch /var/lib/dpkg/status > /dev/null 2>&1
	systemctl enable systemd-networkd.service > /dev/null 2>&1
	systemctl restart systemd-networkd.service > /dev/null 2>&1
EOF
}

guest_init() {
	# ${1}: guest IP

	ssh -q -i ubuntu-22.04.id_rsa root@${1} <<EOF
    apt update
    apt install -y git netperf
    git clone https://github.com/choiyhking/net_script.git 
    mkdir -p net_script/net_result/fc/throughput/
EOF
}


# Enable IP forwarding
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

# Set up microVM internet access (common)
sudo iptables -t nat -D POSTROUTING -o i"${HOST_IFACE}" -j MASQUERADE > /dev/null 2>&1
sudo iptables -t nat -A POSTROUTING -o "${HOST_IFACE}" -j MASQUERADEi > /dev/null 2>&1
sudo iptables -D FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1
sudo iptables -I FORWARD 1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1

# Check original rootfs
if [ ! -f "${ROOTFS}" ]; then
	wget -q -O ${ROOTFS} "https://s3.amazonaws.com/spec.ccfc.min/firecracker-ci/v1.10/aarch64/ubuntu-22.04.ext4"
fi

ROOTFS_SIZE="5G"
truncate -s ${ROOTFS_SIZE} ${ROOTFS} > /dev/null 2>&1
e2fsck -f ${ROOTFS} > /dev/null 2>&1
resize2fs ${ROOTFS} > /dev/null 2>&1


for ((i=1; i<=${VM_NUM}; i++))
do
	TAP_DEV="fc-${i}-tap0"
	TAP_IP=${NETWORK_IP_PREFIX}$((${NETWORK_IP_LAST_OCTET} + 1))
	GUEST_IP=${NETWORK_IP_PREFIX}$((${NETWORK_IP_LAST_OCTET} + 2))

	MAC_LAST_OCTET=$(printf "%02x" $((2 + 4 * (i - 1)))) # maximum 64 mac addresses are available
	MAC_ADDR="06:00:AC:10:00:${MAC_LAST_OCTET}"

	# Print information
	echo "VM ${i}:"
	echo "  Subnet: ${NETWORK_IP_PREFIX}${NETWORK_IP_LAST_OCTET}${SUBNET_MASK}"
	echo "  TAP IP: ${TAP_IP}"
	echo "  GUEST IP: ${GUEST_IP}"
	echo "  MAC Address: ${MAC_ADDR}"

	echo "${GUEST_IP}" >> fc_ip_list

	host_network_setup ${TAP_DEV} ${TAP_IP}

	sudo sed -i 's/"host_dev_name": "[^"]*"/"host_dev_name": \"'${TAP_DEV}'\"/' "fc_config.json"
	sudo sed -i 's/"guest_mac": "[^"]*"/"guest_mac": \"'${MAC_ADDR}'\"/' "fc_config.json"
	cp ${ROOTFS} ${ROOTFS}.${i}
	sudo sed -i 's/"path_on_host": "[^"]*"/"path_on_host": \"'${ROOTFS}.${i}'\"/' "fc_config.json"


    rm -f /tmp/firecracker.socket 
	(firecracker --api-sock /tmp/firecracker.socket --config-file fc_config.json > /dev/null 2>&1) &
	sleep 3
	echo "Firecracker microVM is created."

	guest_network_setup ${GUEST_IP} ${TAP_IP} > /dev/null 2>&1
	echo "Guest network set-up is finished"

	echo "Guest VM initializing...(it takes time)"
	guest_init ${GUEST_IP} > /dev/null 2>&1
	echo "Guest init is finished"

    # Next network subnet
    # 172.16.0.0/30, 172.16.0.4/30, ...
    NETWORK_IP_LAST_OCTET=$((NETWORK_IP_LAST_OCTET + SUBNET_SIZE))
done
