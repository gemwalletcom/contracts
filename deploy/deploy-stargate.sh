#!/bin/bash

# Ensure Bash is used
if [ -z "$BASH_VERSION" ]; then
    echo "This script requires Bash. Please run it with bash."
    exit 1
fi

# Load environment variables
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo ".env file not found. Please create one with necessary environment variables."
    exit 1
fi

# Validate input
if [ -z "$1" ]; then
    echo "Usage: $0 <chain-name>"
    exit 1
fi

CHAIN_NAME=$1

# List of zkSync chains
ZKSYNC_CHAINS=("abstract")

# Convert chain name to lowercase
CHAIN_NAME_LOWER=$(echo "$CHAIN_NAME" | tr '[:upper:]' '[:lower:]')

# Check if chain is zkSync
if [[ " ${ZKSYNC_CHAINS[@]} " =~ " $CHAIN_NAME_LOWER " ]]; then
    echo "Deploying to zkSync chain: $CHAIN_NAME_LOWER"
    bash ./deploy/deploy-stargate-zksync.sh "$CHAIN_NAME_LOWER"
else
    echo "Deploying to non-zkSync chain: $CHAIN_NAME_LOWER"
    bash ./deploy/deploy-stargate-non-zksync.sh "$CHAIN_NAME_LOWER"
fi
