# Smart Contracts

Gem Wallet deployment helpers and read lenses.

- `src/hub_reader`: BSC staking hub reader.
- `src/stargate`: post-bridge call handler for Stargate V2.
- `src/monad`: staking lens for Monad (precompile reader).

## Development

1) Install [Foundry](https://book.getfoundry.sh/).
2) Copy `.env.example` to `.env` and fill RPCs (including `MONAD_RPC_URL`), scan keys, and `PRIVATE_KEY` for deploys.

## Common Tasks

- Build: `forge build`
- Lint/format: `forge lint && forge fmt`
- Test: `forge test` (HubReader tests expect a live BSC RPC; the Monad lens tests are mocked)

## Deploy

- Hub Reader (BSC): `just deploy-hub-reader`
- Stargate fee receiver: `just deploy-stargate optimism` (or another supported chain)
- Monad staking lens: `just deploy-monad-staking`




