#!/bin/bash


cd "$(dirname "$0")"


convert_to_kb() {
    local input=${1}
    local result

    if [[ "${input}" =~ ^([0-9]+)G$ ]]; then
        result=$(( ${BASH_REMATCH[1]} * 1024 * 1024))
    elif [[ "${input}" =~ ^([0-9]+)m$ ]]; then
	result=$(( ${BASH_REMATCH[1]} * 1024 ))
    else
        result=${input}
    fi

    echo "${result}"
}
# ${1}: VM name



while getopts ":n:c:m:" opt; do
  case $opt in
    n) VM_NAME=${OPTARG} ;;
    c) CPU=${OPTARG} ;;
    m) MEMORY=${OPTARG} ;;
    \?) echo "Invalid option -${OPTARG}" >&2; exit 1 ;;
    :) echo "Option -${OPTARG} requires an argument." >&2; exit 1 ;;
  esac
done

# Check if all required options are provided
if [ -z "${VM_NAME}" ] || [ -z "${CPU}" ] || [ -z "${MEMORY}" ]; then
	echo "Error: Options -n(VM name), -c(CPU), and -m(Memory) are required." >&2
  exit 1
fi


CONFIG=${VM_NAME}-config.xml
sudo virsh dumpxml ${VM_NAME} > ${CONFIG}


sudo sed -i "s/<vcpu placement='static'>[0-9]\+<\/vcpu>/<vcpu placement='static'>"${CPU}"<\/vcpu>/" ${CONFIG}
sudo sed -i "s/<memory unit='KiB'>[0-9]\+<\/memory>/<memory unit='KiB'>"$(convert_to_kb ${MEMORY})"<\/memory>/" ${CONFIG}

sudo virsh define ${CONFIG}

sudo virsh destroy ${VM_NAME}
sudo virsh start ${NAME} && sleep 60
