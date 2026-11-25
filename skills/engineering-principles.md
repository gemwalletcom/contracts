# Engineering Principles

Use for every code change. Review criteria live in [Code Review](code-review.md); this file is for writing code.

## Fix Causes, Not Symptoms

- Fix the broken rule in the contract that owns it. A wrong value from a lens is fixed in the lens, not papered over by a second getter or a consumer-side correction.
- Diagnose failing tests against intent. Fix a violating implementation; update stale expectations or intentionally changed behavior. Never weaken assertions just to pass.
- Check the sibling lens for the same cause.

## Solidity Style

- `forge fmt` owns formatting: 4-space indentation and the default line length. Do not hand-format against it.
- Every file starts with `// SPDX-License-Identifier: MIT` and a `pragma solidity ^0.8.x` line. Use named imports (`import {X} from "..."`) and the remappings in `remappings.txt`.
- Contracts, libraries, interfaces, structs, and enums are PascalCase; functions and variables camelCase; constants and immutables ALL_CAPS; internal and private functions start with `_`. Interfaces are prefixed `I` and live beside the contract that reads them.
- Mirror the directory in all three trees: `src/<area>/X.sol`, `script/<area>/X.s.sol`, `test/<area>/X.t.sol`.
- Name protocol numbers as constants with the unit in the name (`APY_BPS_PRECISION`, `MONAD_EPOCH_SECONDS`). No magic numbers in arithmetic.
- NatSpec belongs on external functions whose behavior a caller cannot read from the signature: units, pagination, defaults for empty input. Do not comment what the code already says.
- Suppress a lint only on the line it applies to, with `// forge-lint: disable-next-line(<lint>)` and a comment above it stating why the flagged pattern is safe. A narrowing cast needs a guard or a stated bound.

## Read-Lens Rules

- Lenses are stateless and permissionless: no storage writes, no owner, no `payable`, no `selfdestruct` or `delegatecall`. Fixed protocol addresses are constants.
- Every loop needs a bound the caller or a constant controls. A lens that iterates an unbounded on-chain list will exceed node `eth_call` gas limits as the list grows; paginate or cap it.
- Return fully populated structs in a stable field order. Appending, reordering, or retyping a field changes the ABI; see [Consumers](project-overview.md#consumers).
- When trimming a memory array with `mstore`, the new length must not exceed the allocated length.
- Guard every division whose denominator comes from chain state, and saturate instead of truncating when casting a computed value down.
- Report missing data as zero values or an omitted entry, consistently with the function's existing behavior. A revert in one validator's read should not be introduced where the function currently returns partial results.

## Abstractions Must Earn Their Place

- Extend the existing contract before adding a new one. Add a library, base contract, or dependency only for a current consumer; hypothetical reuse does not justify it.
- Keep single-use logic as an internal function on the contract. No forwarding-only wrappers.
- New dependencies are git submodules under `lib/` and need the user's agreement.

## Tests

- Test contracts are named `<Subject>Test`, test functions `test_<behavior>`, and mock helpers `_mock<Thing>`.
- Mock a system contract or precompile with `vm.mockCall` at its real address, encoding the selector from the interface. Monad's precompile cannot be forked, so [`StakingLens.t.sol`](../test/monad/StakingLens.t.sol) is the pattern.
- Fork tests select their fork in `setUp` with `vm.createSelectFork`, skip when the RPC variable is unset, state the chain in a header comment, and assert on values that stay true over time. Prefer a past timestamp or structural properties over an account's current balance; [`HubReader.t.sol`](../test/hub_reader/HubReader.t.sol) is the pattern.
- Protect business rules and boundaries: empty sets, the `MAX_*` caps, pagination past the end, zero denominators, and state transitions such as an epoch boundary. Temporarily invert a changed rule and confirm the targeted test fails, then restore it.
- Use `assertEq`, `assertGt`, and `assertLe` over `assertTrue(a == b)` so a failure prints both values, and give assertions in loops or fork tests a message.
