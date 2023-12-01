#!/bin/bash

#############################################################
#
# This script performs three experiments as follows: 
#     1. Collecting data with "features=enable_opcode_metrics ".
#
#############################################################

# Default values
DEFAULT_DATADIR="/home/ubuntu/data"
DEFAULT_TARGET_NUMBER=18000000
DEFAULT_MIDDLE_NUMBER=17000000

##############################################################
##
##  get args
##
##############################################################

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
        -middle_number)
        MIDDLE_NUMBER="$2"
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

if [ -z "$MIDDLE_NUMBER" ]; then
    MIDDLE_NUMBER="$DEFAULT_MIDDLE_NUMBER"
fi

# Check if the parameters are empty
if [ -z "$DATADIR" ] || [ -z "$TARGET_NUMBER" ] || [ -z "$MIDDLE_NUMBER" ]; then
    echo "USAGE: ./perf_record.sh -datadir DATADIR -target_number TARGET_NUMBER -middle_number MIDDLE_NUMBER"
    exit 1
fi

echo "Data directory is: $DATADIR"
echo "Target block number is: $TARGET_NUMBER"
echo "Middle block number is: $MIDDLE_NUMBER"

#############################################################
#
#  1. Run with features: enable_opcode_metrics.
#
#############################################################
pushd reth && \
RUSTFLAGS="-C target-cpu=native" cargo build --profile maxperf --features=finish_after_execution_stage,enable_opcode_metrics && \
CARGO_BIN="$HOME/.cargo/bin/" && \
cp ./target/maxperf/reth $CARGO_BIN && \
popd && \
echo "Install reth finish!" && \
reth --version && \


vmtouch -e $DATADIR && \

RUST_LOG=info reth stage run execution --from $MIDDLE_NUMBER --to $TARGET_NUMBER --datadir $DATADIR  > op.log

