# Small-Chain Quality Retrospective

## Summary

The original small-chain flow reached `verify-change PASS`, but a later systematic review still found real defects. The root cause was not a single implementation mistake. The process treated `verify-change` as if it were adversarial code review.

## What Happened

- `writing-plans` created ACs for the main router and hook outcomes, but did not force a failure-matrix row for every failure-contract promise.
- `verify-change` checked task completion, task-plan mapping, success criteria, fresh command evidence, and route evidence.
- It did not require an independent adversarial review artifact before passing contract-grade or runtime-gate changes.
- As a result, negative paths like missing route input, route/task/plan drift, stale blocked route replay, and multi-active workset selection were only found after the user requested a separate review.

## Root Cause

`verify-change` is an acceptance and evidence gate. It proves that declared tasks and success criteria have supporting evidence. It is not designed to discover undeclared failure modes.

For contract-grade changes, quality depends on two earlier or separate gates:

- planning gate: the failure contract must be expanded into negative tests
- review gate: adversarial review must inspect correctness, state, error handling, evidence integrity, and missing tests before `verify-change`

Both gates were under-specified in the local small-chain wrapper.

## Fix

- `writing-plans` now requires a Contract-Grade Failure Matrix.
- `contracts/small-chain.yaml` now includes conditional `requesting-code-review` before `verify-change`.
- `verify-change` now requires `code-review-result.json` for contract-grade/runtime-gate surfaces.
- `verification-before-completion` now routes contract-grade/runtime-gate work to review before `verify-change`.
- Boundary tests now assert these gates are present.

## Expected Effect

The same class of defects should now be caught before a small-chain change can report `verify-change PASS`, because failure modes must be planned as negative tests and code review evidence must exist before final verification accepts the change.
