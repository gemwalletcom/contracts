#!/bin/bash

# Ensure the script runs in Bash
if [ -z "$BASH_VERSION" ]; then
    echo "This script requires Bash. Please run it with bash."
    exit 1
fi

# Load environment variables from .env
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo ".env file not found. Please create one with necessary environment variables."
    exit 1
fi

# List of chains with their network names and chain IDs
CHAIN_IDS=("1:ethereum" "10:optimism" "8453:base" "56:bsc" "43114:avalanche" "137:polygon" "42161:arbitrum")

# Deployment script path
SCRIPT_PATH="../script/stargate/GemStargateDeployerScript.s.sol"
SCRIPT_CONTRACT_NAME="GemStargateDeployerScript"

# Chain name passed as the first argument
TARGET_CHAIN=$1

PRIVATE_KEY=${PRIVATE_KEY}

if [ -z "$PRIVATE_KEY" ]; then
        echo "Missing PRIVATE_KEY. Skipping..."
        continue
fi


# Deploy to each chain
for CHAIN in "${CHAIN_IDS[@]}"; do
    CHAIN_ID=$(echo $CHAIN | cut -d':' -f1)
    NETWORK_NAME=$(echo $CHAIN | cut -d':' -f2)

    # Skip chains if a specific chain name is provided
    if [ -n "$TARGET_CHAIN" ] && [ "$NETWORK_NAME" != "$TARGET_CHAIN" ]; then
        continue
    fi

     # Transform the network name to uppercase
    NETWORK_NAME=$(echo "$NETWORK_NAME" | tr '[:lower:]' '[:upper:]')

    RPC_URL_VAR="${NETWORK_NAME}_RPC_URL"
    ENDPOINT_VAR="STARGATE_ENDPOINT_${NETWORK_NAME}"
    ETHERSCAN_API_KEY_NAME="${NETWORK_NAME}_SCAN_API_KEY"

    RPC_URL=$(eval echo "\$$RPC_URL_VAR")
    ENDPOINT=$(eval echo "\$$ENDPOINT_VAR")
    ETHERSCAN_API_KEY=$(eval echo "\$$ETHERSCAN_API_KEY_NAME")

    echo "----------------------------------------"
    echo "Deploying to $NETWORK_NAME (Chain ID: $CHAIN_ID)"
    echo "RPC URL: $RPC_URL"
    echo "Endpoint: $ENDPOINT"

    if [ -z "$RPC_URL" ]; then
        echo "Missing RPC_URL for $NETWORK_NAME. Skipping..."
        continue
    fi


    if [ -z "$ENDPOINT" ]; then
        echo "Missing ENDPOINT for $NETWORK_NAME. Skipping..."
        continue
    fi

    if [ -z "$ETHERSCAN_API_KEY" ]; then
        echo "Missing ETHERSCAN_API_KEY for $NETWORK_NAME. Skipping..."
        continue
    fi

    # Run the deployment
    forge script GemStargateDeployerScript \
        --rpc-url "$RPC_URL" \
        --chain-id "$CHAIN_ID" \
        --etherscan-api-key "$ETHERSCAN_API_KEY" \
        --broadcast --verify -vvvv
    
    echo "Deployment to $NETWORK_NAME completed."
done

echo "All deployments are done!"
