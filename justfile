set dotenv-load := true

list:
    just --list

build:
    forge build

build-monad:
    forge build --contracts src/monad/StakingLens.sol

test:
    forge test

test-monad:
    forge test --match-path test/monad/*

deploy-stargate CHAIN_NAME:
    bash ./deploy/deploy-stargate.sh {{CHAIN_NAME}}

deploy-hub-reader:
    forge script script/hub_reader/HubReader.s.sol:HubReaderScript --rpc-url "$BSC_RPC_URL" --broadcast --verify -vvvv

deploy-monad-staking:
    forge script --force script/monad/StakingLens.s.sol:StakingLensScript --rpc-url "$MONAD_RPC_URL" --broadcast -vvvv

read-staking-lens-address BROADCAST_FILE="broadcast/StakingLens.s.sol/143/run-latest.json":
    #!/usr/bin/env bash
    jq -r '.receipts[]?.contractAddress // empty' "{{BROADCAST_FILE}}"

verify-monad-staking ADDRESS: build-monad
    forge verify-contract \
        --rpc-url https://rpc.monad.xyz \
        --verifier sourcify \
        --verifier-url 'https://sourcify-api-monad.blockvision.org/' \
        --chain-id 143 \
        "{{ADDRESS}}" \
        src/monad/StakingLens.sol:StakingLens

verify-monad-staking-etherscan ADDRESS: build-monad
    [ -n "${ETHERSCAN_API_KEY-}" ] || { echo "ETHERSCAN_API_KEY is required" >&2; exit 1; }
    forge verify-contract \
        --verifier custom \
        --verifier-url 'https://api.etherscan.io/v2/api?chainid=143' \
        --verifier-api-key "$ETHERSCAN_API_KEY" \
        --chain 143 \
        --rpc-url https://rpc.monad.xyz \
        "{{ADDRESS}}" \
        src/monad/StakingLens.sol:StakingLens
