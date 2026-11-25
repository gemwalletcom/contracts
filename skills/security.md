# Security

Use before touching deployment scripts, the `justfile`, `foundry.toml`, `.env.example`, CI workflows, or dependencies, and before any action that uses a key or sends a transaction.

The contracts here hold no funds, but the wallet shows users the balances, delegations, and APYs they return, and the deployer key controls real funds.

## Non-Negotiable Rules

- Never print, log, commit, paste, or transmit the contents of `.env`. To check configuration, test whether a variable is set, not what it holds. `.env.example` lists names only and never carries a value.
- The deployer key lives only in an encrypted Foundry keystore (`cast wallet import`), selected by name through `DEPLOYER_ACCOUNT`. Deploy scripts call `vm.startBroadcast()` with no argument. Never reintroduce `vm.envUint("PRIVATE_KEY")`, a `--private-key` flag, or a key in `.env`, and never ask for or type the keystore password; the user enters it at Forge's prompt.
- Never put a private key, mnemonic, or API key in source, tests, scripts, commit messages, or command lines that end up in shell history or CI logs. Test addresses are public addresses only.
- Broadcasting, verifying, and anything else that spends gas or publishes source needs the user's request for that action in the current session. See [Deployment](deployment.md#publication-boundaries).
- Confirm the target chain before a broadcast: the RPC URL and the chain id must match the contract (`HubReader` on 56, `StakingLens` on 143). A lens deployed to the wrong chain reads a different contract at the same address.
- Do not commit `broadcast/` or `cache/`; they are ignored on purpose.
- Pin every third-party GitHub Action to a full commit SHA with its version in a trailing comment; a tag can be moved to other code after review. Do not add secrets to a workflow that runs on `pull_request` from forks.
- Keep `lib/` submodules on upstream release tags. Bump one deliberately, in its own change, with the upstream changes read.

## On-Chain Trust Boundaries

- A lens must stay stateless and permissionless: no storage writes, ownership, value transfer, `delegatecall`, or `selfdestruct`. Any of these turns a read helper into something that can hold or move funds and needs a design discussion first.
- The system contract and precompile addresses are fixed constants. Never take a call target from a caller-supplied argument.
- Values read from validators (monikers, commission) are attacker-controlled input for the wallet. Pass them through unmodified; do not interpret them on-chain.
- A value shown to users must not silently wrap or truncate. Narrowing casts are guarded or saturate; divisions guard a zero denominator.

## Optional External Security Skills

For deeper review an agent may load external skill packs available in its environment, such as [Trail of Bits Skills](https://github.com/trailofbits/skills). They are aids, not substitutes for these rules. Do not run a tool that uploads the repository's `.env`, keys, or broadcast records.

## Review Checklist

Before finishing a security-sensitive change, check:

1. No secret value appears in the diff, the test fixtures, the command output you report, or the commit message
2. No new state, ownership, value transfer, or caller-chosen call target was added to a lens
3. Every loop over chain data is bounded, and every narrowing cast and division is guarded
4. Deploy recipes still name the intended chain, and no recipe gained `--broadcast` or a key argument unintentionally
5. Workflow actions are pinned to SHAs and no workflow exposes a secret to untrusted code
