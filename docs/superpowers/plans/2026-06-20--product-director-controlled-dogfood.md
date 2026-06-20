# Product-director Controlled Dogfood Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the record templates, validator, and gate wiring for staged `product-director` real-transcript dogfood without starting a live dogfood run.

**Architecture:** Keep the dogfood package under `shared/skills/product-director/evals/dogfood/real-transcript-review/` as skill-local evaluation evidence, not as active standard-chain state. A Python validator enforces stage boundaries, record shape, privacy constraints, stop conditions, and promotion rules against static fixture records. A focused shell test owns red/green coverage and quick-gate integration.

**Tech Stack:** Bash test harness, Python 3 standard library, JSON record files, existing `tests/run-all.sh` and `tests/gate-plan.json`.

## Global Constraints

- Do not start a live dogfood run.
- Do not create or modify `contracts/active-doc-scope.yaml`.
- Do not create `brief.json`, `phase-prd.json`, `worklog.md`, or other standard-chain canonical artifacts.
- Do not run `delivery-owner` as a real delivery owner.
- Do not claim `product-director -> delivery-owner` full-chain readiness.
- Do not promote `product-director` to daily/default use, simple-request handling, or full standard-chain replacement.
- Route decisions stay inline and non-persistent; do not create a route-decision artifact.
- The 5-transcript requirement is a promotion gate, not a start-up prerequisite.
- Fixtures must be synthetic and redacted; no raw secrets, credentials, private user data, or customer-identifying details may be committed.

---

## File Structure

- Create `shared/skills/product-director/evals/dogfood/real-transcript-review/README.md`
  - Explains that this directory contains templates and synthetic fixtures for future staged real-transcript reviews.
- Create `shared/skills/product-director/evals/dogfood/real-transcript-review/plan.template.json`
  - Template for a future run plan. It defines stage, sample target, allowed demand classes, reviewer, stop conditions, and promotion target.
- Create `shared/skills/product-director/evals/dogfood/real-transcript-review/review.template.json`
  - Template for one transcript review record.
- Create `shared/skills/product-director/evals/dogfood/real-transcript-review/summary.template.json`
  - Template for aggregate stage or promotion summary.
- Create `shared/skills/product-director/evals/dogfood/real-transcript-review/fixtures/valid-stage1-smoke/`
  - Synthetic valid one-transcript smoke package.
- Create `shared/skills/product-director/evals/dogfood/real-transcript-review/fixtures/invalid-promotion-with-four-transcripts/`
  - Synthetic invalid package proving 5 transcripts are required only for promotion.
- Create `shared/skills/product-director/evals/dogfood/real-transcript-review/fixtures/invalid-persistent-route-state/`
  - Synthetic invalid package proving route decisions cannot become persistent runtime state.
- Create `shared/skills/product-director/scripts/validate_real_transcript_dogfood.py`
  - Validates templates and package directories.
- Create `tests/test-product-director-real-transcript-dogfood.sh`
  - Owns red/green contract tests for validator and fixtures.
- Modify `tests/run-all.sh`
  - Add the new shell test to syntax checks.
- Modify `tests/gate-plan.json`
  - Add the new test as a quick product/team-pilot canary.
- Modify `findings.md` and `progress.md`
  - Record that the implementation plan exists and no dogfood run has started.

---

### Task 1: Lock The Dogfood Record Contract

**Files:**
- Create: `tests/test-product-director-real-transcript-dogfood.sh`
- Create: `shared/skills/product-director/evals/dogfood/real-transcript-review/README.md`
- Create: `shared/skills/product-director/evals/dogfood/real-transcript-review/plan.template.json`
- Create: `shared/skills/product-director/evals/dogfood/real-transcript-review/review.template.json`
- Create: `shared/skills/product-director/evals/dogfood/real-transcript-review/summary.template.json`

**Interfaces:**
- Consumes: `shared/skills/product-director/evals/dogfood/team-pilot-readiness.json`
- Produces:
  - `plan.template.json` object with `artifact_type = "product-director-real-transcript-dogfood-plan"`
  - `review.template.json` object with `artifact_type = "product-director-real-transcript-review"`
  - `summary.template.json` object with `artifact_type = "product-director-real-transcript-summary"`

- [ ] **Step 1: Write the failing shell test skeleton**

Create `tests/test-product-director-real-transcript-dogfood.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$ROOT/shared/skills/product-director/evals/dogfood/real-transcript-review"
VALIDATOR="$ROOT/shared/skills/product-director/scripts/validate_real_transcript_dogfood.py"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

test -f "$BASE/plan.template.json" || fail "missing plan template"
test -f "$BASE/review.template.json" || fail "missing review template"
test -f "$BASE/summary.template.json" || fail "missing summary template"
test -f "$BASE/README.md" || fail "missing README"
test -f "$VALIDATOR" || fail "missing validator"

python3 "$VALIDATOR" --check-template "$BASE/plan.template.json"
python3 "$VALIDATOR" --check-template "$BASE/review.template.json"
python3 "$VALIDATOR" --check-template "$BASE/summary.template.json"

printf '[PASS] product-director real transcript dogfood\n'
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
bash tests/test-product-director-real-transcript-dogfood.sh
```

Expected: FAIL with `missing plan template`.

- [ ] **Step 3: Create the directory README**

Create `shared/skills/product-director/evals/dogfood/real-transcript-review/README.md`:

```markdown
# Product-director Real Transcript Dogfood

This directory defines templates and synthetic fixtures for staged `product-director` dogfood review.

It does not contain active standard-chain state, does not create `brief.json` or `phase-prd.json`, and does not start a dogfood run.

Use this package only after a real complex-demand candidate has been selected and transcript evidence handling has been confirmed.

Stages:

- Stage 1: one-transcript smoke.
- Stage 2: three-transcript stability sample.
- Stage 3: five-transcript promotion gate.

Promotion target is limited to `default_complex_demand_entry`.
```

- [ ] **Step 4: Create `plan.template.json`**

Create `shared/skills/product-director/evals/dogfood/real-transcript-review/plan.template.json`:

```json
{
  "artifact_type": "product-director-real-transcript-dogfood-plan",
  "schema_version": "0.1.0",
  "skill_under_test": "shared/skills/product-director",
  "stage": "STAGE_1_SMOKE",
  "sample_target": 1,
  "promotion_required_transcripts": 5,
  "promotion_target": "default_complex_demand_entry",
  "allowed_demand_classes": [
    "business_growth",
    "stability_or_technical_debt",
    "workflow_or_compliance"
  ],
  "review_dimensions_ref": "shared/skills/product-director/evals/dogfood/team-pilot-readiness.json#/review_dimensions",
  "route_policy_ref": "contracts/standard-chain-invocation-policy.yaml",
  "non_goals": [
    "do_not_start_live_dogfood_from_template",
    "do_not_create_active_doc_scope",
    "do_not_create_standard_chain_canonical_artifacts",
    "do_not_claim_full_chain_readiness",
    "do_not_run_delivery_owner_real_delivery"
  ],
  "stop_conditions": [
    "premature_final_artifact_write",
    "inferred_fact_treated_as_confirmed",
    "stage_jump_before_director_confirmation",
    "bundled_survey_questioning",
    "simple_request_forced_into_director",
    "unreviewable_transcript_evidence",
    "user_rejects_interaction_cost"
  ],
  "evidence_policy": {
    "raw_transcript_in_repo_allowed": false,
    "requires_redacted_excerpt_or_external_digest": true,
    "forbids_raw_secrets_or_customer_identifiers": true
  },
  "reviewer": "independent-reviewer",
  "created_at": "2026-06-20"
}
```

- [ ] **Step 5: Create `review.template.json`**

Create `shared/skills/product-director/evals/dogfood/real-transcript-review/review.template.json`:

```json
{
  "artifact_type": "product-director-real-transcript-review",
  "schema_version": "0.1.0",
  "review_id": "PD-DOGFOOD-001",
  "stage": "STAGE_1_SMOKE",
  "request_summary": "Finance operations needs a reliable overdue invoice follow-up baseline.",
  "demand_class": "business_growth",
  "route_rationale": {
    "matched_signal": "PD-ROUTE-003",
    "decision": "manual_invoke_product_director",
    "basis_ref": "contracts/standard-chain-invocation-policy.yaml",
    "persistent_state_created": false
  },
  "transcript_ref": {
    "storage": "external_redacted_or_digest",
    "ref": "external://secure-transcript-store/PD-DOGFOOD-001-redacted",
    "digest": "sha256:1111111111111111111111111111111111111111111111111111111111111111",
    "redacted_excerpt_ref": "reviews/PD-DOGFOOD-001.excerpt.md"
  },
  "transcript_redaction_status": "redacted_excerpt_sufficient",
  "dimension_verdicts": [
    {
      "id": "no_interrogation",
      "verdict": "PASS",
      "evidence_ref": "reviews/PD-DOGFOOD-001.excerpt.md#turn-2",
      "reason": "The skill asked one decision-changing blocking fact and explained why it mattered.",
      "impact": "none"
    },
    {
      "id": "no_pretend_closure",
      "verdict": "PASS",
      "evidence_ref": "reviews/PD-DOGFOOD-001.excerpt.md#turn-4",
      "reason": "Unknown, inferred, and user-confirmed facts remained separated.",
      "impact": "none"
    },
    {
      "id": "no_stage_jump",
      "verdict": "PASS",
      "evidence_ref": "reviews/PD-DOGFOOD-001.excerpt.md#stage-map",
      "reason": "The transcript stayed in the active Director stage before advancing.",
      "impact": "none"
    },
    {
      "id": "success_standard_closure",
      "verdict": "PASS",
      "evidence_ref": "reviews/PD-DOGFOOD-001.excerpt.md#success-standard",
      "reason": "Current baseline, target direction, observation window, data source, and failure signal were closed or explicitly blocked.",
      "impact": "none"
    },
    {
      "id": "director_why_only",
      "verdict": "PASS",
      "evidence_ref": "reviews/PD-DOGFOOD-001.excerpt.md#recommendation",
      "reason": "The output stayed at root problem, success standard, scope boundary, risk, and phase slice.",
      "impact": "none"
    },
    {
      "id": "explicit_confirmation_before_finalization",
      "verdict": "PASS",
      "evidence_ref": "reviews/PD-DOGFOOD-001.excerpt.md#confirmation",
      "reason": "Finalization was blocked until explicit product director confirmation.",
      "impact": "none"
    },
    {
      "id": "handoff_to_product_manager_only",
      "verdict": "PASS",
      "evidence_ref": "reviews/PD-DOGFOOD-001.excerpt.md#handoff",
      "reason": "The only allowed downstream target after final gates was product-manager.",
      "impact": "none"
    },
    {
      "id": "simple_request_reroute",
      "verdict": "NOT_APPLICABLE",
      "evidence_ref": "reviews/PD-DOGFOOD-001.excerpt.md#route",
      "reason": "The candidate was a complex demand, not a simple request.",
      "impact": "none"
    }
  ],
  "baseline_risk_review": {
    "likely_without_skill_failure": "fake_closure_or_unclear_success_standard",
    "skill_prevented_failure": true,
    "process_cost_observed": "acceptable_for_complex_demand"
  },
  "blocking_findings": [],
  "expansion_decision": "EXPAND_TO_STAGE_2",
  "reviewer": "independent-reviewer",
  "reviewed_at": "2026-06-20"
}
```

- [ ] **Step 6: Create `summary.template.json`**

Create `shared/skills/product-director/evals/dogfood/real-transcript-review/summary.template.json`:

```json
{
  "artifact_type": "product-director-real-transcript-summary",
  "schema_version": "0.1.0",
  "stage": "STAGE_1_SMOKE",
  "reviews": [
    "reviews/PD-DOGFOOD-001.json"
  ],
  "review_count": 1,
  "in_scope_blocker_count": 0,
  "warning_patterns": [],
  "promotion_effect": "NOT_PROMOTION_SAMPLE_YET",
  "next_action": "EXPAND_TO_STAGE_2",
  "does_not_claim": [
    "full_chain_readiness",
    "delivery_owner_real_delivery_readiness",
    "daily_default_skill_readiness"
  ]
}
```

- [ ] **Step 7: Run the test to verify the next failure**

Run:

```bash
bash tests/test-product-director-real-transcript-dogfood.sh
```

Expected: FAIL with `missing validator`.

---

### Task 2: Implement Validator And Synthetic Fixtures

**Files:**
- Create: `shared/skills/product-director/scripts/validate_real_transcript_dogfood.py`
- Create: `shared/skills/product-director/evals/dogfood/real-transcript-review/fixtures/valid-stage1-smoke/plan.json`
- Create: `shared/skills/product-director/evals/dogfood/real-transcript-review/fixtures/valid-stage1-smoke/reviews/PD-DOGFOOD-001.json`
- Create: `shared/skills/product-director/evals/dogfood/real-transcript-review/fixtures/valid-stage1-smoke/reviews/PD-DOGFOOD-001.excerpt.md`
- Create: `shared/skills/product-director/evals/dogfood/real-transcript-review/fixtures/valid-stage1-smoke/summary.json`
- Create: `shared/skills/product-director/evals/dogfood/real-transcript-review/fixtures/invalid-promotion-with-four-transcripts/plan.json`
- Create: `shared/skills/product-director/evals/dogfood/real-transcript-review/fixtures/invalid-persistent-route-state/plan.json`
- Modify: `tests/test-product-director-real-transcript-dogfood.sh`

**Interfaces:**
- Consumes:
  - `--check-template <json>`
  - `--check-package <dir>`
- Produces:
  - Exit 0 for valid templates and valid package.
  - Exit non-zero with `[FAIL]` for invalid packages.

- [ ] **Step 1: Extend the failing test for fixture validation**

Append this block before the final PASS line in `tests/test-product-director-real-transcript-dogfood.sh`:

```bash
VALID_FIXTURE="$BASE/fixtures/valid-stage1-smoke"
INVALID_PROMOTION="$BASE/fixtures/invalid-promotion-with-four-transcripts"
INVALID_ROUTE_STATE="$BASE/fixtures/invalid-persistent-route-state"

python3 "$VALIDATOR" --check-package "$VALID_FIXTURE"

if python3 "$VALIDATOR" --check-package "$INVALID_PROMOTION" >/tmp/product-director-invalid-promotion.out 2>&1; then
  fail "invalid promotion fixture unexpectedly passed"
fi
rg -n "promotion requires 5 complete reviews" /tmp/product-director-invalid-promotion.out >/dev/null \
  || fail "invalid promotion fixture failed for the wrong reason"

if python3 "$VALIDATOR" --check-package "$INVALID_ROUTE_STATE" >/tmp/product-director-invalid-route.out 2>&1; then
  fail "invalid persistent route fixture unexpectedly passed"
fi
rg -n "route decisions must remain inline and non-persistent" /tmp/product-director-invalid-route.out >/dev/null \
  || fail "invalid persistent route fixture failed for the wrong reason"
```

- [ ] **Step 2: Run the test to verify it fails on the missing validator**

Run:

```bash
bash tests/test-product-director-real-transcript-dogfood.sh
```

Expected: FAIL with `missing validator`.

- [ ] **Step 3: Implement `validate_real_transcript_dogfood.py`**

Create `shared/skills/product-director/scripts/validate_real_transcript_dogfood.py`:

```python
#!/usr/bin/env python3
"""Validate product-director real transcript dogfood templates and packages."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

REQUIRED_DIMENSIONS = {
    "no_interrogation",
    "no_pretend_closure",
    "no_stage_jump",
    "success_standard_closure",
    "director_why_only",
    "explicit_confirmation_before_finalization",
    "handoff_to_product_manager_only",
    "simple_request_reroute",
}

VALID_REVIEW_VERDICTS = {"PASS", "FAIL", "BLOCKED", "NOT_APPLICABLE"}
VALID_STAGE_DECISIONS = {
    "EXPAND_TO_STAGE_2",
    "STOP_FOR_REPAIR",
    "COLLECT_MORE_STAGE_2_SAMPLE",
    "PROMOTION_ALLOWED_FOR_COMPLEX_DEMAND_ENTRY",
    "PROMOTION_BLOCKED",
}


def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def load_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        fail(f"{path}: file does not exist")
    except json.JSONDecodeError as exc:
        fail(f"{path}: invalid JSON: {exc}")
    require(isinstance(data, dict), f"{path}: must be a JSON object")
    return data


def require_text(value: Any, label: str) -> str:
    require(isinstance(value, str) and value.strip(), f"{label} is required")
    return str(value)


def require_bool(value: Any, label: str) -> bool:
    require(isinstance(value, bool), f"{label} must be boolean")
    return bool(value)


def check_template(path: Path) -> None:
    data = load_json(path)
    artifact_type = data.get("artifact_type")
    allowed = {
        "product-director-real-transcript-dogfood-plan",
        "product-director-real-transcript-review",
        "product-director-real-transcript-summary",
    }
    require(artifact_type in allowed, f"{path}: unsupported artifact_type {artifact_type!r}")
    require(data.get("schema_version") == "0.1.0", f"{path}: schema_version must be 0.1.0")
    if artifact_type == "product-director-real-transcript-dogfood-plan":
        validate_plan(data, path.parent, template=True)
    elif artifact_type == "product-director-real-transcript-review":
        validate_review(data, path.parent, template=True)
    else:
        validate_summary(data, [], template=True)


def validate_plan(plan: dict[str, Any], root: Path, template: bool = False) -> None:
    require(plan.get("artifact_type") == "product-director-real-transcript-dogfood-plan", "plan artifact_type drift")
    require(plan.get("schema_version") == "0.1.0", "plan schema_version drift")
    require(plan.get("skill_under_test") == "shared/skills/product-director", "plan skill_under_test drift")
    stage = require_text(plan.get("stage"), "plan.stage")
    require(stage in {"STAGE_1_SMOKE", "STAGE_2_STABILITY", "STAGE_3_PROMOTION"}, "plan.stage invalid")
    sample_target = plan.get("sample_target")
    require(isinstance(sample_target, int) and sample_target >= 1, "plan.sample_target must be a positive integer")
    require(plan.get("promotion_required_transcripts") == 5, "plan.promotion_required_transcripts must be 5")
    require(plan.get("promotion_target") == "default_complex_demand_entry", "plan.promotion_target drift")
    demand_classes = plan.get("allowed_demand_classes")
    require(isinstance(demand_classes, list) and demand_classes, "plan.allowed_demand_classes must be a non-empty array")
    for demand_class in demand_classes:
        require(demand_class in {"business_growth", "stability_or_technical_debt", "workflow_or_compliance"}, f"plan.allowed_demand_classes invalid: {demand_class!r}")
    require(plan.get("review_dimensions_ref") == "shared/skills/product-director/evals/dogfood/team-pilot-readiness.json#/review_dimensions", "plan.review_dimensions_ref drift")
    require(plan.get("route_policy_ref") == "contracts/standard-chain-invocation-policy.yaml", "plan.route_policy_ref drift")
    non_goals = set(plan.get("non_goals", []))
    required_non_goals = {
        "do_not_start_live_dogfood_from_template",
        "do_not_create_active_doc_scope",
        "do_not_create_standard_chain_canonical_artifacts",
        "do_not_claim_full_chain_readiness",
        "do_not_run_delivery_owner_real_delivery",
    }
    missing_non_goals = sorted(required_non_goals - non_goals)
    require(not missing_non_goals, f"plan.non_goals missing {missing_non_goals}")
    stop_conditions = set(plan.get("stop_conditions", []))
    required_stop_conditions = {
        "premature_final_artifact_write",
        "inferred_fact_treated_as_confirmed",
        "stage_jump_before_director_confirmation",
        "bundled_survey_questioning",
        "simple_request_forced_into_director",
        "unreviewable_transcript_evidence",
        "user_rejects_interaction_cost",
    }
    missing_stop_conditions = sorted(required_stop_conditions - stop_conditions)
    require(not missing_stop_conditions, f"plan.stop_conditions missing {missing_stop_conditions}")
    evidence_policy = plan.get("evidence_policy")
    require(isinstance(evidence_policy, dict), "plan.evidence_policy must be an object")
    require(evidence_policy.get("raw_transcript_in_repo_allowed") is False, "raw transcripts must not be allowed in repo")
    require(evidence_policy.get("requires_redacted_excerpt_or_external_digest") is True, "redacted excerpt or digest required")
    require(evidence_policy.get("forbids_raw_secrets_or_customer_identifiers") is True, "raw secrets/customer identifiers must be forbidden")
    if stage == "STAGE_1_SMOKE":
        require(sample_target == 1, "STAGE_1_SMOKE sample_target must be 1")
    if stage == "STAGE_2_STABILITY":
        require(sample_target == 3, "STAGE_2_STABILITY sample_target must be 3")
    if stage == "STAGE_3_PROMOTION":
        require(sample_target == 5, "STAGE_3_PROMOTION sample_target must be 5")
    if not template:
        require_text(plan.get("reviewer"), "plan.reviewer")
        require_text(plan.get("created_at"), "plan.created_at")


def validate_review(review: dict[str, Any], root: Path, template: bool = False) -> None:
    require(review.get("artifact_type") == "product-director-real-transcript-review", "review artifact_type drift")
    require(review.get("schema_version") == "0.1.0", "review schema_version drift")
    require_text(review.get("review_id"), "review.review_id")
    stage = require_text(review.get("stage"), "review.stage")
    require(stage in {"STAGE_1_SMOKE", "STAGE_2_STABILITY", "STAGE_3_PROMOTION"}, "review.stage invalid")
    require_text(review.get("request_summary"), "review.request_summary")
    demand_class = require_text(review.get("demand_class"), "review.demand_class")
    require(demand_class in {"business_growth", "stability_or_technical_debt", "workflow_or_compliance"}, "review.demand_class invalid")
    route = review.get("route_rationale")
    require(isinstance(route, dict), "review.route_rationale must be an object")
    require_text(route.get("matched_signal"), "review.route_rationale.matched_signal")
    require(route.get("decision") == "manual_invoke_product_director", "review.route_rationale.decision must manually invoke product-director")
    require(route.get("basis_ref") == "contracts/standard-chain-invocation-policy.yaml", "review.route_rationale.basis_ref drift")
    require_bool(route.get("persistent_state_created"), "review.route_rationale.persistent_state_created")
    require(route.get("persistent_state_created") is False, "route decisions must remain inline and non-persistent")
    transcript = review.get("transcript_ref")
    require(isinstance(transcript, dict), "review.transcript_ref must be an object")
    require(transcript.get("storage") != "raw_repo_transcript", "raw transcript storage in repo is not allowed")
    digest = require_text(transcript.get("digest"), "review.transcript_ref.digest")
    require(digest.startswith("sha256:"), "review.transcript_ref.digest must start with sha256:")
    excerpt = require_text(transcript.get("redacted_excerpt_ref"), "review.transcript_ref.redacted_excerpt_ref")
    require(review.get("transcript_redaction_status") in {"redacted_excerpt_sufficient", "external_digest_with_excerpt", "reviewer_note_only_limited"}, "review.transcript_redaction_status invalid")
    if not template:
        excerpt_path = root / excerpt
        require(excerpt_path.is_file(), f"redacted excerpt missing: {excerpt}")
        require(excerpt_path.read_text(encoding="utf-8").strip(), f"redacted excerpt empty: {excerpt}")
    dimensions = review.get("dimension_verdicts")
    require(isinstance(dimensions, list), "review.dimension_verdicts must be an array")
    by_id = {item.get("id"): item for item in dimensions if isinstance(item, dict)}
    missing = sorted(REQUIRED_DIMENSIONS - set(by_id))
    require(not missing, f"review.dimension_verdicts missing {missing}")
    for dimension_id, item in by_id.items():
        if dimension_id not in REQUIRED_DIMENSIONS:
            continue
        require(item.get("verdict") in VALID_REVIEW_VERDICTS, f"{dimension_id}.verdict invalid")
        require_text(item.get("evidence_ref"), f"{dimension_id}.evidence_ref")
        require_text(item.get("reason"), f"{dimension_id}.reason")
        require_text(item.get("impact"), f"{dimension_id}.impact")
    baseline = review.get("baseline_risk_review")
    require(isinstance(baseline, dict), "review.baseline_risk_review must be an object")
    require_text(baseline.get("likely_without_skill_failure"), "baseline_risk_review.likely_without_skill_failure")
    require_bool(baseline.get("skill_prevented_failure"), "baseline_risk_review.skill_prevented_failure")
    require_text(baseline.get("process_cost_observed"), "baseline_risk_review.process_cost_observed")
    blocking_findings = review.get("blocking_findings")
    require(isinstance(blocking_findings, list), "review.blocking_findings must be an array")
    require(review.get("expansion_decision") in VALID_STAGE_DECISIONS, "review.expansion_decision invalid")
    if blocking_findings:
        require(review.get("expansion_decision") in {"STOP_FOR_REPAIR", "PROMOTION_BLOCKED"}, "blocking findings require a blocking expansion decision")
    require_text(review.get("reviewer"), "review.reviewer")
    require_text(review.get("reviewed_at"), "review.reviewed_at")


def validate_summary(summary: dict[str, Any], review_paths: list[Path], template: bool = False) -> None:
    require(summary.get("artifact_type") == "product-director-real-transcript-summary", "summary artifact_type drift")
    require(summary.get("schema_version") == "0.1.0", "summary schema_version drift")
    stage = require_text(summary.get("stage"), "summary.stage")
    review_count = summary.get("review_count")
    require(isinstance(review_count, int) and review_count >= 1, "summary.review_count must be a positive integer")
    if not template:
        require(review_count == len(review_paths), "summary.review_count must match review files")
    blocker_count = summary.get("in_scope_blocker_count")
    require(isinstance(blocker_count, int) and blocker_count >= 0, "summary.in_scope_blocker_count must be >= 0")
    summary_reviews = summary.get("reviews")
    require(isinstance(summary_reviews, list) and summary_reviews, "summary.reviews must be a non-empty array")
    for review_ref in summary_reviews:
        require(isinstance(review_ref, str) and review_ref.startswith("reviews/") and review_ref.endswith(".json"), f"summary.reviews invalid: {review_ref!r}")
    if not template:
        expected_review_refs = [f"reviews/{review_path.name}" for review_path in review_paths]
        require(summary_reviews == expected_review_refs, "summary.reviews must match review files")
    next_action = require_text(summary.get("next_action"), "summary.next_action")
    require(next_action in VALID_STAGE_DECISIONS, "summary.next_action invalid")
    does_not_claim = set(summary.get("does_not_claim", []))
    missing_claims = sorted({"full_chain_readiness", "delivery_owner_real_delivery_readiness", "daily_default_skill_readiness"} - does_not_claim)
    require(not missing_claims, f"summary.does_not_claim missing {missing_claims}")
    if stage == "STAGE_3_PROMOTION" and next_action == "PROMOTION_ALLOWED_FOR_COMPLEX_DEMAND_ENTRY":
        require(review_count >= 5, "promotion requires 5 complete reviews")
        require(blocker_count == 0, "promotion requires zero in-scope blockers")


def check_package(path: Path) -> None:
    plan = load_json(path / "plan.json")
    validate_plan(plan, path)
    review_paths = sorted((path / "reviews").glob("*.json"))
    require(review_paths, f"{path}: package must include reviews/*.json")
    reviews = []
    for review_path in review_paths:
        review = load_json(review_path)
        validate_review(review, path)
        reviews.append(review)
    summary = load_json(path / "summary.json")
    validate_summary(summary, review_paths)
    require(summary.get("stage") == plan["stage"], "summary.stage must match plan.stage")
    for review in reviews:
        require(review.get("stage") == plan["stage"], "review.stage must match plan.stage")
    if plan["stage"] == "STAGE_1_SMOKE":
        require(len(reviews) == 1, "STAGE_1_SMOKE requires exactly one review")
    if plan["stage"] == "STAGE_3_PROMOTION" and summary.get("next_action") == "PROMOTION_ALLOWED_FOR_COMPLEX_DEMAND_ENTRY":
        require(len(reviews) >= 5, "promotion requires 5 complete reviews")


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--check-template", type=Path)
    group.add_argument("--check-package", type=Path)
    args = parser.parse_args()
    if args.check_template:
        check_template(args.check_template)
    else:
        check_package(args.check_package)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Create valid Stage 1 fixture**

Create `shared/skills/product-director/evals/dogfood/real-transcript-review/fixtures/valid-stage1-smoke/plan.json`:

```json
{
  "artifact_type": "product-director-real-transcript-dogfood-plan",
  "schema_version": "0.1.0",
  "skill_under_test": "shared/skills/product-director",
  "stage": "STAGE_1_SMOKE",
  "sample_target": 1,
  "promotion_required_transcripts": 5,
  "promotion_target": "default_complex_demand_entry",
  "allowed_demand_classes": [
    "business_growth",
    "stability_or_technical_debt",
    "workflow_or_compliance"
  ],
  "review_dimensions_ref": "shared/skills/product-director/evals/dogfood/team-pilot-readiness.json#/review_dimensions",
  "route_policy_ref": "contracts/standard-chain-invocation-policy.yaml",
  "non_goals": [
    "do_not_start_live_dogfood_from_template",
    "do_not_create_active_doc_scope",
    "do_not_create_standard_chain_canonical_artifacts",
    "do_not_claim_full_chain_readiness",
    "do_not_run_delivery_owner_real_delivery"
  ],
  "stop_conditions": [
    "premature_final_artifact_write",
    "inferred_fact_treated_as_confirmed",
    "stage_jump_before_director_confirmation",
    "bundled_survey_questioning",
    "simple_request_forced_into_director",
    "unreviewable_transcript_evidence",
    "user_rejects_interaction_cost"
  ],
  "evidence_policy": {
    "raw_transcript_in_repo_allowed": false,
    "requires_redacted_excerpt_or_external_digest": true,
    "forbids_raw_secrets_or_customer_identifiers": true
  },
  "reviewer": "independent-reviewer",
  "created_at": "2026-06-20"
}
```

Create `shared/skills/product-director/evals/dogfood/real-transcript-review/fixtures/valid-stage1-smoke/reviews/PD-DOGFOOD-001.excerpt.md`:

```markdown
# Redacted Excerpt

## turn-2
The skill asks one blocking fact: which current success signal proves the demand is worth a Director baseline?

## turn-4
The review separates user-confirmed facts from inferred assumptions.

## stage-map
The conversation remains in Director problem and success-standard closure before recommendation.

## success-standard
Current baseline, target direction, observation window, data source, and failure signal are represented.

## recommendation
The recommendation stays at root problem, success standard, scope boundary, risk, and phase slice.

## confirmation
The transcript blocks finalization until explicit product director confirmation.

## handoff
The only downstream handoff target is product-manager.

## route
The request is a complex-demand intake candidate.
```

Run this command to create the valid Stage 1 review and summary records from the templates:

```bash
python3 - <<'PY'
import json
from pathlib import Path

base = Path("shared/skills/product-director/evals/dogfood/real-transcript-review")
fixture = base / "fixtures/valid-stage1-smoke"
reviews = fixture / "reviews"
reviews.mkdir(parents=True, exist_ok=True)

review = json.loads((base / "review.template.json").read_text(encoding="utf-8"))
(reviews / "PD-DOGFOOD-001.json").write_text(
    json.dumps(review, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)

summary = json.loads((base / "summary.template.json").read_text(encoding="utf-8"))
(fixture / "summary.json").write_text(
    json.dumps(summary, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)
PY
```

- [ ] **Step 5: Create invalid promotion fixture**

Create `shared/skills/product-director/evals/dogfood/real-transcript-review/fixtures/invalid-promotion-with-four-transcripts/plan.json`:

```json
{
  "artifact_type": "product-director-real-transcript-dogfood-plan",
  "schema_version": "0.1.0",
  "skill_under_test": "shared/skills/product-director",
  "stage": "STAGE_3_PROMOTION",
  "sample_target": 5,
  "promotion_required_transcripts": 5,
  "promotion_target": "default_complex_demand_entry",
  "allowed_demand_classes": [
    "business_growth"
  ],
  "review_dimensions_ref": "shared/skills/product-director/evals/dogfood/team-pilot-readiness.json#/review_dimensions",
  "route_policy_ref": "contracts/standard-chain-invocation-policy.yaml",
  "non_goals": [
    "do_not_start_live_dogfood_from_template",
    "do_not_create_active_doc_scope",
    "do_not_create_standard_chain_canonical_artifacts",
    "do_not_claim_full_chain_readiness",
    "do_not_run_delivery_owner_real_delivery"
  ],
  "stop_conditions": [
    "premature_final_artifact_write",
    "inferred_fact_treated_as_confirmed",
    "stage_jump_before_director_confirmation",
    "bundled_survey_questioning",
    "simple_request_forced_into_director",
    "unreviewable_transcript_evidence",
    "user_rejects_interaction_cost"
  ],
  "evidence_policy": {
    "raw_transcript_in_repo_allowed": false,
    "requires_redacted_excerpt_or_external_digest": true,
    "forbids_raw_secrets_or_customer_identifiers": true
  },
  "reviewer": "independent-reviewer",
  "created_at": "2026-06-20"
}
```

Run this command to create four Stage 3 review JSON files and redacted excerpts:

```bash
python3 - <<'PY'
import json
from pathlib import Path

base = Path("shared/skills/product-director/evals/dogfood/real-transcript-review")
fixture = base / "fixtures/invalid-promotion-with-four-transcripts"
reviews = fixture / "reviews"
reviews.mkdir(parents=True, exist_ok=True)

template = json.loads((base / "review.template.json").read_text(encoding="utf-8"))
excerpt_template = """# Redacted Excerpt

## turn-2
The skill asks one blocking fact for {review_id}.

## turn-4
The review separates user-confirmed facts from inferred assumptions for {review_id}.

## stage-map
The conversation remains in the Director stage for {review_id}.

## success-standard
The success standard is represented for {review_id}.

## recommendation
The recommendation stays at Director-level scope for {review_id}.

## confirmation
The transcript blocks finalization until confirmation for {review_id}.

## handoff
The only downstream handoff target is product-manager for {review_id}.

## route
The request is a complex-demand intake candidate for {review_id}.
"""

for index in range(1, 5):
    review_id = f"PD-DOGFOOD-{index:03d}"
    review = json.loads(json.dumps(template))
    review["review_id"] = review_id
    review["stage"] = "STAGE_3_PROMOTION"
    review["transcript_ref"]["ref"] = f"external://secure-transcript-store/{review_id}-redacted"
    review["transcript_ref"]["digest"] = f"sha256:{str(index) * 64}"
    review["transcript_ref"]["redacted_excerpt_ref"] = f"reviews/{review_id}.excerpt.md"
    for dimension in review["dimension_verdicts"]:
        dimension["evidence_ref"] = dimension["evidence_ref"].replace("PD-DOGFOOD-001", review_id)
    (reviews / f"{review_id}.json").write_text(
        json.dumps(review, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    (reviews / f"{review_id}.excerpt.md").write_text(
        excerpt_template.format(review_id=review_id),
        encoding="utf-8",
    )
PY
```

Create `shared/skills/product-director/evals/dogfood/real-transcript-review/fixtures/invalid-promotion-with-four-transcripts/summary.json`:

```json
{
  "artifact_type": "product-director-real-transcript-summary",
  "schema_version": "0.1.0",
  "stage": "STAGE_3_PROMOTION",
  "reviews": [
    "reviews/PD-DOGFOOD-001.json",
    "reviews/PD-DOGFOOD-002.json",
    "reviews/PD-DOGFOOD-003.json",
    "reviews/PD-DOGFOOD-004.json"
  ],
  "review_count": 4,
  "in_scope_blocker_count": 0,
  "warning_patterns": [],
  "promotion_effect": "PROMOTION_REQUESTED",
  "next_action": "PROMOTION_ALLOWED_FOR_COMPLEX_DEMAND_ENTRY",
  "does_not_claim": [
    "full_chain_readiness",
    "delivery_owner_real_delivery_readiness",
    "daily_default_skill_readiness"
  ]
}
```

- [ ] **Step 6: Create invalid persistent route fixture**

Run this command to create `shared/skills/product-director/evals/dogfood/real-transcript-review/fixtures/invalid-persistent-route-state/` with a route-state violation:

```bash
python3 - <<'PY'
import json
import shutil
from pathlib import Path

base = Path("shared/skills/product-director/evals/dogfood/real-transcript-review/fixtures")
source = base / "valid-stage1-smoke"
target = base / "invalid-persistent-route-state"
if target.exists():
    shutil.rmtree(target)
shutil.copytree(source, target)

review_path = target / "reviews/PD-DOGFOOD-001.json"
review = json.loads(review_path.read_text(encoding="utf-8"))
review["route_rationale"]["persistent_state_created"] = True
review_path.write_text(
    json.dumps(review, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)
PY
```

- [ ] **Step 7: Run fixture test**

Run:

```bash
bash tests/test-product-director-real-transcript-dogfood.sh
```

Expected: PASS with `[PASS] product-director real transcript dogfood`.

---

### Task 3: Wire Gate Plan And Documentation

**Files:**
- Modify: `tests/run-all.sh`
- Modify: `tests/gate-plan.json`
- Modify: `findings.md`
- Modify: `progress.md`

**Interfaces:**
- Consumes: `tests/test-product-director-real-transcript-dogfood.sh`
- Produces: quick gate step `product-director-real-transcript-dogfood`

- [ ] **Step 1: Add syntax check entry**

Modify `tests/run-all.sh` and add this entry in `SYNTAX_SHELL_FILES` near other product-director tests:

```bash
  "tests/test-product-director-real-transcript-dogfood.sh"
```

- [ ] **Step 2: Add quick gate step**

Modify `tests/gate-plan.json` and add this step after `product-director-team-pilot-contract`:

```json
{
  "id": "product-director-real-transcript-dogfood",
  "command": [
    "bash",
    "tests/test-product-director-real-transcript-dogfood.sh"
  ],
  "area": "product",
  "tier": "quick",
  "tags": [
    "canary",
    "product",
    "team-pilot",
    "dogfood"
  ],
  "parallel_safe": true,
  "timeout_sec": 60
}
```

- [ ] **Step 3: Update findings**

Append to the `Product-director Controlled Dogfood Design` section in `findings.md`:

```markdown
- Planned implementation: `docs/superpowers/plans/2026-06-20--product-director-controlled-dogfood.md` defines templates, synthetic fixtures, a validator, and quick-gate wiring. It does not create live transcript evidence.
```

- [ ] **Step 4: Update progress**

Add a new phase to `progress.md`:

```markdown
### Phase 13: Product-director Controlled Dogfood Implementation Plan
- **Status:** complete
- Actions taken:
  - Created `docs/superpowers/plans/2026-06-20--product-director-controlled-dogfood.md`.
  - Planned record templates, synthetic fixtures, validator behavior, and quick-gate integration for staged real-transcript dogfood.
  - Kept execution out of scope: no live dogfood run, no active scope, no canonical standard-chain artifact, and no delivery-owner real delivery.
- Files created/modified:
  - `docs/superpowers/plans/2026-06-20--product-director-controlled-dogfood.md`
  - `findings.md`
  - `progress.md`
```

- [ ] **Step 5: Verify plan and gate integration**

Run:

```bash
bash tests/test-product-director-real-transcript-dogfood.sh
bash -n tests/test-product-director-real-transcript-dogfood.sh
python3 -m py_compile shared/skills/product-director/scripts/validate_real_transcript_dogfood.py
python3 -m json.tool tests/gate-plan.json >/tmp/gate-plan.pretty.json
bash tests/run-all.sh --quick --list --format=json > /tmp/quick-plan.json
python3 - <<'PY'
import json
from pathlib import Path
obj = json.loads(Path('/tmp/quick-plan.json').read_text())
ids = [step['id'] for step in obj['steps']]
count = ids.count('product-director-real-transcript-dogfood')
print(count)
raise SystemExit(0 if count == 1 else 1)
PY
git diff --check -- \
  docs/superpowers/plans/2026-06-20--product-director-controlled-dogfood.md \
  shared/skills/product-director/evals/dogfood/real-transcript-review \
  shared/skills/product-director/scripts/validate_real_transcript_dogfood.py \
  tests/test-product-director-real-transcript-dogfood.sh \
  tests/run-all.sh \
  tests/gate-plan.json \
  findings.md \
  progress.md
```

Expected:

- Test prints `[PASS] product-director real transcript dogfood`.
- Shell syntax and Python compile commands exit 0.
- JSON formatting command exits 0.
- Quick plan ID count prints `1`.
- `git diff --check` exits 0 with no output.

- [ ] **Step 6: Run quick regression**

Run:

```bash
bash tests/run-all.sh --quick
```

Expected: all quick checks pass, including `product-director-real-transcript-dogfood`.

---

## Self-review Checklist

- Spec coverage:
  - Staged smoke/stability/promotion model is implemented by templates and validator rules.
  - 5-transcript promotion gate is enforced by invalid promotion fixture.
  - Non-persistent routing is enforced by invalid persistent route fixture.
  - No active scope or canonical standard-chain artifacts are created.
  - Privacy/redaction policy is represented in templates and validator checks.
- Red-flag scan:
  - Search the plan for unresolved placeholders, deferred implementation wording, and cross-task shorthand.
  - Expected result: no unresolved placeholder or shorthand hit in task instructions.
- Type consistency:
  - `artifact_type` values in templates match validator constants.
  - `next_action` and `expansion_decision` values match `VALID_STAGE_DECISIONS`.
  - Dimension IDs match `team-pilot-readiness.json`.

## Execution Handoff

After this plan is accepted, implement it task-by-task. Use subagent-driven development if concurrency is useful, but keep each task's write set isolated. Do not start real transcript review during implementation.
