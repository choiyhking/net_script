#!/bin/bash


cd "$(dirname "$0")"
#VM_NUM=${1}

HOST_IFACE="eth0"
NETWORK_IP_PREFIX="172.16.0."
NETWORK_IP_LAST_OCTET="0"
SUBNET_MASK="/30"
SUBNET_SIZE=4
ROOTFS="ubuntu-22.04.ext4" # Original rootfs. Do not use this directly !!. Only copy allowed.
PRIVATE_KEY="ubuntu-22.04.id_rsa"
SSH_OPTIONS="-i ${PRIVATE_KEY} root@"

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

	echo -e "\tHost network set-up is finished."
}

guest_network_setup() {
	# ${1}: guest IP
	# ${2}: tap IP
	
	ssh ${SSH_OPTIONS}${1} sh -c "cat <<EOF | tee /etc/systemd/network/my-network-config.network > /dev/null
[Match] 
Name=${HOST_IFACE} 

[Network] 
Address=${1}${SUBNET_MASK} 
Gateway=${2} 
EOF
"

	ssh ${SSH_OPTIONS}${1} <<EOF
	echo nameserver 155.230.10.2 > /etc/resolv.conf;
	mkdir /var/lib/dpkg;
	touch /var/lib/dpkg/status;
	systemctl enable systemd-networkd.service;
	systemctl restart systemd-networkd.service;
EOF
}

guest_init() {
	# ${1}: guest IP

	ssh ${SSH_OPTIONS}${1} <<EOF
    apt update
    apt install -y git netperf
    git clone https://github.com/choiyhking/net_script.git 
    mkdir -p net_script/net_result/fc/throughput/
EOF
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

# Enable IP forwarding
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

# Set up microVM internet access (common)
sudo iptables -t nat -D POSTROUTING -o i"${HOST_IFACE}" -j MASQUERADE > /dev/null 2>&1
sudo iptables -t nat -A POSTROUTING -o "${HOST_IFACE}" -j MASQUERADEi > /dev/null 2>&1
sudo iptables -D FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1
sudo iptables -I FORWARD 1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1

# Check original rootfs
if [ ! -f "${ROOTFS}" ]; then
	echo "ROOTFS is missing. Downloading..."
	wget -q -O ${ROOTFS} "https://s3.amazonaws.com/spec.ccfc.min/firecracker-ci/v1.10/aarch64/ubuntu-22.04.ext4"
fi

ROOTFS_SIZE="5G"
truncate -s ${ROOTFS_SIZE} ${ROOTFS} > /dev/null 2>&1
e2fsck -f ${ROOTFS} > /dev/null 2>&1
resize2fs ${ROOTFS} > /dev/null 2>&1


for ((i=1; i<=${VM_NUM}; i++))
do
	echo "Creating Firecracker microVM..."
	TAP_DEV="fc-${i}-tap0"
	TAP_IP=${NETWORK_IP_PREFIX}$((${NETWORK_IP_LAST_OCTET} + 1))
	GUEST_IP=${NETWORK_IP_PREFIX}$((${NETWORK_IP_LAST_OCTET} + 2))

	MAC_LAST_OCTET=$(printf "%02x" $((2 + 4 * (i - 1)))) # maximum 64 mac addresses are available
	MAC_ADDR="06:00:AC:10:00:${MAC_LAST_OCTET}"

	
	#echo "${GUEST_IP}" >> fc_ip_list
	host_network_setup ${TAP_DEV} ${TAP_IP}
	
	sudo sed -i 's/"host_dev_name": "[^"]*"/"host_dev_name": \"'${TAP_DEV}'\"/' "fc_config.json"
	sudo sed -i 's/"guest_mac": "[^"]*"/"guest_mac": \"'${MAC_ADDR}'\"/' "fc_config.json"
	cp ${ROOTFS} ${ROOTFS}.${i}
	sudo sed -i 's/"path_on_host": "[^"]*"/"path_on_host": \"'${ROOTFS}.${i}'\"/' "fc_config.json"

	sudo sed -i 's/"vcpu_count": [0-9]\+/"vcpu_count": '${CPU}'/' "fc_config.json"
	sudo sed -i 's/"mem_size_mib": [0-9]\+/"mem_size_mib": '${MEMORY}'/' "fc_config.json"

    rm -f /tmp/firecracker.socket 
	(firecracker --api-sock /tmp/firecracker.socket --config-file fc_config.json > /dev/null 2>&1) &
	sleep 3
	echo -e "\tMicroVM is created."
	
	# Save information
	cat <<EOF >> fc_info_list
VM ${i}:
  PID: $!
  Subnet: ${NETWORK_IP_PREFIX}${NETWORK_IP_LAST_OCTET}${SUBNET_MASK}
  TAP IP: ${TAP_IP}
  GUEST IP: ${GUEST_IP}
  MAC Address: ${MAC_ADDR}

EOF


	guest_network_setup ${GUEST_IP} ${TAP_IP} > /dev/null 2>&1
	echo -e "\tGuest network set-up is finished."

	echo -e "\tGuest VM initializing...(it takes some time)"
	guest_init ${GUEST_IP} > /dev/null 2>&1
	echo -e "\tGuest initialization is finished."

    # Next network subnet
    # 172.16.0.0/30, 172.16.0.4/30, ...
    NETWORK_IP_LAST_OCTET=$((NETWORK_IP_LAST_OCTET + SUBNET_SIZE))
done
