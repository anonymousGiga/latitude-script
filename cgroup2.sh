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
# 用cgroup限制内存的设置
##########################################################################

# 设置swap的优先级
sudo sh -c "echo $SWAPNESS > /proc/sys/vm/swappiness"

# 检查 cgroup 目录是否已存在，如果不存在则创建
if [ ! -d "$CGROUP_DIR1" ]; then
    # 创建 cgroup 目录
    sudo mkdir -p "$CGROUP_DIR1"
fi


# 检查 cgroup 文件系统是否已挂载
if ! mountpoint -q /sys/fs/cgroup/unified; then
    # 挂载 cgroup 文件系统
    sudo mount -t cgroup2 none /sys/fs/cgroup/unified -o rw
fi

# 检查 cgroup 目录是否已存在，如果不存在则创建
if [ ! -d "$CGROUP_DIR2" ]; then
    # 创建 cgroup 目录
    sudo mkdir -p "$CGROUP_DIR2"
fi

# 设置内存限制
sudo sh -c "echo $SWAP_MEMORY_LIMIT > $CGROUP_DIR2/memory.swap.max"
sudo sh -c "echo $MEMORY_LIMIT > $CGROUP_DIR2/memory.high"


##########################################################################
# 实验1
##########################################################################
# 编译Reth
pushd reth && \
RUSTFLAGS="-C target-cpu=native" cargo build --profile maxperf --features=enable_cache_record,enable_execution_duration_record,finish_after_execution_stage,enable_tps_gas_record,enable_db_speed_record,enable_execute_measure,enable_write_to_db_measure && \
CARGO_BIN="$HOME/.cargo/bin/" && \
cp ./target/maxperf/reth $CARGO_BIN && \
popd && \
echo "Install reth finish!" && \
reth --version && \


# 删除历史数据
RUST_LOG=info reth stage drop execution --datadir $DATADIR  && \
RUST_LOG=info reth stage drop account-hashing --datadir $DATADIR  && \
RUST_LOG=info reth stage drop storage-hashing --datadir $DATADIR  && \
RUST_LOG=info reth stage drop merkle --datadir $DATADIR && \
RUST_LOG=info reth stage drop tx-lookup --datadir $DATADIR && \
RUST_LOG=info reth stage drop account-history --datadir $DATADIR && \
RUST_LOG=info reth stage drop storage-history --datadir $DATADIR && \
vmtouch -e $DATADIR && \

# 启动 reth 进程并获取其id
RUST_LOG=info reth node --debug.max-block $TARGET_NUMBER --datadir $DATADIR --config ./max.toml --debug.terminate -d > all_log &
RETH_PID=$! 

# 将 reth 的 PID 添加到 cgroup
RETH_PROCESS_DIR="$CGROUP_DIR2/my_process5"
if [ ! -d "$RETH_PROCESS_DIR" ]; then
    sudo mkdir "$RETH_PROCESS_DIR"
fi
sudo sh -c "echo $RETH_PID > $RETH_PROCESS_DIR/cgroup.procs"

# 等待 reth 进程执行结束
wait $RETH_PID

##########################################################################
# 实验2: opcode
##########################################################################
# 编译Reth
pushd reth && \
RUSTFLAGS="-C target-cpu=native" cargo build --profile maxperf --features=finish_after_execution_stage,enable_opcode_metrics && \
CARGO_BIN="$HOME/.cargo/bin/" && \
cp ./target/maxperf/reth $CARGO_BIN && \
popd && \
echo "Install reth finish!" && \
reth --version && \


# 删除历史数据
RUST_LOG=info reth stage drop execution --datadir $DATADIR  && \
RUST_LOG=info reth stage drop account-hashing --datadir $DATADIR  && \
RUST_LOG=info reth stage drop storage-hashing --datadir $DATADIR  && \
RUST_LOG=info reth stage drop merkle --datadir $DATADIR && \
RUST_LOG=info reth stage drop tx-lookup --datadir $DATADIR && \
RUST_LOG=info reth stage drop account-history --datadir $DATADIR && \
RUST_LOG=info reth stage drop storage-history --datadir $DATADIR && \
vmtouch -e $DATADIR && \

# 启动 reth 进程并获取其id
RUST_LOG=info reth node --debug.max-block $TARGET_NUMBER --datadir $DATADIR --config ./max.toml --debug.terminate -d > opcode_record.log &
RETH_PID=$!

# 将 reth 的 PID 添加到 cgroup
RETH_PROCESS_DIR="$CGROUP_DIR2/my_process5"
if [ ! -d "$RETH_PROCESS_DIR" ]; then
    sudo mkdir "$RETH_PROCESS_DIR"
fi
sudo sh -c "echo $RETH_PID > $RETH_PROCESS_DIR/cgroup.procs"

# 等待 reth 进程执行结束
wait $RETH_PID

##########################################################################
# 结束
##########################################################################

# 检查是否需要卸载 cgroup 文件系统
if mountpoint -q /sys/fs/cgroup/unified; then
    # 卸载 cgroup 文件系统
    sudo umount /sys/fs/cgroup/unified
fi
