#!/bin/bash


echo "Select the virtualization platform (e.g., runc, kata, fc, vm):"
read -p ">> " PLATFORM

echo "Enter the number of iterations (e.g., 10):"
read -p ">> " REPEAT


# Remove existing results
sudo rm -rf net_result/${PLATFORM}/basic/*_rr_*


echo "***************"
echo "**** START ****"
echo "***************"
./${PLATFORM}_rr.sh -r "${REPEAT}" 
echo ""

echo "***************************************************"
echo "**** ALL EXPERIMENTS ARE SUCCESSFULLY FINISHED ****"
echo "***************************************************"
