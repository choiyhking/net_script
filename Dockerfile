# Base image
FROM ubuntu:22.04

# Update package lists and install required packages
RUN apt update && \
    apt install -y git netperf

# Set working directory
WORKDIR /root

# Define a build argument to clone the newest repo with no cache
ARG CACHE_BUST=1

# Clone the repository
RUN git clone https://github.com/choiyhking/net_script.git

# Set working directory
WORKDIR /root/net_script

# Make all .sh files executable
RUN chmod +x *.sh

# Default command
CMD ["sleep", "infinity"]
