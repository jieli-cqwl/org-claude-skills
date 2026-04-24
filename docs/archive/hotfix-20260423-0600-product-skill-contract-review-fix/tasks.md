# Tasks - product skill contract review hotfix
Created: 2026-04-23
Related plan: ./plan.md

## Acceptance Checklist

- [x] T1 Confirm scope, invariants, and authoritative fix surfaces
  - AC: The seven accepted findings are mapped to concrete authoritative surfaces, and this hotfix explicitly distinguishes itself from the already-archived `product-skills-governance` package.
  - AC: `design.md` records why the hotfix exists, what stays out of scope, which invariants must hold, and which downstream consumers are affected.
  - Traces: G1; G3
  - Depends: -
  - Complexity: simple

- [x] T2 Apply and verify the contract-sync fixes
  - AC: Director WHY fields, Manager phase/UNIT semantics, design handoff gating, lifecycle retain thresholds, eval anchors, and context-budget expiry behavior are all aligned across code, schema, templates, validators, fixtures, and tests.
  - AC: Fresh targeted verification passes for the modified contract surfaces and a fresh broad regression proves the repository still holds after the follow-up fixes.
  - Traces: G1
  - Depends: T1
  - Complexity: complex

- [x] T3 Close the review and process-evidence loop
  - AC: Review history is recorded with resolved FAIL rounds and a final PASS outcome.
  - AC: This directory contains `developer-report.md`, `code-review-result.json`, `code-review-report.md`, and `verify-change-report.md`, and `python3 tools/community/check_task_plan_consistency.py docs/hotfix-20260423-0600-product-skill-contract-review-fix/tasks.md docs/hotfix-20260423-0600-product-skill-contract-review-fix/plan.md` exits 0.
  - AC: `fix-result.json` records the post-backfill verifier status and the latest broad regression result.
  - Traces: G2; G3
  - Depends: T2
  - Complexity: moderate

## Definition of Done

All tasks checked = ready for verify-change.
