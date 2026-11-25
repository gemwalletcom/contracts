# AGENTS.md

Guidance for Coding Agents (Claude Code, Codex, etc.) collaborating in this repository. This file is the routing layer plus the non-negotiable rules. Everything else lives in a skill; load only what the task needs.

## Using the Guidance

The user's task defines scope and authorization. Current source and the deployed contracts govern design; nearby code provides examples, not permission to copy a known violation. Agent memory and external skills are advisory and must be checked against these sources. When guidance disagrees with the source, resolve it from the source, fix the stale rule, and ask only if a product or security decision remains unresolved.

## Skills

`task-workflow.md` and `engineering-principles.md` apply to every task. The rest are load-on-demand; the one-line description tells you when.

- [Task Workflow](skills/task-workflow.md) — Scope, investigation, implementation loop, verification, cleanup rounds, handoff, and guide maintenance
- [Engineering Principles](skills/engineering-principles.md) — Solidity style, naming, read-lens design rules, and test intent
- [Project Overview](skills/project-overview.md) — Repo layout, what each contract reads, where it is deployed, and who consumes it
- [Development Commands](skills/development-commands.md) — Foundry and `just` commands, RPC aliases, and tool caveats
- [Quality Checks](skills/quality-checks.md) — Iteration and closing checks per change type, and proof of done
- [Code Review](skills/code-review.md) — Review checklist for correctness, ABI compatibility, gas bounds, and security
- [Security](skills/security.md) — Deployer key handling, broadcast authorization, and on-chain trust boundaries
- [Deployment](skills/deployment.md) — Deploy, verify, record the address, update consumers, commits, and publication boundaries

## Non-Negotiables

- A deployed contract is immutable and its address and ABI are pinned in [Gem Wallet Core](skills/project-overview.md#consumers). Changing an external function signature, a returned struct, or an enum order is a breaking change that needs a new deployment and a coordinated Core update; say so before editing.
- Never broadcast a transaction, verify a contract, or run a `just deploy-*` or `just verify-*` recipe unless the user asked for that action in this session. See [Deployment](skills/deployment.md#publication-boundaries).
- Never read out, log, commit, or paste the contents of `.env`, and never put a private key in it. The deployer key lives in an encrypted Foundry keystore. See [Security](skills/security.md).
- Local checks are the gate: CI cannot run the `HubReader` fork tests. See [Quality Checks](skills/quality-checks.md).
- Do not edit `lib/` (git submodules), `out/`, `cache/`, or `broadcast/`.

## Task Completion

Follow [Task Workflow](skills/task-workflow.md#4-verify-the-actual-result) for verification, both cleanup rounds, and handoff; [Quality Checks](skills/quality-checks.md) defines the required commands. Review deployment, key-handling, and CI changes with [Security](skills/security.md#review-checklist).
