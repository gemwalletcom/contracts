# Smart Contracts

## Component

- [bsc/hub_reader](bsc/hub_reader): A contract that simplify interacting with BSC Staking Hub

## Development

1. Install [Foundry](https://book.getfoundry.sh/) and you're good to go.
2. Configure `.env` file with your `BSC_RPC_URL` and `BSCSCAN_API_KEY`

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
forge script script/HubReader.s.sol:HubReaderScript --rpc-url "$BSC_RPC_URL" --broadcast --verify -vvvv
```
