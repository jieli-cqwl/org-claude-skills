# Product Skill Contract Review Hotfix

## Why
The archived `product-skills-governance` small-chain was already complete, but a later review surfaced seven contract and gate drifts in the implemented product skill changes. Without a focused hotfix package, the repository would keep passing around split truth between skill prose, canonical schema/template/validator contracts, review gates, and lifecycle/context-budget tests.

This hotfix exists to close that gap with a minimal follow-up change set and to backfill a traceable small-chain evidence package for the review-driven fix loop.

## Scope
- In scope: fix the seven accepted findings across canonical schema/template/validator/test surfaces; capture the hotfix process evidence in this directory; rerun review and verification.
- Out of scope: redesign the archived `product-skills-governance` feature, reopen its archived scope, or broaden product skill semantics beyond the seven findings and their direct regressions.

## Approach
Treat each finding as a contract-sync problem first, not as isolated text cleanup. For each accepted finding, update every authoritative surface that participates in runtime truth: schema, template, validator, standard-chain registry, fixtures, tests, and role gates. Then backfill this hotfix directory with a compact small-chain package so the review-driven closeout has design, task, implementation, and verification evidence in one place.

## Alternatives Considered
| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| Patch code only and keep evidence in `fix-result.json` | Fastest | Leaves process review blocked and spreads evidence across chat, git diff, and JSON only | Rejected |
| Treat verifier block as process mismatch and waive it | No extra docs | Weakens the "small-chain before stop" rule and leaves the hotfix non-replayable | Rejected |
| Create a minimal hotfix small-chain package in this directory and rerun review | Clears process gap, keeps evidence local, preserves archived original package | Slightly retrospective because the hotfix was triggered by later review findings | Chosen |

## Key Decisions
- D1: Fix every accepted finding at the canonical truth layer, not only in Skill prose. Reason: the observed failures were all drift between prose contracts and machine gates.
- D2: Keep the original archived `product-skills-governance` package immutable. Reason: this hotfix is a follow-up correction, not a rewrite of archived history.
- D3: Record the hotfix as a self-contained evidence package under `docs/hotfix-20260423-0600-product-skill-contract-review-fix/`. Reason: verifier feedback explicitly called out missing process artifacts for the hotfix fallback path.
- D4: Use fresh targeted verification plus a fresh broad quick regression before closing the hotfix. Reason: the fixes touch shared contract surfaces, not only isolated docs.

## Goals & Success Criteria
| Goal | Success Criteria | Verification |
|------|------------------|--------------|
| G1 Fix the seven accepted findings | Director/Manager canonical contracts, design gates, lifecycle retain rules, eval anchors, and context-budget expiry behavior align with the accepted review findings | `bash tests/test-product-artifact-contract.sh`; `bash tests/test-skill-output-and-gate-contract.sh`; `bash tests/test-skill-lifecycle-eval-framework.sh`; `bash tests/test-standard-chain-foundation-registry.sh`; `bash tests/test-skill-context-budget.sh`; `bash tests/test-skill-context-budget-expiry.sh` |
| G2 Close the review loop cleanly | Code review reaches PASS with no new P1/P2, a formal hotfix review result exists, and verifier no longer reports process-blocked for missing hotfix artifacts | `code-review-result.json`; `code-review-report.md`; verifier rerun summary recorded in `fix-result.json` |
| G3 Backfill hotfix process evidence | This directory contains `design.md`, `tasks.md`, `plan.md`, `developer-report.md`, `code-review-report.md`, and `verify-change-report.md`; task-plan consistency passes | `python3 tools/community/check_task_plan_consistency.py docs/hotfix-20260423-0600-product-skill-contract-review-fix/tasks.md docs/hotfix-20260423-0600-product-skill-contract-review-fix/plan.md` |

## Change Scope
| File or Area | Change Type | Size |
|--------------|-------------|------|
| `contracts/canonical/schemas/planning/*.json` | modify | medium |
| `contracts/canonical/templates/planning/*.json` | modify | medium |
| `contracts/standard-chain.yaml` | modify | small |
| `tools/community/validate_product_closure.py` | modify | medium |
| `shared/skills/design/scripts/completion_check.sh` | modify | medium |
| `shared/skills/product-director/scripts/completion_check.sh` | modify | small |
| `shared/skills/product-manager/scripts/completion_check.sh` | modify | medium |
| `shared/skills/product-manager/references/output-contract.md` | modify | small |
| `shared/skills/product-manager/evals/evals.json` | modify | small |
| `tests/test-product-artifact-contract.sh` | modify | medium |
| `tests/test-skill-output-and-gate-contract.sh` | modify | medium |
| `tests/test-skill-lifecycle-eval-framework.sh` | modify | medium |
| `tests/test-standard-chain-foundation-registry.sh` | modify | medium |
| `tests/test-skill-context-budget.sh` | modify | small |
| `tests/test-skill-context-budget-expiry.sh` | create | small |
| `docs/hotfix-20260423-0600-product-skill-contract-review-fix/*` | create / modify | medium |

## Invariants
- Do not revert or rewrite unrelated dirty work from the main worktree.
- Do not reopen or edit the archived `docs/archive/product-skills-governance/2026-04-23-capability-and-structure-redesign/` package.
- Keep Director owning WHY-layer locked fields and Manager owning WHAT-layer UNIT/phase semantics.
- Keep canonical JSON and validator gates as the runtime source of truth.

## Downstream Impact
| Consumer | Impact | Propagation Needed |
|----------|--------|--------------------|
| `design` skill gate | Now blocks incomplete PM closure and unconfirmed product handoff | yes, via updated completion check and docs |
| `product-director` / `product-manager` runtime validation | Canonical lock fields and UNIT/phase semantics become machine-enforced | yes |
| Standard-chain pilots and fixtures | Sample artifacts need migrated fields and regenerated replay proofs | yes |
| Lifecycle and context-budget CI checks | Retain decisions and allowlist expiry become stricter | yes |
| Future reviewers of this hotfix | Can replay the closeout from this directory instead of reconstructing it from chat | yes |

## Risks
| Risk | Impact | Mitigation |
|------|--------|------------|
| Retrospective hotfix docs drift from the actual implementation sequence | Process evidence could look reconstructed rather than traceable | Anchor every doc to `fix-result.json`, fresh commands, and recorded review rounds |
| Shared contract changes ripple into pilots and registry fixtures | Tests may pass locally but regress on downstream fixtures | Re-run targeted pilot/registry/readiness tests and a fresh `run-all --quick --profile` |
| Verifier still treats the hotfix as process-blocked | The original blocker would remain unresolved | Backfill the missing small-chain artifacts in this directory and rerun verifier explicitly against them |
