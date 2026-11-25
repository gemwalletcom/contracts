# Project Overview

Use when you need the repo layout, what a contract reads, where it is deployed, or who calls it.

This repository holds Gem Wallet's on-chain read lenses: small, stateless contracts that batch staking reads into one `eth_call` so the wallet does not make one RPC request per validator. They hold no funds and have no owner or upgrade path. It is a [Foundry](https://book.getfoundry.sh/) project.

```
contracts/
├── src/
│   ├── hub_reader/   # HubReader: BNB Smart Chain staking reads
│   └── monad/        # StakingLens: Monad staking precompile reads
├── script/           # Foundry deploy scripts, one per contract
├── test/             # *.t.sol, mirroring src/
├── lib/              # git submodule: forge-std, pinned to a release tag
├── foundry.toml      # compiler pin, lint config, and RPC aliases
├── remappings.txt
└── justfile          # build, test, deploy, and verify recipes
```

`out/`, `cache/`, `broadcast/`, `docs/`, and `.env` are ignored by git.

## Contracts

| Contract | Chain | Reads | Entry points |
|---|---|---|---|
| [`HubReader`](../src/hub_reader/HubReader.sol) | BNB Smart Chain (56) | `StakeHub` system contract at `0x…2002` and each validator's `StakeCredit` contract | `getValidators`, `getDelegations`, `getUndelegations`, `getAPYs` |
| [`StakingLens`](../src/monad/StakingLens.sol) | Monad (143) | Staking precompile at `0x…1000` through [`IStaking`](../src/monad/IStaking.sol) | `getBalance`, `getDelegations`, `getValidators`, `getAPYs` |

- `HubReader` functions are `view` and paginate with `offset` and `limit` over the validator list; the caller chooses the page size.
- `StakingLens` functions are not `view` because the precompile interface is not; callers still use `eth_call`. Its loops are bounded by the `MAX_*` and `ACTIVE_VALIDATOR_SET` constants, and returned arrays are trimmed in place with `mstore`.
- APYs are returned in basis points. `StakingLens` derives them from protocol constants (`MONAD_BLOCK_REWARD`, `MONAD_BLOCKS_PER_YEAR`); `HubReader` derives them from the hub's daily reward records.
- The contracts have no library dependencies; `forge-std` is used only by scripts and tests.

## Deployments

The [README](../README.md#deployments) is the record of deployed addresses. Each deployment is immutable: a fix means a new deployment at a new address.

## Consumers

Gem Wallet Core, in the `core/` directory of [gemwalletcom/wallet](https://github.com/gemwalletcom/wallet), calls these contracts and pins both the address and the ABI:

| Contract | Address constant | ABI and decoding |
|---|---|---|
| `HubReader` | `HUB_READER_ADDRESS` in `crates/gem_bsc/src/constants.rs` | `crates/gem_bsc/src/contracts.rs`, `encode.rs` |
| `StakingLens` | `MONAD_STAKING_LENS_CONTRACT` in `crates/primitives/src/contract_constants.rs` | `crates/gem_monad/src/contracts.rs`, `encode.rs` |

Function names, argument types, struct field order and types, and enum member order are the wire contract. Released app versions keep calling the address they shipped with, so an existing deployment must keep working for them; a new ABI ships as a new deployment that Core adopts in its own change.
