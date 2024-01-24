#!/bin/bash

# This script uses cgroup to measure the various metrics of reth under 
# different memory limits. When running reth in this script, use an 
# max batch threshold.
CGROUP_DIR1="/sys/fs/cgroup/unified"
CGROUP_DIR2="/sys/fs/cgroup/unified/my_memory_limit"
MEMORY_LIMIT="32G"
SWAP_MEMORY_LIMIT="128G"
SWAPNESS="10"
#SWAPNESS="60"
DATADIR="/nvme2/reth_data"
TARGET_NUMBER=18000000 

##########################################################################
# Memory limit using cgroup configuration
##########################################################################
sudo swapon -a

# Set the swappiness priority
sudo sh -c "echo $SWAPNESS > /proc/sys/vm/swappiness"

# Check if the cgroup directory exists, if not, create it
if [ ! -d "$CGROUP_DIR1" ]; then
    # Create the cgroup directory
    sudo mkdir -p "$CGROUP_DIR1"
fi

# Check if the cgroup filesystem is mounted
if ! mountpoint -q /sys/fs/cgroup/unified; then
    # 挂载 cgroup 文件系统
    sudo mount -t cgroup2 none /sys/fs/cgroup/unified -o rw
fi

# Check if the cgroup directory2 exists, if not, create it
if [ ! -d "$CGROUP_DIR2" ]; then
    # Create the cgroup directory2
    sudo mkdir -p "$CGROUP_DIR2"
fi

# Set memory limits
sudo sh -c "echo $SWAP_MEMORY_LIMIT > $CGROUP_DIR2/memory.swap.max"
sudo sh -c "echo $MEMORY_LIMIT > $CGROUP_DIR2/memory.high"

# Compile Reth
pushd reth && \
RUSTFLAGS="-C target-cpu=native" cargo build --profile maxperf --features=enable_cache_record,enable_execution_duration_record,finish_after_execution_stage,enable_tps_gas_record,enable_db_speed_record,enable_execute_measure,enable_write_to_db_measure && \
CARGO_BIN="$HOME/.cargo/bin/" && \
cp ./target/maxperf/reth $CARGO_BIN && \
popd && \
echo "Install reth finish!" && \

##########################################################################
# Experiment 1
##########################################################################
reth --version && \

vmtouch -e $DATADIR && \

# Start the reth process and get its ID
RUST_LOG=info reth node --debug.max-block $TARGET_NUMBER --datadir $DATADIR --config ./max.toml --debug.terminate -d > all_log1 & 
RETH_PID=$! 

# Add the reth PID to the cgroup
RETH_PROCESS_DIR="$CGROUP_DIR2/my_process"
if [ ! -d "$RETH_PROCESS_DIR" ]; then
    sudo mkdir "$RETH_PROCESS_DIR"
fi
sudo sh -c "echo $RETH_PID > $RETH_PROCESS_DIR/cgroup.procs"

# Wait for the reth process to finish execution
wait $RETH_PID && \

##########################################################################
# end 
##########################################################################

# Check if the cgroup filesystem needs to be unmounted
if mountpoint -q /sys/fs/cgroup/unified; then
    # Unmount the cgroup filesystem
    sudo umount /sys/fs/cgroup/unified
fi

