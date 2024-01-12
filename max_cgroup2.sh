# This script uses cgroup to measure the various metrics of reth under 
# different memory limits. When running reth in this script, use an 
# max batch threshold.

#!/bin/bash

CGROUP_DIR1="/sys/fs/cgroup/unified"
CGROUP_DIR2="/sys/fs/cgroup/unified/my_memory_limit"
#MEMORY_LIMIT="100M"
MEMORY_LIMIT="2G"
SWAP_MEMORY_LIMIT="100G"
#SWAPNESS="10"
SWAPNESS="60"

#DATADIR="/nvme2/reth_data"
DATADIR="/home/andy/.local/share/reth/mainnet"
TARGET_NUMBER=50000 

##########################################################################
# Memory limit using cgroup configuration
##########################################################################

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


##########################################################################
# Experiment 1
##########################################################################
# Compile Reth
pushd reth && \
RUSTFLAGS="-C target-cpu=native" cargo build --profile maxperf --features=enable_cache_record,enable_execution_duration_record,finish_after_execution_stage,enable_tps_gas_record,enable_db_speed_record,enable_execute_measure,enable_write_to_db_measure && \
CARGO_BIN="$HOME/.cargo/bin/" && \
cp ./target/maxperf/reth $CARGO_BIN && \
popd && \
echo "Install reth finish!" && \
reth --version && \

# Delete historical data
RUST_LOG=info reth stage drop execution --datadir $DATADIR  && \
RUST_LOG=info reth stage drop account-hashing --datadir $DATADIR  && \
RUST_LOG=info reth stage drop storage-hashing --datadir $DATADIR  && \
RUST_LOG=info reth stage drop merkle --datadir $DATADIR && \
RUST_LOG=info reth stage drop tx-lookup --datadir $DATADIR && \
RUST_LOG=info reth stage drop account-history --datadir $DATADIR && \
RUST_LOG=info reth stage drop storage-history --datadir $DATADIR && \
vmtouch -e $DATADIR && \

# Start the reth process and get its ID
RUST_LOG=info reth node --debug.max-block $TARGET_NUMBER --datadir $DATADIR --config ./max.toml --debug.terminate -d > all_log &
RETH_PID=$! 

# Add the reth PID to the cgroup
RETH_PROCESS_DIR="$CGROUP_DIR2/my_process5"
if [ ! -d "$RETH_PROCESS_DIR" ]; then
    sudo mkdir "$RETH_PROCESS_DIR"
fi
sudo sh -c "echo $RETH_PID > $RETH_PROCESS_DIR/cgroup.procs"

# Wait for the reth process to finish execution
wait $RETH_PID

##########################################################################
# Experiment 2: opcode
##########################################################################
# Compile Reth
pushd reth && \
RUSTFLAGS="-C target-cpu=native" cargo build --profile maxperf --features=finish_after_execution_stage,enable_opcode_metrics && \
CARGO_BIN="$HOME/.cargo/bin/" && \
cp ./target/maxperf/reth $CARGO_BIN && \
popd && \
echo "Install reth finish!" && \
reth --version && \

# Delete historical data
RUST_LOG=info reth stage drop execution --datadir $DATADIR  && \
RUST_LOG=info reth stage drop account-hashing --datadir $DATADIR  && \
RUST_LOG=info reth stage drop storage-hashing --datadir $DATADIR  && \
RUST_LOG=info reth stage drop merkle --datadir $DATADIR && \
RUST_LOG=info reth stage drop tx-lookup --datadir $DATADIR && \
RUST_LOG=info reth stage drop account-history --datadir $DATADIR && \
RUST_LOG=info reth stage drop storage-history --datadir $DATADIR && \
vmtouch -e $DATADIR && \

# Start the reth process and get its ID
RUST_LOG=info reth node --debug.max-block $TARGET_NUMBER --datadir $DATADIR --config ./max.toml --debug.terminate -d > opcode_record.log &
RETH_PID=$!

# Add the reth PID to the cgroup
RETH_PROCESS_DIR="$CGROUP_DIR2/my_process5"
if [ ! -d "$RETH_PROCESS_DIR" ]; then
    sudo mkdir "$RETH_PROCESS_DIR"
fi
sudo sh -c "echo $RETH_PID > $RETH_PROCESS_DIR/cgroup.procs"

# Wait for the reth process to finish execution
wait $RETH_PID

##########################################################################
# end 
##########################################################################

# Check if the cgroup filesystem needs to be unmounted
if mountpoint -q /sys/fs/cgroup/unified; then
    # Unmount the cgroup filesystem
    sudo umount /sys/fs/cgroup/unified
fi
