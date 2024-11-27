#!/bin/bash


SERVER_IP="192.168.51.232"
TIME="21" # netperf test time (sec)
REQUEST_SIZES=(1 32 256 1024 4096)
RESPONSE_SIZES=(1 128 512 2048 8192)
HEADER="throughput(trans/s), min_latency(us), max_latency(us), mean_latency(us), stddev_latency(us)"
