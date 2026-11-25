# Code Review

Use when reviewing a diff, branch, or PR. Apply these checks within the agent's native review workflow and output format. Review only unless fixes are requested; the other skills remain the source of truth.

## Setup and Scope

1. Follow [Task Workflow](task-workflow.md). Read [Security](security.md) when the change touches scripts, the `justfile`, configuration, CI, or dependencies.
2. Fix the review range: the PR's actual base and head commits. Refresh affected evidence if the head moves.
3. Read the diff, the whole changed contract, the interface it calls, its test, and its deploy script.

## Correctness

- Derive expected behavior from the task and from the system contract or precompile being read, not from the test. Mocked tests share the author's assumptions about return layouts; check the interface against the chain's own source for any changed call.
- Challenge with reachable inputs: a delegator with no positions, more validators than `MAX_DELEGATIONS`, a page past the end, `limit` of zero, a validator with zero stake, total stake of zero, a withdrawal exactly at the current epoch, and an id that is not in the validator set.
- Check pagination loops terminate when the source reports done, when a cap is reached, and when it returns an empty page without `isDone`.
- Check every `mstore` length rewrite shrinks the array, and that position counters cannot pass the allocated size.
- Check arithmetic for precision loss from dividing before multiplying, zero denominators, and narrowing casts. Each `forge-lint` suppression needs a reason that is actually true for the surrounding code.

## Compatibility

- Compare `forge inspect <Contract> abi` with the base for any change to external functions, structs, or enums. An ABI change without a stated redeployment and [Core update](project-overview.md#consumers) is a High finding.
- A change in returned values under an unchanged ABI (units, ordering, which entries are included) is also a consumer-visible change: check how Core decodes and uses it.
- Constants that encode protocol parameters (block reward, blocks per year, epoch length, validator set size) need an authoritative source and the date or block it was checked at.

## Gas and Size

- Each added external call inside a loop multiplies by the loop bound. Estimate the worst case against the caps and flag a path that could exceed a node's `eth_call` gas limit.
- `forge build --sizes` must keep each contract under the 24,576-byte runtime limit.

## Design and Style

Apply [Engineering Principles](engineering-principles.md). Each new contract, external function, or constant needs a current consumer. Flag unnecessary wrappers and unrelated refactors.

## Reporting

Report findings by severity with file and line references. Each correctness or security finding needs a reachable failing scenario, expected versus actual behavior, impact, and the smallest reasonable fix. Distinguish reproduction from code inspection.

Separate verification gaps (uncovered scenarios, fork tests that could not run) from pre-existing failures verified against the base. Report exact commands run, skipped, or blocked. If no findings remain, say so and disclose residual risks.

Use native severity labels when available; otherwise:

- Critical: wrong balances, delegations, or rewards shown to users; a lens gaining the ability to hold or move funds; exposed key material
- High: ABI break without a deployment plan, unbounded gas, broken build or deploy path
- Medium: edge-case correctness bugs or incorrect partial results
- Low: minor correctness issues with limited impact
