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

# Validate private key
if [ -z "$PRIVATE_KEY" ]; then
    echo "Missing PRIVATE_KEY. Exiting."
    exit 1
fi

# zkSync chain list
ZKSYNC_CHAIN_IDS=("2741:abstract")

# Deployment script
SCRIPT_CONTRACT_NAME="GemStargateDeployerScript"

# Chain name passed as an argument
TARGET_CHAIN=$1

for CHAIN in "${ZKSYNC_CHAIN_IDS[@]}"; do
    CHAIN_ID="${CHAIN%%:*}"
    NETWORK_NAME="${CHAIN##*:}"

    # Skip if specific chain is provided and doesn't match
    if [ -n "$TARGET_CHAIN" ] && [ "$NETWORK_NAME" != "$TARGET_CHAIN" ]; then
        continue
    fi

    # Convert network name to uppercase
    NETWORK_NAME_UPPER=$(echo "$NETWORK_NAME" | tr '[:lower:]' '[:upper:]')

    RPC_URL_VAR="${NETWORK_NAME_UPPER}_RPC_URL"
    ENDPOINT_VAR="STARGATE_ENDPOINT_${NETWORK_NAME_UPPER}"
    ETHERSCAN_API_KEY_VAR="${NETWORK_NAME_UPPER}_SCAN_API_KEY"

    RPC_URL=$(eval echo "\$$RPC_URL_VAR")
    STARGATE_ENDPOINT=$(eval echo "\$$ENDPOINT_VAR")
    ETHERSCAN_API_KEY=$(eval echo "\$$ETHERSCAN_API_KEY_VAR")

    echo "Deploying to zkSync chain: $NETWORK_NAME (Chain ID: $CHAIN_ID)"

    if [ -z "$RPC_URL" ] || [ -z "$STARGATE_ENDPOINT" ] || [ -z "$ETHERSCAN_API_KEY" ]; then
        echo "Missing required environment variables for $NETWORK_NAME. Skipping..."
        continue
    fi

    echo "🔍 Estimating Gas for Deployment..."
    # Estimate Gas Usage for Constructor
    GAS_ESTIMATE=$(cast estimate --rpc-url "$RPC_URL" \
        --private-key "$PRIVATE_KEY" \
        0x0000000000000000000000000000000000000000 \
        "StargateFeeReceiver.constructor(address)" \
        "$STARGATE_ENDPOINT")

    if [[ -z "$GAS_ESTIMATE" ]] || [[ "$GAS_ESTIMATE" == "infinite" ]]; then
        echo "⚠️  Gas estimation failed. Setting fallback gas limit of 3,000,000."
        GAS_ESTIMATE=3000000
    else
        # Apply a 30% buffer for safety
        GAS_ESTIMATE=$(( GAS_ESTIMATE + (GAS_ESTIMATE / 3) ))
        
        # Ensure a reasonable minimum
        if [[ "$GAS_ESTIMATE" -lt 3000000 ]]; then
            GAS_ESTIMATE=3000000
        fi
    fi

    echo "✅ Final Gas Limit: $GAS_ESTIMATE"

    # Check deployer's balance
    DEPLOYER_BALANCE=$(cast balance $(cast wallet address --private-key "$PRIVATE_KEY") --rpc-url "$RPC_URL")
    echo "💰 Deployer Balance: $DEPLOYER_BALANCE ETH"

    if [[ "$DEPLOYER_BALANCE" -lt 0.01 ]]; then
        echo "❌ Insufficient ETH balance for deployment. Exiting."
        exit 1
    fi

    # Optimize Solidity Bytecode
    echo "⚡ Optimizing Solidity Bytecode..."
    forge build --optimize --optimizer-runs 200

    echo "🚀 Starting Deployment..."
    
    # Run deployment with optimized gas settings
    forge script "$SCRIPT_CONTRACT_NAME" \
        --rpc-url "$RPC_URL" \
        --chain-id "$CHAIN_ID" \
        --etherscan-api-key "$ETHERSCAN_API_KEY" \
        --broadcast \
        --verify \
        --gas-limit $GAS_ESTIMATE \
        --gas-price 200000000 \
        -vvvv \
        --zksync 

    echo "✅ Deployment to $NETWORK_NAME completed."
done

echo "🎉 All zkSync deployments done!"
