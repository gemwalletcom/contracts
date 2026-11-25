# Monad Staking Lens

`StakingLens.sol` is a read-only helper around the Monad staking precompile. It is designed for Gem Wallet's RPC-only flow, so the main goal is to make `getDelegations(address)` useful without requiring an indexer or transaction history service.

## Trade-off

Monad exposes active delegations and validator lists, but withdrawals are only available through point lookups:

- `getDelegations(delegator, startValId)` can enumerate validators with current delegation state.
- `getWithdrawalRequest(validatorId, delegator, withdrawId)` requires the caller to already know both the validator and the withdraw id.

Because withdraw ids are scoped per `(validator, delegator)` and can use the full `0..255` range, a fully exact on-chain scan would mean checking up to 256 withdraw ids for every validator. That is too expensive for the default lens path.

## Discovery coverage

`getBalance(address)` sums every page returned by the native delegator list, then checks the four curated validators for balances such as rewards left after a full exit. Each validator is counted once. The balance read does not enumerate consensus validators or withdrawal requests. Rewards left on a non-curated validator outside the delegator list may still appear in the detailed positions.

`getDelegations(address)` keeps the first 128 native delegations and fills unused slots from the consensus list. MonadVision (16), Alchemy (5), Stakin (10) and Everstake (9) are also checked, even if absent from both lists. The four curated IDs take no slots away from native delegations or the previous consensus fallback coverage.

Withdrawal IDs are scanned at two depths. The first eight selected validators that are in the native delegator list, curated ones first, are checked for all 256 withdrawal IDs. Every other selected validator, including a curated validator the delegator has fully exited, is checked for IDs 0 through 7. This keeps the curated check to a few lookups for a wallet that never staked: the precompile gives no way to tell that wallet from one that fully exited. A non-curated validator outside the scan or a high withdrawal ID on a shallow-scanned validator can still require transaction history for discovery. The balance total includes stake beyond the 128 active positions displayed.
