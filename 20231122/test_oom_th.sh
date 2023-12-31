#!/bin/bash

#############################################################
#
# This script for get oom th
#
#############################################################

# Default values
DEFAULT_DATADIR="/home/ubuntu/data"
# 18m
DEFAULT_TARGET_NUMBER=18000000



#############################################################
#
#  get args
#
#############################################################

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        -datadir)
        DATADIR="$2"
        shift
        shift
        ;;
        -target_number)
        TARGET_NUMBER="$2"
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

if [ -z "$TARGET_NUMBER" ]; then
    TARGET_NUMBER="$DEFAULT_TARGET_NUMBER"
fi

# Check if the parameters are empty
if [ -z "$DATADIR" ] || [ -z "$TARGET_NUMBER" ]; then
    echo "USAGE: ./revm_measure1.sh -datadir DATADIR -target_number TARGET_NUMBER"
    exit 1
fi

echo "Data directory is: $DATADIR"
echo "Target block number is: $TARGET_NUMBER"

#############################################################
# Build with enable_test_max_th 
pushd reth && \
RUSTFLAGS="-C target-cpu=native" cargo build --profile maxperf --features=finish_after_execution_stage,enable_test_max_th,enable_cache_record && \
CARGO_BIN="$HOME/.cargo/bin/" && \
cp ./target/maxperf/reth $CARGO_BIN && \
popd && \
echo "Install reth finish!" && \
reth --version && \

# Clear data
RUST_LOG=info reth stage drop execution --datadir $DATADIR  && \
RUST_LOG=info reth stage drop account-hashing --datadir $DATADIR  && \
RUST_LOG=info reth stage drop storage-hashing --datadir $DATADIR  && \
RUST_LOG=info reth stage drop merkle --datadir $DATADIR && \
RUST_LOG=info reth stage drop tx-lookup --datadir $DATADIR && \
RUST_LOG=info reth stage drop account-history --datadir $DATADIR && \
RUST_LOG=info reth stage drop storage-history --datadir $DATADIR && \
#vmtouch -e $DATADIR && \

# Run reth with default Th.
RUST_LOG=info reth stage run execution --from 0 --to $TARGET_NUMBER  --datadir $DATADIR > oom_th_log
