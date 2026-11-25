# Quality Checks

Use narrow checks while iterating, then the closing matrix once the change is stable. Commands and their caveats are explained in [Development Commands](development-commands.md).

Local checks are the gate. [CI](../.github/workflows/ci.yml) runs lint, build, the format check, and `forge test`, but it has no `BSC_RPC_URL`, so the `HubReader` fork tests are skipped there.

Confirm that filters selected the intended tests: zero selected tests is not a pass.

## Iteration Matrix

| Change Type | Inner Loop Checks |
|---|---|
| `src/monad` or `test/monad` | `just test-monad` |
| `src/hub_reader` or `test/hub_reader` | `just test-hub-reader` |
| `script/` | `forge build` |

## Closing Matrix

| Change Type | Minimum Closing Checks |
|---|---|
| Any Solidity change | `forge fmt`<br>`forge lint`, with no new warning on changed lines<br>`forge build --sizes`<br>`forge test` with `BSC_RPC_URL` set, so no suite is skipped |
| External signature, returned struct, or enum change | The row above<br>`forge inspect <Contract> abi` compared with the base revision<br>Name the [Core files](project-overview.md#consumers) that must change |
| `script/`, `justfile`, or `foundry.toml` | `forge build --sizes`<br>`just --list`<br>`forge test`<br>A [dry run](deployment.md#dry-run) when a deploy path changed |
| `.github/` | Read the workflow against [Security](security.md#non-negotiable-rules); every third-party action stays pinned to a commit SHA |
| Documentation-only change | `git diff --check`<br>Inspect changed links, anchors, paths, and commands |

Report deterministic tests, fork tests, skipped tests, and failures separately. Compilation does not prove runtime behavior.

## Reading Fork Test Results

`HubReader` tests run against live mainnet state and assert properties that hold over time: page shape, a validator's own self-delegation, empty results for an unknown delegator, and APYs for a past day. They can still fail without a code change when the RPC cannot serve the state.

When a fork test fails, rerun the same command on the base revision. A failure that reproduces there is pre-existing: report it as such with the output, and do not edit the assertion to make it pass unless the task is to fix the test. A skipped fork suite (no `BSC_RPC_URL`) is a blocked check to report, not a pass.

## Proof of Done

Checks show the code works; proof shows the result. Capture it once after the closing checks.

| Change kind | Proof |
|---|---|
| Bug fix | A test that fails on the base and passes on the change |
| Logic | The tests that pin it; for a rule that depends on chain behavior, a `cast call` against the live system contract or precompile |
| ABI change | The `forge inspect` diff and the list of Core files to update |
| Gas or size | Before and after numbers from `forge test --gas-report` or `forge build --sizes` on the same setup |
| Deployment | The transaction hash, the address, and the verified explorer link |
