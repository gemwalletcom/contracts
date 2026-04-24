# Monad Staking Lens

`StakingLens.sol` is a read-only helper around the Monad staking precompile. It is designed for Gem Wallet's RPC-only flow, so the main goal is to make `getDelegations(address)` useful without requiring an indexer or transaction history service.

## Trade-off

Monad exposes active delegations and validator lists, but withdrawals are only available through point lookups:

- `getDelegations(delegator, startValId)` can enumerate validators with current delegation state.
- `getWithdrawalRequest(validatorId, delegator, withdrawId)` requires the caller to already know both the validator and the withdraw id.

Because withdraw ids are scoped per `(validator, delegator)` and can use the full `0..255` range, a fully exact on-chain scan would mean checking up to 256 withdraw ids for every validator. That is too expensive for the default lens path.

## Current policy

`getDelegations(address)` uses a bounded hybrid scan:

- Prioritize Gem Wallet's curated validators:
  - `16` MonadVision
  - `5` Alchemy
  - `10` Stakin
  - `9` Everstake
- Then prioritize validators returned by `getDelegations(...)`.
- Full scan `0..255` for up to `MAX_FULL_SCAN_VALIDATORS` prioritized validators.
- Shallow scan `0..7` for remaining active validators.
- Shallow scan `0..7` for up to `MAX_FALLBACK_SCAN_VALIDATORS` other validators discovered from the validator set fallback.

Curated validators are processed first inside the full-scan set, so they are not squeezed out when the lens hits the `MAX_DELEGATIONS` cap.

This keeps the common Gem Wallet path accurate while avoiding a worst-case `all validators x 256 withdraw ids` sweep on every call.

`getBalance(address)` uses the same active, curated, and fallback validator sources, but processes active validators first because balance calculation has no withdrawal scan tier. That prevents curated discovery from crowding out active stake if the validator cap is ever reached.

## Accepted blind spot

The main case we still may miss is:

- a user fully undelegated from an unknown validator
- the only remaining state is a withdrawal
- that withdrawal lives at `withdrawId > 7`
- the validator is outside the bounded fallback scan window

The same can happen for an active non-curated validator after the full-scan validator cap is reached, but active stake and rewards are still returned because those do not depend on withdraw-id discovery.

We accept that trade-off for now because this lens is optimized for our wallet and our supported validators. If we later need exact recovery for all unknown validators, we will need either a heavier RPC fallback or an off-chain indexer.
