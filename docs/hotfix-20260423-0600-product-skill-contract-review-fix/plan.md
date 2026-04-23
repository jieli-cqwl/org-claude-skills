# Product Skill Contract Review Hotfix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Close the seven accepted review findings on product-skill contract drift and backfill a replayable hotfix evidence package.

**Architecture:** Keep the archived original small-chain untouched and treat this work as a focused hotfix layer. Synchronize code-facing contract surfaces first, then add review and verification evidence in this directory so the hotfix itself is replayable.

**Tech Stack:** JSON schema/templates, shell contract tests, Python validation utilities, Markdown small-chain artifacts, agent-based review.

---

## Current State

- The original `product-skills-governance` redesign package is already archived with a PASS `verify-change-report.md`.
- This follow-up work was triggered by seven later review findings against the implemented product-skill changes.
- The current branch/worktree already contains the code fixes and most verification evidence; the remaining gap is to backfill hotfix-local small-chain evidence and rerun verifier.

## File Boundary Map

- Create: `docs/hotfix-20260423-0600-product-skill-contract-review-fix/design.md`
- Create: `docs/hotfix-20260423-0600-product-skill-contract-review-fix/tasks.md`
- Create: `docs/hotfix-20260423-0600-product-skill-contract-review-fix/plan.md`
- Create: `docs/hotfix-20260423-0600-product-skill-contract-review-fix/developer-report.md`
- Create: `docs/hotfix-20260423-0600-product-skill-contract-review-fix/code-review-result.json`
- Create: `docs/hotfix-20260423-0600-product-skill-contract-review-fix/code-review-report.md`
- Create: `docs/hotfix-20260423-0600-product-skill-contract-review-fix/verify-change-report.md`
- Modify: `docs/hotfix-20260423-0600-product-skill-contract-review-fix/fix-result.json`
- Modify: `contracts/canonical/schemas/planning/brief.schema.json`
- Modify: `contracts/canonical/schemas/planning/phase-prd.schema.json`
- Modify: `contracts/canonical/schemas/planning/unit-definition.schema.json`
- Modify: `contracts/canonical/templates/planning/brief.template.json`
- Modify: `contracts/canonical/templates/planning/director/brief.template.json`
- Modify: `contracts/canonical/templates/planning/phase-prd.template.json`
- Modify: `contracts/canonical/templates/planning/unit-definition.template.json`
- Modify: `contracts/standard-chain.yaml`
- Modify: `tools/community/validate_product_closure.py`
- Modify: `shared/skills/design/SKILL.md`
- Modify: `shared/skills/design/scripts/completion_check.sh`
- Modify: `shared/skills/product-director/scripts/completion_check.sh`
- Modify: `shared/skills/product-manager/references/output-contract.md`
- Modify: `shared/skills/product-manager/evals/evals.json`
- Modify: `shared/skills/product-manager/scripts/completion_check.sh`
- Modify: `tests/test-product-artifact-contract.sh`
- Modify: `tests/test-product-role-split-contract.sh`
- Modify: `tests/test-skill-context-budget.sh`
- Create: `tests/test-skill-context-budget-expiry.sh`
- Modify: `tests/test-skill-lifecycle-eval-framework.sh`
- Modify: `tests/test-skill-output-and-gate-contract.sh`
- Modify: `tests/test-standard-chain-foundation-registry.sh`
- Modify: migrated pilot and fixture JSON under `docs/login-homepage-pilot/`, `docs/feedback-thanks-pilot/`, and `tests/fixtures/standard-chain-foundation/`

### Task 1: Confirm scope and evidence boundaries [T1]

Context: This hotfix must stay strictly on the accepted review findings and their direct regressions. It also needs to explain why a second evidence package exists even though the original redesign package is already archived.

Files:
- Create: `docs/hotfix-20260423-0600-product-skill-contract-review-fix/design.md`
- Modify: `docs/hotfix-20260423-0600-product-skill-contract-review-fix/fix-result.json`

1. [T1] Read the seven accepted findings, the current `fix-result.json`, and the archived `product-skills-governance` small-chain package to confirm the hotfix scope.
2. [T1] Freeze invariants: do not edit archived history, do not revert unrelated workspace changes, and do not extend beyond the accepted findings plus their direct gate/test fallout.
3. [T1] Write `design.md` so it records why the hotfix exists, the chosen approach, success criteria, changed surfaces, downstream impact, and risk mitigation.

### Task 2: Apply and verify contract-sync fixes [T2]

Context: The accepted findings are all cross-surface drift problems. The implementation must update every authoritative surface that participates in runtime truth, not just the visible Skill prose or a single validator.

Files:
- Modify: `contracts/canonical/schemas/planning/brief.schema.json`
- Modify: `contracts/canonical/schemas/planning/phase-prd.schema.json`
- Modify: `contracts/canonical/schemas/planning/unit-definition.schema.json`
- Modify: `contracts/canonical/templates/planning/brief.template.json`
- Modify: `contracts/canonical/templates/planning/director/brief.template.json`
- Modify: `contracts/canonical/templates/planning/phase-prd.template.json`
- Modify: `contracts/canonical/templates/planning/unit-definition.template.json`
- Modify: `contracts/standard-chain.yaml`
- Modify: `tools/community/validate_product_closure.py`
- Modify: `shared/skills/design/SKILL.md`
- Modify: `shared/skills/design/scripts/completion_check.sh`
- Modify: `shared/skills/product-director/scripts/completion_check.sh`
- Modify: `shared/skills/product-manager/references/output-contract.md`
- Modify: `shared/skills/product-manager/evals/evals.json`
- Modify: `shared/skills/product-manager/scripts/completion_check.sh`
- Modify: `tests/test-product-artifact-contract.sh`
- Modify: `tests/test-product-role-split-contract.sh`
- Modify: `tests/test-skill-context-budget.sh`
- Create: `tests/test-skill-context-budget-expiry.sh`
- Modify: `tests/test-skill-lifecycle-eval-framework.sh`
- Modify: `tests/test-skill-output-and-gate-contract.sh`
- Modify: `tests/test-standard-chain-foundation-registry.sh`
- Modify: migrated pilot and fixture JSON under `docs/login-homepage-pilot/`, `docs/feedback-thanks-pilot/`, and `tests/fixtures/standard-chain-foundation/`

1. [T2] Extend Director canonical lock truth so `user_profile`, `appetite`, `non_goals`, `feasibility_constraints`, `risks_and_unknowns`, and `decision_rationale` are protected consistently in schema, templates, validator lock fields, standard-chain declarations, and fixtures.
2. [T2] Extend Product Manager canonical phase/UNIT truth so `business_flows`, `user_paths`, `rule_mappings`, `design_decision_candidates`, `integration_context`, structured AC items, and `verification_plan` exist in schema, templates, validators, tests, and fixtures.
3. [T2] Tighten gates and regressions: require confirmed PM handoff before `design`, enforce retain measurement thresholds, complete eval anchor coverage, and make context-budget allowlist expiry fail after its deadline.
4. [T2] Run focused proving commands and confirm green output:
   - [T2] `bash tests/test-product-artifact-contract.sh`
   - [T2] `bash tests/test-skill-output-and-gate-contract.sh`
   - [T2] `bash tests/test-skill-lifecycle-eval-framework.sh`
   - [T2] `bash tests/test-standard-chain-foundation-registry.sh`
   - [T2] `bash tests/test-skill-context-budget.sh`
   - [T2] `bash tests/test-skill-context-budget-expiry.sh`
5. [T2] Run a fresh broad regression:
   - [T2] `bash tests/run-all.sh --quick --profile`
   - [T2] Record the result in `fix-result.json` and the hotfix reports.

### Task 3: Close the review and process-evidence loop [T3]

Context: The code-side fixes already passed multiple review rounds. This task records that loop cleanly, reruns verifier against the backfilled hotfix package, and writes the closeout artifacts required for this directory to stand on its own.

Files:
- Create: `docs/hotfix-20260423-0600-product-skill-contract-review-fix/developer-report.md`
- Create: `docs/hotfix-20260423-0600-product-skill-contract-review-fix/code-review-result.json`
- Create: `docs/hotfix-20260423-0600-product-skill-contract-review-fix/code-review-report.md`
- Create: `docs/hotfix-20260423-0600-product-skill-contract-review-fix/verify-change-report.md`
- Modify: `docs/hotfix-20260423-0600-product-skill-contract-review-fix/fix-result.json`

1. [T3] Summarize implementation evidence in `developer-report.md`, including scope, key fixes, fresh proving commands, and the distinction between historical RED signals and fresh GREEN evidence.
2. [T3] Write a formal `code-review-result.json` for this hotfix package and summarize the same review loop in `code-review-report.md`, including the two failing rounds, their fixes, and the final PASS round.
3. [T3] Run task-plan consistency for this hotfix package:

```bash
python3 tools/community/check_task_plan_consistency.py docs/hotfix-20260423-0600-product-skill-contract-review-fix/tasks.md docs/hotfix-20260423-0600-product-skill-contract-review-fix/plan.md
```

Expected: `[PASS] tasks-plan consistency (3 tasks, ... plan steps)`.

4. [T3] Rerun verifier against the backfilled hotfix package and record the outcome in `fix-result.json`.
5. [T3] Write `verify-change-report.md` with PASS only if this directory has `design.md`, `tasks.md`, `plan.md`, all tasks are `[x]`, fresh evidence exists, and no CRITICAL finding remains.
