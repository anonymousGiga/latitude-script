#!/bin/bash

#######################################################################################
#
# This script is for performing preparation tasks for testing, including: 
#      1. Installing the runtime environment; 
#      2. Installing testing tools; 
#      3. Synchronizing to the target block.
#
#######################################################################################

# Default values
mkdir data
DEFAULT_DATADIR="/home/ubuntu/data"
# 10M
#DEFAULT_TARGET_BLOCK_HASH="0xaa20f7bde5be60603f11a45fc4923aab7552be775403fc00c2e6b805e6297dbe"
# 5M
#DEFAULT_TARGET_BLOCK_HASH="0x7d5a4369273c723454ac137f48a4f142b097aa2779464e6505f1b1c5e37b5382"
# 18M
DEFAULT_TARGET_BLOCK_HASH="0x95b198e154acbfc64109dfd22d8224fe927fd8dfdedfae01587674482ba4baf3"


# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        -datadir)
        DATADIR="$2"
        shift
        shift
        ;;
        -target_hash)
        TARGET_BLOCK_HASH="$2"
        shift
        shift
        ;;
        *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
done

# Use default values if parameters are empty
if [ -z "$DATADIR" ]; then
    DATADIR="$DEFAULT_DATADIR"
fi

if [ -z "$TARGET_BLOCK_HASH" ]; then
    TARGET_BLOCK_HASH="$DEFAULT_TARGET_BLOCK_HASH"
fi

# Check if the parameters are empty
if [ -z "$DATADIR" ] || [ -z "$TARGET_BLOCK_HASH" ]; then
    echo "USAGE: ./prepare.sh -datadir DATADIR -target_hash TARGET_BLOCK_HASH"
    exit 1
fi

echo "Data directory is: $DATADIR"
echo "Target block hash is: $TARGET_BLOCK_HASH"

# Do not interrupt the script with pop-ups after installing or updating packages.
# https://askubuntu.com/questions/1367139/apt-get-upgrade-auto-restart-services
sudo sed -i "/#\$nrconf{restart} = 'i';/s/.*/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf
sudo apt update && \

# Setup rust
curl https://sh.rustup.rs -sSf | sh -s -- -y && \
source "$HOME/.cargo/env" && \
echo "Setup rust finish!" && \

# Install Linux perf
sudo apt -yq install linux-tools-common linux-tools-$(uname -r) && \
echo "kernel.perf_event_paranoid=-1" | sudo tee -a /etc/sysctl.conf && \
echo "kernel.kptr_restrict=0" | sudo tee -a /etc/sysctl.conf && \
sudo sysctl --system && \
echo "Install perf finish!" && \

# Install Reth depedency
sudo DEBIAN_FRONTEND=noninteractive apt -yq install libclang-dev pkg-config build-essential && \
echo "Install reth depedency finish!" && \

# Install vmtouch
sudo apt -yq install vmtouch && \
echo "Install vmtouch finish!" && \

# Turn off swap
sudo swapoff -a && \
echo "Turn off swap finish!" && \

# Clone FlameGraph
git clone https://github.com/brendangregg/FlameGraph.git && \
echo "Clone FlameGraph finish!" && \

# Build Reth with maximum performance
git clone -b andy/debug/performance-dashboard https://github.com/megaeth-labs/reth.git && \
#git clone -b andy/test/latitude-test1 https://github.com/megaeth-labs/reth.git && \
pushd reth && \
RUSTFLAGS="-C target-cpu=native" cargo build --profile maxperf --features=finish_after_execution_stage && \
CARGO_BIN="$HOME/.cargo/bin/" && \
cp ./target/maxperf/reth $CARGO_BIN && \
popd && \
echo "Install reth finish!" && \

# Set datadir
echo "Using data directory: $DATADIR" && \

# Sync data to the target block 
RUST_LOG=info reth node --debug.tip $TARGET_BLOCK_HASH --datadir $DATADIR --debug.terminate > sync.log && \
echo "Sync data finish!" 

