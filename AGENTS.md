# Repository Guidelines

## Project Structure & Module Organization
- Core Solidity modules live in `src/`, split into `src/hub_reader` and `src/stargate` for BSC staking and cross-chain calls.
- Automation scripts reside in `script/` (Foundry) and `deploy/` (bash helpers like `deploy-stargate.sh`); compiled artifacts land in `out/`.
- Tests live in `test/` using `.t.sol` suffixes; dependencies stay in `lib/`; align configuration via root-level `foundry.toml` and `.env.example`.

## Build, Test, and Development Commands
- `forge build` or `just build` compiles the workspace with default remappings.
- `forge test` and `forge test --rpc-url $BSC_RPC_URL` execute the suite locally or against a fork.
- `forge lint` then `forge fmt` keep Solidity style consistent; run them before sharing branches.
- `just deploy-hub-reader` and `just deploy-stargate optimism` broadcast deployments through the prewired RPCs.

## Coding Style & Naming Conventions
- Use 4-space indentation, `pragma solidity ^0.8.x`, sorted imports, and SPDX identifiers.
- Name contracts, libraries, and interfaces in PascalCase; state variables in camelCase; constants in ALL_CAPS.
- Match test filenames to their targets (`StargateFeeReceiver.t.sol`) and prefix helper contracts with `Test`.
- Validate formatting with `forge fmt` or `forge fmt --check` before review.

## Testing Guidelines
- Keep integration scenarios in dedicated contracts and isolate unit fixtures per module.
- Leverage `vm.expectRevert`, `vm.prank`, and explicit `assertEq` messages to clarify intent.
- When forking, pass the RPC with `--rpc-url` and note chain assumptions in header comments.
- Prioritize coverage of deposit, withdrawal, and fee flows; `forge coverage --report lcov` helps quantify readiness.

## Commit & Pull Request Guidelines
- Follow the short imperative style seen in history (`add auto formatter`, `rename to StargateFeeReceiver`), keeping summaries under 65 characters.
- Reference tickets, flag deployment or configuration impacts, and list the tests you ran.
- For PRs, link on-chain transactions, attach explorer URLs or calldata, and note any environment variable or RPC updates.

## Security & Configuration Tips
- Copy `.env.example` to `.env`, add RPC URLs and scan keys matching `foundry.toml`, and keep secrets untracked.
- Limit raw private keys to deployment contexts; favor hardware signing for `forge script --broadcast`.
- Before merging, confirm remappings, target chain IDs, and contract addresses to avoid cross-chain leaks.
