# Rule Runtime Systemic Correction Design

**Status:** Accepted and implemented on `codex/runtime-contract-systemic-correction`.

## Goal

Make runtime scene contracts generalize across request forms and domains, and make the evaluator prove required behavior without rewarding prompt-specific wording, over-reading, or identical candidate/baseline behavior.

## Problem

The prior change improved several known scenarios but embedded their nouns and answer structure in runtime references. Its focused evaluator repeated the same request prefix, tracked required reads without bounding irrelevant reads, forced one run, omitted the installed entry from runtime identity, and could report effectiveness when candidate and baseline behaved the same. The rollout readiness pack also became the accidental owner of evaluator execution fields.

## Decisions

1. Scene activation depends on problem domain, decision impact, and risk, not on whether the request asks for analysis or file changes.
2. Multi-scene activation is additive at `shared/assistant.md`; references do not recursively compose other scenes.
3. Runtime rules state mechanism-neutral invariants. Authentication mechanism details live in `shared/reference/authentication-and-authorization.md`.
4. Eval cases declare required scenes, forbidden scenes, and an optional maximum scene-read count. Regression cases and generalization cases remain separate profiles.
5. Effectiveness profiles run each configuration at least twice with interleaved candidate/baseline order.
6. Identical outcomes produce `NO_OBSERVED_UPLIFT`. Bundle-level source differences are associations, not causal attribution.
7. Comparative baselines must be distinct ancestors. Candidate-owned contracts may observe a source or installed target absent from an older baseline; that absence is evidence, not infrastructure failure.
8. `tools/eval/contracts/rule-runtime-eval.json` owns evaluator execution. `docs/rule-runtime--team-readiness/acceptance-pack.json` owns rollout decisions and consumes evaluator evidence without redefining execution.
9. Quick gates run deterministic contract tests. The exhaustive fake-Codex integration test is full-only; live model evaluation remains an explicit evidence command.

## Non-Goals

- Retiring the still-referenced Codex controlled-pilot rollout record.
- Claiming broad runtime or team rollout readiness.
- Treating command parsing as proof that a reference was semantically understood.
- Replacing model-graded behavior evidence with Markdown prose assertions.

## Acceptance

- Existing focused cases retain candidate behavior and route coverage.
- Generalization cases cover opaque tokens, native OAuth diagnosis, cross-layer business rules, acceptable bounded compatibility, and low-cost near misses.
- Forbidden or excessive scene reads fail route evidence.
- The rendered `AGENTS.md` participates in installed-runtime identity.
- Same-commit and non-ancestor baselines are rejected before execution.
- Repeated runs are executed and projected at the selected scope rather than against a hard-coded case count.
- Rollout and eval contracts have one owner each, and targeted governance tests enforce that separation.
