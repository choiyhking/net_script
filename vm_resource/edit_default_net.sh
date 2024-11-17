#!/bin/bash


BASE_IP="192.168.122.101" 
BASE_MAC="52:54:00:00"       
NETWORK_NAME="default" 
STARTING_ID=1 


if [ $# -ne 1 ]; then
  echo "Usage: $0 <# of VMs>"
  exit 1
fi
NUM_VM=$1

generate_ip() {
  local index=$1
  local IFS='.'
  read -r i1 i2 i3 i4 <<<"$BASE_IP"
  echo "$i1.$i2.$i3.$((i4 + index - 1))"
}

generate_mac() {
  local index=$1
  printf "%s:%02x:%02x\n" "$BASE_MAC" $((index / 256)) $((index % 256))
}

# DHCP 설정 추가
echo "Adding $NUM_VM to DHCP configuration of $NETWORK_NAME network..."

sudo virsh net-dumpxml $NETWORK_NAME > network.xml

for i in $(seq $STARTING_ID $((STARTING_ID + NUM_VM - 1))); do
  VM_NAME="net-vm-$i"
  VM_IP=$(generate_ip $i)
  VM_MAC=$(generate_mac $i)

  echo "Adding VM: $VM_NAME, IP: $VM_IP, MAC: $VM_MAC"
  sed -i "/<range start=/a \ \ \ \ \ \ <host mac='$VM_MAC' name='$VM_NAME' ip='$VM_IP'/>" network.xml

done

# 변경된 XML을 네트워크에 적용
sudo virsh net-destroy $NETWORK_NAME
sudo virsh net-define network.xml
sudo virsh net-start $NETWORK_NAME

# 확인 메시지
echo "DHCP 설정 완료! 네트워크 $NETWORK_NAME에 $NUM_VM개의 VM이 추가되었습니다."

