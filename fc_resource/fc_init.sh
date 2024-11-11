#!/bin/bash


GUEST_IP=${1}

ssh -i ubuntu-22.04.id_rsa root@${GUEST_IP} << EOF
	apt update
	apt install -y git netperf
	git clone https://github.com/choiyhking/net_script.git
EOF

