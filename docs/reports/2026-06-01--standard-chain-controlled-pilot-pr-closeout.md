# Standard-chain Controlled Pilot PR Closeout

Date: 2026-06-01

## Conclusion

The current standard-chain worktree is acceptable for a Codex-only controlled pilot after the target-scope closeout fixes recorded here.

This closeout does not claim broad team rollout, all-runtime readiness, or a full gate pass. The repository full gate `bash tests/run-all.sh` was intentionally not run under the current user constraint.

## Target

Enable the standard-chain delivery flow to run a real, low-risk, end-to-end controlled pilot from business intent through delivery-owner closeout and user decision.

Primary pilot scope:

- Feature: `docs/feature--codex-controlled-pilot-consistency-auditor-rg-absence`
- Chain: `product-director -> product-manager -> design -> test-design -> tech-lead -> developer/verify/qa/review -> delivery-owner`
- Decision boundary: allow, block, rework, risk accept, or target-change
- Runtime source of truth: canonical JSON artifacts and active artifact registry

## Current Status

The controlled pilot feature directory recorded in this historical closeout has since been manually removed. Its active scope entry has been cleared from `contracts/active-doc-scope.yaml`; do not use this report as current handoff input or run the pilot-specific commands below unless the feature directory is intentionally restored.

## 1. PR Scope Classification

### Include in the standard-chain controlled pilot PR

These changes are in scope for the controlled pilot objective and should travel together because the contracts, validators, fixtures, and actual pilot artifacts depend on each other.

- `contracts/standard-chain.yaml`: DO-S8 split into DO-S8a/DO-S8b/DO-S8c, target-change consumer alignment, and consistency-auditor target-change input.
- `contracts/standard-chain-field-consumption.yaml`: target-change field consumer expansion and `target_change_payload_digest` audit consumption.
- `contracts/active-doc-scope.yaml`: active managed scope entry for the actual controlled pilot.
- `docs/feature--codex-controlled-pilot-consistency-auditor-rg-absence/**`: actual controlled pilot artifacts, worklog, history, replay oracle, projection view, signoff package, and user decision.
- `shared/skills/delivery-owner/SKILL.md`: delivery-owner closeout flow alignment with DO-S8a/DO-S8b/DO-S8c.
- `shared/skills/delivery-owner/contracts/signoff-package.schema.json`: final signoff package contract hardening.
- `shared/skills/delivery-owner/contracts/target-change.schema.json`: target-change invalidation, rebaseline, and payload digest contract.
- `shared/skills/delivery-owner/scripts/intake_preflight_check.py`: hard gate behavior for task contract and test-design obligation consumption.
- `shared/skills/delivery-owner/templates/target-change.template.json`: template alignment with the target-change contract.
- `shared/skills/product-manager/contracts/unit-definition.schema.json` and `shared/skills/product-manager/templates/unit-definition.template.json`: unit-definition contract alignment used by pilot fixtures and validators.
- `shared/skills/tech-lead/templates/tasks.template.json`: task registry contract alignment.
- `shared/skills/developer/scripts/preflight_check.py` and `shared/skills/verify/scripts/preflight_check.py`: task evidence anchor validation alignment.
- `tools/community/validate_standard_chain_phase.py`: catalog default path guard for target-change.
- `tools/community/validate_standard_chain_readiness.py` and `tools/community/readiness_*.py`: readiness closure, review, runtime, and signoff checks.
- `tools/community/validate_standard_chain_field_consumption.py`: required field-consumer guard for target-change payload digest.
- `tools/community/validate_standard_chain_field_decision_matrix.py`: target-change row consumer guard.
- `tools/community/standard_chain_negative_cases.py`: negative cases for readiness and contract gates.
- `tools/community/simple_json_schema.py`: schema support required by the hardened contracts.
- `tools/community/authority_proof.py` and `tools/community/write_user_decision.py`: authority proof and user decision support.
- `tools/community/canonical_test_case_rules.py`: test case canonical review guard used by synchronized fixtures.
- Standard-chain tests and fixtures touched by these contracts, including `tests/test-standard-chain-*.sh`, `tests/test-task-contract-consumer-alignment.sh`, `tests/test-skill-output-and-gate-contract.sh`, `tests/test_feedback_thanks_app.py`, and standard-chain fixture directories.
- `tests/lib/test-env.sh`: `assert_rg_no_match` helper that makes absence checks fail closed on `rg` errors.

### Needs user decision or separate PR

These changes may be valuable, but they are not required to prove the standard-chain controlled pilot and increase PR review surface.

- `docs/rule-runtime--team-readiness/**`
- `tools/community/validate_rule_runtime_run_record.py`
- `tests/test-rule-runtime-team-readiness-pack.sh`
- `install.sh`
- `tests/test-install-*.sh`
- `tests/lib/install-test-env.sh`
- Runtime rule/reference edits under `shared/rules/**` and `shared/reference/**`
- Broad skill governance tests and materials unrelated to the standard-chain pilot target

Recommendation: split these into a rule-runtime readiness / install cleanup PR unless the intended PR scope explicitly includes Codex-only runtime rollout preparation.

### Exclude or handle separately

These root-level historical or temporary materials should not be mixed into the standard-chain controlled pilot PR unless the PR explicitly includes root cleanup.

- `overview审查.md`: restored as a root transcript triage fixture because skill-quality-audit eval/test materials reference it.
- `review评审结果.md`: no active tracked reference found during this pass; handle as separate cleanup if desired.
- `一致性检查.md`: no active tracked reference found during this pass; handle as separate cleanup if desired.
- `一致性问题处理.md`: no active tracked reference found during this pass; handle as separate cleanup if desired.
- `精简复杂度.md`: no active tracked reference found during this pass; handle as separate cleanup if desired.
- `标准链 review.md`: historical review material; do not use as current fact source and do not include unless explicitly archived or converted into current evidence.

## 2. PR Delivery Package

### PR title

Enable standard-chain Codex controlled pilot readiness

### PR summary

This PR hardens the standard-chain contracts, validators, and runtime artifacts needed to run a real Codex-only controlled pilot. It closes target-change rebaseline drift, splits delivery-owner final closeout into signoff package preparation, user decision intake, and final readiness, makes `rg` absence gates fail closed, and records an actual controlled pilot feature under active context management.

### Acceptance scope

- Real low-risk demand can proceed through the standard-chain from brief to final delivery-owner signoff and user decision.
- target-change records cannot bypass affected downstream consumers or stale evidence checks.
- final closeout cannot pass with pending signoff or missing signed user decision.
- shell absence gates do not treat `rg` search errors as absence success.
- active pilot artifacts are recoverable through `contracts/active-doc-scope.yaml` and context validators.
- full gate remains explicitly unrun and must not be claimed.

### Not claimed

- Broad team rollout readiness.
- All-runtime readiness.
- Repository full gate pass.
- Any claim that fixture-only regression equals actual pilot completion.

## 3. Review Findings And Fixes

### Fixed target-scope P1

The actual pilot `design.json` runtime facts originally pointed to a non-existent fixture path under `tests/fixtures/standard-chain-foundation/golden-pilot/codex-controlled-pilot-consistency-auditor-rg-absence`. That made the actual pilot evidence boundary ambiguous.

Fix:

- Updated `docs/feature--codex-controlled-pilot-consistency-auditor-rg-absence/phase-1/design.json` runtime facts to point to the actual pilot artifacts under `docs/feature--codex-controlled-pilot-consistency-auditor-rg-absence/phase-1`.
- Recomputed and synchronized `review_closure.reviewed_design_digest` and reviewer digests.

Verification:

```bash
python3 shared/skills/design/scripts/review_digest.py --check docs/feature--codex-controlled-pilot-consistency-auditor-rg-absence/phase-1/design.json
```

Observed result: PASS with `sha256:27365b8437047650131f2c1ea7148302bd7da368523123297f5fd367b4a6c5de`.

### No remaining target-scope P0/P1 found

Read-only review did not find remaining target-scope P0/P1 blockers in:

- target-change consumer chain
- DO-S8a/DO-S8b/DO-S8c staging
- signoff and user-decision closure
- actual pilot readiness path
- fixture-only versus actual-pilot claim boundary
- full gate and all-runtime exclusion wording

## 4. Controlled Pilot Operating Rules

Use this standard-chain state only for controlled pilot operation unless broader evidence is gathered.

Pilot constraints:

- Pilot operator is explicitly assigned.
- Demand is real, low risk, end-to-end, and reversible.
- The feature is registered in `contracts/active-doc-scope.yaml`.
- Canonical JSON artifacts remain the runtime source of truth.
- `worklog.md` records navigation only; it must not replace canonical artifact state.
- Each stage consumes upstream canonical artifacts, not historical reports or fixture-only evidence.
- `target-change.json` is used for scope, AC, goal, or design target changes that invalidate baselines.
- `user-decision.json` is used for signoff or risk decision after signoff-package preparation.
- `signoff-package.json` must be CLOSED and SIGNED_OFF before readiness is claimed.
- Full gate remains separate and unclaimed unless explicitly run later.

Pilot failure handling:

- P0/P1 in target scope: add the smallest failing negative test first, make the minimal fix, then run the corresponding narrow proof.
- Out-of-scope findings: record and report; do not expand the current pilot closure claim.
- Fixture-only evidence: allowed for regression mechanism proof only, never as actual pilot completion evidence.

## 5. Merge Strategy And Final Commands

No files were staged or committed during this closeout.

Historical commands from the original closeout run:

Do not run full gate under the original user constraint:

```bash
bash tests/run-all.sh
```

These were the original commands recorded for that closeout. Pilot-specific commands now require the removed feature directory to be restored first:

```bash
git diff --check
```

```bash
python3 tools/community/validate_context_contract.py --repo-root /Users/lijieli/org-claude-skills
```

```bash
python3 shared/skills/design/scripts/review_digest.py --check docs/feature--codex-controlled-pilot-consistency-auditor-rg-absence/phase-1/design.json
```

```bash
python3 tools/community/validate_standard_chain_readiness.py \
  --phase-dir docs/feature--codex-controlled-pilot-consistency-auditor-rg-absence/phase-1 \
  --catalog shared/runtime/standard-chain-catalog.json \
  --profiles shared/runtime/replay-profiles.json
```

```bash
python3 tools/community/check_test_signal_assertions.py
```

```bash
bash tests/run-all.sh --quick
```

Current closeout evidence from this run:

- `git diff --check`: PASS
- `validate_context_contract.py`: PASS
- `review_digest.py --check` for actual pilot design: PASS
- actual pilot readiness validator: PASS
- `check_test_signal_assertions.py`: PASS
- `bash tests/run-all.sh --quick`: PASS, 28/28 checks

## Residual Risks

- Full gate was not run by constraint; do not claim full repository gate coverage.
- Current uncommitted closeout diff is small, but this branch contains prior standard-chain, rule-runtime, install, and cleanup commits. If the PR includes those commits, review the broader branch history as part of PR scope.
- `overview审查.md` is intentionally present as a skill-quality-audit eval fixture; do not delete it in this PR without migrating the eval reference.
- Rule-runtime readiness and install cleanup changes are meaningful but should be treated as separate rollout scope unless deliberately included.
