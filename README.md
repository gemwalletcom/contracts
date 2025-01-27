# Smart Contracts

A collection of smart contracts for Gem Wallet.

- [bsc/hub_reader](bsc/hub_reader): A contract that simplify interacting with BSC Staking Hub

## Development

1. Install [Foundry](https://book.getfoundry.sh/) and you're good to go.
2. Configure `.env` using `.env.example` rpcs (if needed) and etherscan values, if you need to deploy the contract, you need to set `PRIVATE_KEY` as well.

## Usage

### Build

```shell
forge build
```

### Test

```shell
forge test --rpc-url <your_rpc_url>
```

### Deploy

```shell
# deploy hub_reader
just deploy-hub-reader
```

```shell
# deploy stargate to all supported chains
just deploy-stargate
```

```shell
# deploy stargate to specific chain
just deploy-stargate optimism
```





