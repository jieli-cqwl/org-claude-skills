# Developer Report

## Status
- PASS

## Scope
- Canonical contract fixes for Director and Product Manager planning artifacts
- Product/design gate hardening for downstream consumption
- Lifecycle retain threshold enforcement
- Context-budget allowlist expiry enforcement
- Hotfix-local small-chain evidence backfill in this directory

## Implementation Summary
- Fixed Director lock drift by aligning schema, templates, validator lock fields, standard-chain declarations, and fixture digests.
- Fixed Manager phase/UNIT drift by promoting business-flow fields, integration context, structured AC items, verification plans, and design-decision candidates into canonical truth and semantic validation.
- Strengthened `design` and product role gates so incomplete PM closure and placeholder UNIT semantics are rejected at the hook layer.
- Bound lifecycle `retain` to measured evidence and added positive/negative regression coverage.
- Made context-budget allowlist expiry enforceable and added a regression test for expiry failure.
- Backfilled this hotfix directory with replayable small-chain process evidence so closeout is not blocked on chat-only history.

## Historical RED Signals
- The initial RED signal for this hotfix was the user-supplied set of seven review findings, which identified concrete contract drift and gate gaps after the original redesign work had already landed.
- First review loop: code reviewer reported three blocking follow-up issues after the initial fixes.
- Second review loop: code reviewer reported one remaining hook-layer semantic gate gap for Product Manager UNIT validation.

## Fresh GREEN Evidence
- `bash tests/test-product-artifact-contract.sh` -> PASS
- `bash tests/test-skill-output-and-gate-contract.sh` -> PASS
- `bash tests/test-skill-lifecycle-eval-framework.sh` -> PASS
- `bash tests/test-standard-chain-foundation-registry.sh` -> PASS
- `bash tests/test-skill-context-budget.sh` -> PASS
- `bash tests/test-skill-context-budget-expiry.sh` -> PASS
- `bash tests/run-all.sh --quick --profile` -> PASS, `64/64 steps passed after review-loop follow-up fixes`
- `python3 -m json.tool docs/hotfix-20260423-0600-product-skill-contract-review-fix/fix-result.json >/dev/null` -> PASS
- `git diff --check` -> PASS

## Primary Files Touched
- `contracts/canonical/schemas/planning/brief.schema.json`
- `contracts/canonical/schemas/planning/phase-prd.schema.json`
- `contracts/canonical/schemas/planning/unit-definition.schema.json`
- `contracts/canonical/templates/planning/brief.template.json`
- `contracts/canonical/templates/planning/director/brief.template.json`
- `contracts/canonical/templates/planning/phase-prd.template.json`
- `contracts/canonical/templates/planning/unit-definition.template.json`
- `contracts/standard-chain.yaml`
- `tools/community/validate_product_closure.py`
- `shared/skills/design/SKILL.md`
- `shared/skills/design/scripts/completion_check.sh`
- `shared/skills/product-director/scripts/completion_check.sh`
- `shared/skills/product-manager/evals/evals.json`
- `shared/skills/product-manager/references/output-contract.md`
- `shared/skills/product-manager/scripts/completion_check.sh`
- `tests/test-product-artifact-contract.sh`
- `tests/test-product-role-split-contract.sh`
- `tests/test-skill-context-budget.sh`
- `tests/test-skill-context-budget-expiry.sh`
- `tests/test-skill-lifecycle-eval-framework.sh`
- `tests/test-skill-output-and-gate-contract.sh`
- `tests/test-standard-chain-foundation-registry.sh`
- Migrated pilot and fixture JSON under `docs/login-homepage-pilot/`, `docs/feedback-thanks-pilot/`, and `tests/fixtures/standard-chain-foundation/`

## Notes
- The original `product-skills-governance` small-chain package remains archived and unchanged.
- This report is a hotfix follow-up record. It documents completed implementation work and fresh proving evidence rather than replacing canonical runtime task artifacts from the archived package.
