# Smart Contracts

Gem Wallet deployment helpers and read lenses.

- `src/hub_reader`: BSC staking hub reader.
- `src/monad`: staking lens for Monad (precompile reader).

## Development

1) Install [Foundry](https://book.getfoundry.sh/).
2) Run `git submodule update --init --recursive`.
3) Copy `.env.example` to `.env` and fill RPCs (including `MONAD_RPC_URL`) and explorer keys.
4) For deploys, import the deployer into an encrypted keystore with `cast wallet import deployer --interactive` and set `DEPLOYER_ACCOUNT` to its name. No private key goes in `.env`.

## Common Tasks

- Build: `forge build`
- Lint/format: `forge lint && forge fmt`
- Test: `forge test` (the Monad lens tests are mocked; the HubReader tests fork BSC mainnet and are skipped unless `BSC_RPC_URL` is set)

## Deploy

- Hub Reader (BSC): `just deploy-hub-reader`
- Monad staking lens: `just deploy-monad-staking`

## Deployments

- Hub Reader (BSC): [0x830295c0abe7358f7e24bc38408095621474280b](https://bscscan.com/address/0x830295c0abe7358f7e24bc38408095621474280b)
- Monad Staking Lens: [0x7f58550601A50BA6731EbE6b8Ad1c49bc42b0BE8](https://monadvision.com/address/0x7f58550601A50BA6731EbE6b8Ad1c49bc42b0BE8?tab=Contract)
