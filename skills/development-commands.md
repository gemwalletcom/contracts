# Development Commands

Use when building, testing, linting, or formatting. Deploy and verify recipes are in [Deployment](deployment.md); which checks a change needs is in [Quality Checks](quality-checks.md).

## Setup

```bash
git submodule update --init --recursive   # lib/forge-std
cp .env.example .env                      # then fill in RPC URLs; never commit or print it
foundryup -i v1.10.0                      # the Foundry version CI installs
```

Use the Foundry version pinned in [CI](../.github/workflows/ci.yml); lints and formatting differ between releases. `foundry.toml` pins the compiler (`solc`, `evm_version`, optimizer), so builds do not depend on which compilers are installed. Change those pins only as a deliberate task: they change the bytecode of the next deployment.

## Common Commands

```bash
just                    # list all recipes
forge build             # compile (just build)
forge build --sizes     # compile and print contract sizes, as CI does
forge fmt               # format; forge fmt --check to verify only
forge lint              # lint src/, script/, and test/
forge test              # every suite; HubReader fork tests are skipped without BSC_RPC_URL
just test-monad         # StakingLens tests, mocked, no RPC needed
just test-hub-reader    # HubReader tests on a BSC mainnet fork, needs BSC_RPC_URL
```

Add `-vvv` to a `forge test` run for traces of failing tests, and `--match-test <name>` to select one test.

## RPC Aliases

`foundry.toml` maps aliases (`bsc`, `monad`, `ethereum`, …) to the `*_RPC_URL` variables in `.env`, and Forge loads `.env` itself, so `--rpc-url monad` works without exporting anything. `just` also loads `.env` for its recipes.

## Caveats

- The `HubReader` suite forks BSC mainnet at the latest block in `setUp` and reports `[SKIP]` when `BSC_RPC_URL` is unset or empty. A skipped suite has not been tested.
- The fork needs an RPC that keeps recent state for the length of the run, about a minute. A node that prunes aggressively fails with `missing trie node`; that is the endpoint, not the contract.
- `No tests found in project!` after `No files changed, compilation skipped` means the build cache is stale. Rerun with `--force`. Avoid `forge clean`: it deletes `cache/`, which also holds deployment run records.
- `via_ir = true` makes a full rebuild slow.
- `[profile.ci]` is empty and inherits the default profile; CI selects it with `FOUNDRY_PROFILE=ci`.
- `forge lint` exits zero on warnings. `calls-loop` is excluded in `foundry.toml` because a batching lens calls in loops by design; read the remaining warnings for the lines you changed.
