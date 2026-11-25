# Task Workflow

Use for every task. Follow the requested scope, ground changes in existing code, and verify the result.

Do not hard-wrap prose in docs, skills, commit messages, or PR bodies. Keep one paragraph per block and one list item per line; leave code, tables, and headings as they are.

## 1. Establish the Task Contract

- Classify the request: investigate, review, implement, or publish. Investigation and review are read-only unless fixes are requested. Publishing (commit, push, PR, deploy, verify) follows [Deployment](deployment.md#publication-boundaries).
- Confirm checkout, branch, and `git status --short`. Preserve unrelated changes; avoid stashing the user's tree.
- Decide whether the change touches a deployed contract's ABI or returned values. If it does, it is a cross-repository change: state the required redeployment and [Core update](project-overview.md#consumers) before editing.
- State assumptions affecting scope, security, or compatibility.

## 2. Ground the Change Before Editing

- Read the contract, the interface it reads (`IStakeHub`, `IStakeCredit`, `IStaking`), its test, and its deploy script. Check the sibling lens for an existing pattern before adding one.
- Interfaces in `src/` mirror on-chain system contracts and precompiles this repository does not own. Confirm a signature against the chain's own source or documentation before changing it; a wrong selector or return layout compiles and passes mocked tests.
- For behavior changes, state the intended change, the affected external functions, and the checks in a brief progress update; this does not require approval.
- Before adding a contract, library, or dependency, identify why the existing contract cannot handle the requirement. Apply [Engineering Principles](engineering-principles.md#abstractions-must-earn-their-place).

## 3. Run a Tight Implementation Loop

- Change the contract and its test together. Use the narrow checks from [Quality Checks](quality-checks.md#iteration-matrix) while iterating.
- Resolve failures from evidence, not stacked workarounds. A `forge-lint` suppression needs the reason it is safe on the line above it.
- **Cleanup round one**, before the closing checks: review the whole diff for unnecessary abstractions, dead code, unused imports and constants, stale mocks, and inconsistent naming. Keep cleanup within the task.

## 4. Verify the Actual Result

- Run the applicable [Quality Checks](quality-checks.md#closing-matrix). Report exact commands and results.
- Passing checks are not done: prove the result with [Proof of Done](quality-checks.md#proof-of-done).

## 5. Hand Off a Reproducible State

- **Cleanup round two**, after verification: read each hunk as a reviewer. Remove remaining redundancy, debugging leftovers such as `console.log` in `src/`, and comments that restate the code. Rerun affected checks if source changes.
- Inspect final diff and status. Report changes, exact commands and results, proof, skipped or blocked checks and why, and risks. Always say whether the change needs a redeployment and a Core update.
- Leave changes uncommitted and external systems unchanged unless the user authorized those actions.

## 6. Maintain Agent Guidance

- At handoff, evaluate corrections and costly discoveries. Fix demonstrably wrong guidance during implementation; investigations and reviews stay read-only and propose the fix instead.
- One canonical statement per rule. Root `AGENTS.md` routes tasks and holds the non-negotiables; procedures live in `skills/`; other files link to the rule instead of paraphrasing it. `docs/` is ignored by git (it is `forge doc` output), so durable design notes belong in [Project Overview](project-overview.md).
- Open each skill with its load trigger. Keep commands in [Development Commands](development-commands.md) or [Quality Checks](quality-checks.md). Never retain temporary paths, credentials, transient status, or unverified workarounds.
- Verify guidance changes with the documentation row in [Quality Checks](quality-checks.md#closing-matrix).
