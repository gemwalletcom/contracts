set dotenv-load := true


build:
    forge build

test:
    forge test

deploy-stargate CHAIN_NAME:
    bash ./deploy/deploy-stargate.sh {{CHAIN_NAME}}

deploy-hub-reader:
    forge script script/hub_reader/HubReader.s.sol:HubReaderScript --rpc-url "$BSC_RPC_URL" --broadcast --verify -vvvv
