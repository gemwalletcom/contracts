# Smart Contracts

Gem Wallet deployment helpers and read lenses.

- `src/hub_reader`: BSC staking hub reader.
- `src/stargate`: post-bridge call handler for Stargate V2.
- `src/monad`: staking lens for Monad (precompile reader).

## Development

1) Install [Foundry](https://book.getfoundry.sh/).
2) Copy `.env.example` to `.env` and fill RPCs (including `MONAD_RPC_URL`), explorer keys, and `PRIVATE_KEY` for deploys.

## Common Tasks

- Build: `forge build`
- Lint/format: `forge lint && forge fmt`
- Test: `forge test` (HubReader tests expect a live BSC RPC; the Monad lens tests are mocked)

## Deploy

- Hub Reader (BSC): `just deploy-hub-reader`
- Stargate fee receiver: `just deploy-stargate optimism` (or another supported chain)
- Monad staking lens: `just deploy-monad-staking`

## Deployments

- Hub Reader (BSC): [0x830295c0abe7358f7e24bc38408095621474280b](https://bscscan.com/address/0x830295c0abe7358f7e24bc38408095621474280b)
- Monad Staking Lens: [0x1c5C7645daB3A1642048AF96FACE6be29952CbF9](https://monadvision.com/address/0x1c5C7645daB3A1642048AF96FACE6be29952CbF9?tab=Contract)

