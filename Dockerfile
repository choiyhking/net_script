# Base image
FROM ubuntu:22.04

# Update package lists and install required packages
RUN apt update && \
    apt install -y git netperf

# Set working directory to home
WORKDIR /root

# Clone the repository
RUN git clone https://github.com/choiyhking/net_script.git

# Set working directory to the cloned repository
WORKDIR /root/net_script

# Make all .sh files executable
RUN chmod +x *.sh

# Default command (optional, you can customize this)
CMD ["sleep", "infinity"]



