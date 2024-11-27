#!/bin/bash


SERVER_IP="192.168.51.232"
TIME="21" # netperf test time (sec)
M_SIZES=(1 4 8 16 32 64 128 256 512 1024) 
HEADER="Recv_Socket_Size(B) Send_Socket_Size(B) Send_Message_Size(B) Elapsed_Time(s) Throughput(10^6bps)"
