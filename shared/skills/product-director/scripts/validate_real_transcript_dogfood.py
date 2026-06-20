#!/usr/bin/env python3
"""Validate product-director real transcript dogfood templates and packages."""

from __future__ import annotations

import argparse
import json
import re
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
SHA256_DIGEST_PATTERN = re.compile(r"^sha256:[0-9a-f]{64}$")


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


def excerpt_anchors(path: Path) -> set[str]:
    anchors: set[str] = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("#"):
            title = line.lstrip("#").strip()
            if title:
                anchors.add(title.lower().replace(" ", "-"))
    return anchors


def require_existing_anchor(root: Path, evidence_ref: str, label: str) -> None:
    path_text, separator, anchor = evidence_ref.partition("#")
    require(separator == "#" and path_text and anchor, f"{label} must include file#anchor")
    evidence_path = root / path_text
    require(evidence_path.is_file(), f"evidence file missing: {path_text}")
    anchors = excerpt_anchors(evidence_path)
    require(anchor in anchors, f"evidence anchor missing: {evidence_ref}")


def allowed_route_signals(root: Path) -> set[str]:
    policy_path = None
    for parent in (root, *root.parents):
        candidate = parent / "contracts" / "standard-chain-invocation-policy.yaml"
        if candidate.is_file():
            policy_path = candidate
            break
    if policy_path is None:
        fail("route policy missing: contracts/standard-chain-invocation-policy.yaml")
    try:
        text = policy_path.read_text(encoding="utf-8")
    except FileNotFoundError:
        fail(f"route policy missing: {policy_path}")
    return set(re.findall(r"^\s*-\s+id:\s+(PD-(?:ROUTE|BYPASS)-[0-9]+)\s*$", text, re.MULTILINE))


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
        require(
            demand_class in {"business_growth", "stability_or_technical_debt", "workflow_or_compliance"},
            f"plan.allowed_demand_classes invalid: {demand_class!r}",
        )
    require(
        plan.get("review_dimensions_ref")
        == "shared/skills/product-director/evals/dogfood/team-pilot-readiness.json#/review_dimensions",
        "plan.review_dimensions_ref drift",
    )
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
    matched_signal = require_text(route.get("matched_signal"), "review.route_rationale.matched_signal")
    if not template:
        require(matched_signal in allowed_route_signals(root), "matched_signal is not declared in route policy")
    require(route.get("decision") == "manual_invoke_product_director", "review.route_rationale.decision must manually invoke product-director")
    require(route.get("basis_ref") == "contracts/standard-chain-invocation-policy.yaml", "review.route_rationale.basis_ref drift")
    require_bool(route.get("persistent_state_created"), "review.route_rationale.persistent_state_created")
    require(route.get("persistent_state_created") is False, "route decisions must remain inline and non-persistent")
    transcript = review.get("transcript_ref")
    require(isinstance(transcript, dict), "review.transcript_ref must be an object")
    require(transcript.get("storage") != "raw_repo_transcript", "raw transcript storage in repo is not allowed")
    digest = require_text(transcript.get("digest"), "review.transcript_ref.digest")
    require(SHA256_DIGEST_PATTERN.fullmatch(digest) is not None, "digest must match sha256 hex format")
    excerpt = require_text(transcript.get("redacted_excerpt_ref"), "review.transcript_ref.redacted_excerpt_ref")
    require(
        review.get("transcript_redaction_status")
        in {"redacted_excerpt_sufficient", "external_digest_with_excerpt", "reviewer_note_only_limited"},
        "review.transcript_redaction_status invalid",
    )
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
        evidence_ref = require_text(item.get("evidence_ref"), f"{dimension_id}.evidence_ref")
        if not template:
            require_existing_anchor(root, evidence_ref, f"{dimension_id}.evidence_ref")
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
