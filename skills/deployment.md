# Deployment

Use when deploying or verifying a contract, recording an address, committing, pushing, or opening a PR.

## Publication Boundaries

- Treat commit, push, PR creation, broadcast, and explorer verification as separate actions; perform only what the user requested. A request to implement a change is not a request to deploy it.
- A broadcast is irreversible and spends the deployer's funds. Restate the contract, chain, and recipe, and get the user's go-ahead for that specific deployment before running it.
- `Commit` or `push` applies to the current branch unless the user names another target. If the remote rejects a push, report it instead of inventing a target.
- A rebase or amended commit does not authorize a push. Publish rewritten history with `git push --force-with-lease`, never an unconditional force push.

## Before Deploying

1. The change is merged or the user confirmed the exact commit to deploy, and the tree is clean.
2. Every row of the [closing matrix](quality-checks.md#closing-matrix) passes on that commit.
3. `.env` has the chain's RPC URL, `ETHERSCAN_API_KEY`, and `DEPLOYER_ACCOUNT`, and `cast wallet list` shows that account. Check that variables are set without printing them; see [Security](security.md#non-negotiable-rules).

## Dry Run

Running a deploy script without `--broadcast` simulates it and sends nothing. It needs no key:

```bash
forge script script/hub_reader/HubReader.s.sol:HubReaderScript
forge script script/monad/StakingLens.s.sol:StakingLensScript
```

Add `--rpc-url bsc` or `--rpc-url monad` to simulate against the chain.

## Deploy and Verify

| Contract | Chain | Deploy | Verify |
|---|---|---|---|
| `HubReader` | BNB Smart Chain (56) | `just deploy-hub-reader` | Included (`--verify`) |
| `StakingLens` | Monad (143) | `just deploy-monad-staking` | `just read-staking-lens-address`<br>`just verify-monad-staking <ADDRESS>` (Sourcify)<br>`just verify-monad-staking-etherscan <ADDRESS>` |

The deploy recipes pass `--account "$DEPLOYER_ACCOUNT"`, and Forge prompts for the keystore password. That prompt is the user's to answer, so a deployment runs in their terminal.

Confirm the deployment on the explorer and call one getter with `cast call` before reporting success.

## After Deploying

1. Update the address and explorer link under [Deployments](../README.md#deployments) in the README.
2. Report the transaction hash, the address, and the explorer link.
3. The new address does nothing until [Core](project-overview.md#consumers) adopts it. Name the constant and ABI files to change there; that change is made and reviewed in the wallet repository.
4. The previous deployment stays live for released app versions. Do not describe it as replaced.

## Commits and Pull Requests

- Stage only task-owned paths and inspect the staged diff. Do not use `git add -A`.
- The subject is one short imperative line under 65 characters, as in `Remove Stargate integration` or `Include positions without active delegations`. Detail, reasons, and measured effects go in the body after a blank line.
- Do not hard-wrap commit messages or PR bodies. Do not add agent attribution trailers, `Co-Authored-By` lines, or session links.
- A PR body says what changed, whether the ABI changed, whether a redeployment and a Core update are needed, and the checks that were run with their results. Link the deployment transaction and explorer page when there is one, and note any new environment variable or RPC alias.
