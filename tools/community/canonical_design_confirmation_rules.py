"""Canonical cleanup / co-creation / review-closure / final-confirmation rules.

Split out of canonical_design_rules.py to keep each rules file under 400 lines
while preserving the self-explanatory FAIL messages.
"""

from __future__ import annotations

import re

import canonical_design_errors as err
from canonical_rule_common import (
    _require_non_empty_dict,
    _require_non_empty_list,
    _require_non_empty_string,
    _require_string_list,
)

DESIGN_REQUIRED_CO_CREATION_STAGES = {
    "stakeholders-and-concerns",
    "architecture-significant-requirements",
    "current-state-evidence",
    "complexity-model",
    "decision-discovery",
    "option-tradeoff",
    "design-synthesis",
}
DESIGN_REVIEW_WRAPPER_FIELDS = {
    "candidate_design_json",
    "review_payload_json",
    "open_warns",
    "handoff_summary",
    "co_creation_confirmations",
    "source_refs",
}
DESIGN_WARN_TARGETS = {
    "design.json#planning_constraints",
    "design.json#risk_response",
    "design.json#verification_mapping",
    "design.json#product_handoff",
}


def _walk_values(value: object):
    yield value
    if isinstance(value, dict):
        for child in value.values():
            yield from _walk_values(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk_values(child)


def _assert_canonical_cleanup(payload: dict) -> None:
    leaked_fields = sorted(DESIGN_REVIEW_WRAPPER_FIELDS & set(payload))
    if leaked_fields:
        raise ValueError(
            err.candidate_fields_leaked(
                leaked_fields, sorted(DESIGN_REVIEW_WRAPPER_FIELDS)
            )
        )
    for value in _walk_values(payload):
        if isinstance(value, str) and re.search(r"<[^>]+>", value):
            raise ValueError(err.unresolved_bracket_token(value))


def _assert_co_creation(payload: dict, top_level_ref_assert) -> None:
    co_creation = _require_non_empty_list(
        payload.get("co_creation_summary"), "co_creation_summary"
    )
    seen_stages: set[str] = set()
    for index, row in enumerate(co_creation):
        if not isinstance(row, dict):
            raise ValueError(f"design co_creation_summary[{index}] must be an object")
        stage_id = row.get("stage_id")
        _require_non_empty_string(stage_id, f"co_creation_summary[{index}].stage_id")
        seen_stages.add(stage_id)
        for field in ("stage_name", "question_or_focus", "user_response_summary"):
            _require_non_empty_string(
                row.get(field), f"co_creation_summary[{index}].{field}"
            )
        refs = _require_string_list(
            row.get("decision_refs"), f"co_creation_summary[{index}].decision_refs"
        )
        for ref_index, ref in enumerate(refs):
            top_level_ref_assert(
                ref, payload, f"co_creation_summary[{index}].decision_refs[{ref_index}]"
            )
    missing_stages = sorted(DESIGN_REQUIRED_CO_CREATION_STAGES - seen_stages)
    if missing_stages:
        raise ValueError(
            err.co_creation_missing_stages(
                missing_stages,
                sorted(DESIGN_REQUIRED_CO_CREATION_STAGES),
                sorted(seen_stages),
            )
        )


def _assert_constraint_inheritance(payload: dict) -> None:
    inheritance = _require_non_empty_dict(
        payload.get("constraint_inheritance_confirmation"),
        "constraint_inheritance_confirmation",
    )
    if inheritance.get("status") != "confirmed":
        raise ValueError(
            "design constraint_inheritance_confirmation.status must be confirmed"
        )
    _require_non_empty_string(
        inheritance.get("confirmed_at"),
        "constraint_inheritance_confirmation.confirmed_at",
    )
    for field in ("source_refs", "inherited_constraints", "rejected_constraints"):
        values = inheritance.get(field)
        if not isinstance(values, list):
            raise ValueError(
                f"design constraint_inheritance_confirmation.{field} must be an array"
            )
        for index, value in enumerate(values):
            _require_non_empty_string(
                value, f"constraint_inheritance_confirmation.{field}[{index}]"
            )
    _require_non_empty_string(
        inheritance.get("confirmation_summary"),
        "constraint_inheritance_confirmation.confirmation_summary",
    )


def _assert_review_digest(review: dict) -> str:
    digest = review.get("reviewed_design_digest")
    if not isinstance(digest, str) or not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
        raise ValueError(err.digest_bad_format(digest))
    _require_non_empty_string(review.get("reviewed_at"), "review_closure.reviewed_at")
    return digest


def _assert_single_reviewer(
    reviewer: object, index: int, digest: str
) -> tuple[str, set[str]]:
    if not isinstance(reviewer, dict):
        raise ValueError(f"design review_closure.reviewers[{index}] must be an object")
    name = reviewer.get("reviewer")
    if name not in {"architecture", "product", "test"}:
        raise ValueError(err.reviewer_name_invalid(index, name))
    verdict = reviewer.get("verdict")
    if verdict not in {"PASS", "WARN"}:
        raise ValueError(err.reviewer_verdict_invalid(index, verdict))
    if reviewer.get("reviewed_design_digest") != digest:
        raise ValueError(
            err.reviewer_digest_mismatch(
                index, reviewer.get("reviewed_design_digest"), digest
            )
        )
    finding_refs = reviewer.get("finding_refs")
    if not isinstance(finding_refs, list):
        raise ValueError(
            f"design review_closure.reviewers[{index}].finding_refs must be an array"
        )
    warn_refs: set[str] = set()
    for ref_index, finding_ref in enumerate(finding_refs):
        _require_non_empty_string(
            finding_ref,
            f"review_closure.reviewers[{index}].finding_refs[{ref_index}]",
        )
        if verdict == "WARN":
            warn_refs.add(finding_ref)
    return name, warn_refs


def _assert_reviewers(review: dict, digest: str) -> set[str]:
    reviewers = _require_non_empty_list(
        review.get("reviewers"), "review_closure.reviewers"
    )
    reviewer_names: set[str] = set()
    warn_finding_refs: set[str] = set()
    for index, reviewer in enumerate(reviewers):
        name, warn_refs = _assert_single_reviewer(reviewer, index, digest)
        reviewer_names.add(name)
        warn_finding_refs |= warn_refs
    missing_reviewers = sorted({"architecture", "product", "test"} - reviewer_names)
    if missing_reviewers:
        raise ValueError(err.reviewers_missing(missing_reviewers))
    return warn_finding_refs


def _assert_resolved_failures(review: dict) -> None:
    resolved_failures = review.get("resolved_failures")
    if not isinstance(resolved_failures, list):
        raise ValueError("design review_closure.resolved_failures must be an array")
    for index, row in enumerate(resolved_failures):
        if not isinstance(row, dict):
            raise ValueError(
                f"design review_closure.resolved_failures[{index}] must be an object"
            )
        for field in ("finding_id", "evidence_ref"):
            _require_non_empty_string(
                row.get(field), f"review_closure.resolved_failures[{index}].{field}"
            )


def _assert_warn_followups(review: dict, warn_finding_refs: set[str]) -> None:
    warn_followups = review.get("warn_followups")
    if not isinstance(warn_followups, list):
        raise ValueError("design review_closure.warn_followups must be an array")
    followup_ids: set[str] = set()
    for index, row in enumerate(warn_followups):
        if not isinstance(row, dict):
            raise ValueError(
                f"design review_closure.warn_followups[{index}] must be an object"
            )
        for field in ("finding_id", "target", "summary"):
            _require_non_empty_string(
                row.get(field), f"review_closure.warn_followups[{index}].{field}"
            )
        followup_ids.add(row.get("finding_id"))
        if row.get("target") not in DESIGN_WARN_TARGETS:
            raise ValueError(
                err.warn_followup_target_invalid(
                    index, row.get("target"), sorted(DESIGN_WARN_TARGETS)
                )
            )
    missing_followups = sorted(warn_finding_refs - followup_ids)
    if missing_followups:
        raise ValueError(
            err.warn_followups_missing(missing_followups, sorted(DESIGN_WARN_TARGETS))
        )


def _assert_review_closure(payload: dict) -> None:
    review = _require_non_empty_dict(payload.get("review_closure"), "review_closure")
    digest = _assert_review_digest(review)
    warn_finding_refs = _assert_reviewers(review, digest)
    _assert_resolved_failures(review)
    _assert_warn_followups(review, warn_finding_refs)


def _assert_final_confirmation(payload: dict, top_level_ref_assert) -> None:
    final = _require_non_empty_dict(
        payload.get("final_confirmation"), "final_confirmation"
    )
    if final.get("status") != "confirmed":
        raise ValueError("design final_confirmation.status must be confirmed")
    for field in ("confirmed_by", "confirmed_at", "summary"):
        _require_non_empty_string(final.get(field), f"final_confirmation.{field}")
    accepted_refs = _require_string_list(
        final.get("accepted_refs"), "final_confirmation.accepted_refs"
    )
    for index, ref in enumerate(accepted_refs):
        top_level_ref_assert(ref, payload, f"final_confirmation.accepted_refs[{index}]")


def assert_design_confirmations(payload: dict, top_level_ref_assert) -> None:
    """Run cleanup + co-creation + inheritance + review + final checks.

    top_level_ref_assert is injected to avoid circular imports with
    canonical_design_rules (which owns the design.json# ref matcher).
    """
    _assert_canonical_cleanup(payload)
    _assert_co_creation(payload, top_level_ref_assert)
    _assert_constraint_inheritance(payload)
    _assert_review_closure(payload)
    _assert_final_confirmation(payload, top_level_ref_assert)
