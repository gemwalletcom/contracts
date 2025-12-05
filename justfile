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

verify-monad-staking: build-monad
    forge verify-contract \
        --rpc-url https://rpc.monad.xyz \
        --verifier sourcify \
        --verifier-url 'https://sourcify-api-monad.blockvision.org/' \
        --chain-id 143 \
        0x1c5C7645daB3A1642048AF96FACE6be29952CbF9 \
        src/monad/StakingLens.sol:StakingLens

verify-monad-staking-etherscan: build-monad
    [ -n "${ETHERSCAN_API_KEY-}" ] || { echo "ETHERSCAN_API_KEY is required" >&2; exit 1; }
    forge verify-contract \
        --verifier etherscan \
        --verifier-url 'https://api.etherscan.io/v2/api?chainid=143' \
        --chain 143 \
        --rpc-url https://rpc.monad.xyz \
        --etherscan-api-key "$ETHERSCAN_API_KEY" \
        0x1c5C7645daB3A1642048AF96FACE6be29952CbF9 \
        src/monad/StakingLens.sol:StakingLens
