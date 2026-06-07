"""Shared contract rules for skill-quality-audit alignment validation."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from skill_audit_report_contract import fail, read_line, require, require_known_fields

ALIGNMENT_TOP_LEVEL_FIELDS = {
    "artifact_type",
    "stage",
    "target_skill",
    "target_capability_claims",
    "current_capability_profile",
    "evidence",
    "assumptions_or_unknowns",
    "capability_match_draft",
    "user_confirmation",
}
TARGET_CAPABILITY_FIELDS = {
    "target_capability_id",
    "label",
    "source",
    "confidence",
    "refs",
}
CURRENT_CAPABILITY_FIELDS = {
    "current_capability_id",
    "label",
    "status",
    "evidence_refs",
}
EVIDENCE_COMMON_FIELDS = {"evidence_id", "type", "claim"}
PATH_LINE_EVIDENCE_FIELDS = {
    "evidence_id",
    "type",
    "path",
    "line",
    "expected_snippet",
    "claim",
}
REF_EVIDENCE_FIELDS = {"evidence_id", "type", "ref", "claim"}
ASSUMPTION_FIELDS = {"assumption_id", "label", "status", "refs"}
MATCH_DRAFT_FIELDS = {"gaps"}
GAP_FIELDS = {
    "gap_id",
    "target_capability_id",
    "current_capability_ids",
    "status",
    "evidence_refs",
}
USER_CONFIRMATION_FIELDS = {
    "level",
    "status",
    "confirmed_scope_ref",
    "confirmed_target_capability_ids",
    "accepted_assumption_ids",
}
FORBIDDEN_PRE_CONFIRMATION_FIELDS = {
    "verdict",
    "score",
    "overall_score",
    "severity",
    "findings",
    "repair_handoff",
    "validation",
    "validator_pass",
    "final_audit",
}
TARGET_SOURCES = {"user_supplied", "repo_contract", "declared_claim", "inferred"}
TARGET_CONFIDENCE = {"high", "medium", "low"}
CURRENT_STATUSES = {"supported", "absent", "blocked"}
EVIDENCE_TYPES = {
    "path_line",
    "command",
    "schema",
    "script",
    "test",
    "runtime",
    "user_scope",
}
CURRENT_SUPPORT_EVIDENCE_TYPES = {
    "path_line",
    "command",
    "schema",
    "script",
    "test",
    "runtime",
}
GAP_STATUSES = {"matched", "partial", "missing", "blocked"}
CONFIRMATION_LEVELS = {"G0", "G1", "G2", "G3"}
CONFIRMATION_STATUSES = {"pending", "confirmed", "skipped", "blocked"}
HISTORICAL_AUDIT_REF_MARKERS = (
    "skill-audit-report.json",
    "audit-report.json",
    "evals/dogfood/",
    "evals/lifecycle-review.json",
    "/self-audit/",
    "/audit-summary.md",
    "/raw-output.md",
    "/summary.json",
)


def load_alignment(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"{path}: invalid JSON: {exc}")
    if not isinstance(data, dict):
        fail(f"{path}: alignment must be a JSON object")
    validate_alignment(data)
    return data


def require_non_empty_string(value: Any, label: str) -> None:
    require(isinstance(value, str) and value.strip(), f"{label} is required")


def require_string_list(value: Any, label: str, *, allow_empty: bool = False) -> None:
    require(isinstance(value, list), f"{label} must be an array")
    if not allow_empty:
        require(value, f"{label} must be non-empty")
    require(
        all(isinstance(item, str) and item.strip() for item in value),
        f"{label} must contain non-empty strings",
    )


def validate_top_level(alignment: dict[str, Any]) -> None:
    forbidden = sorted(set(alignment) & FORBIDDEN_PRE_CONFIRMATION_FIELDS)
    require(
        not forbidden,
        "pre-confirmation alignment must not contain " + ", ".join(forbidden),
    )
    require_known_fields(alignment, ALIGNMENT_TOP_LEVEL_FIELDS, "alignment")
    missing = sorted(ALIGNMENT_TOP_LEVEL_FIELDS - alignment.keys())
    require(not missing, f"missing alignment fields: {', '.join(missing)}")
    require(
        alignment["artifact_type"] == "skill-audit-alignment",
        "artifact_type must be skill-audit-alignment",
    )
    require(
        alignment["stage"] in {"awaiting_user_confirmation", "confirmed"},
        "stage must be awaiting_user_confirmation or confirmed",
    )
    require_non_empty_string(alignment["target_skill"], "target_skill")


def validate_target_capabilities(alignment: dict[str, Any]) -> dict[str, str]:
    items = alignment.get("target_capability_claims")
    require(
        isinstance(items, list) and items,
        "target_capability_claims must be a non-empty array",
    )
    sources: dict[str, str] = {}
    for index, item in enumerate(items):
        require(
            isinstance(item, dict),
            f"target_capability_claims[{index}] must be an object",
        )
        require_known_fields(
            item, TARGET_CAPABILITY_FIELDS, f"target_capability_claims[{index}]"
        )
        capability_id = item.get("target_capability_id")
        require_non_empty_string(
            capability_id, f"target_capability_claims[{index}].target_capability_id"
        )
        require(
            capability_id not in sources,
            f"duplicate target_capability_id: {capability_id}",
        )
        require_non_empty_string(item.get("label"), f"{capability_id}.label")
        source = item.get("source")
        require(source in TARGET_SOURCES, f"{capability_id}.source is invalid")
        confidence = item.get("confidence")
        require(
            confidence in TARGET_CONFIDENCE, f"{capability_id}.confidence is invalid"
        )
        require_string_list(item.get("refs"), f"{capability_id}.refs")
        sources[str(capability_id)] = str(source)
    return sources


def is_historical_audit_evidence(evidence: dict[str, Any]) -> bool:
    if evidence.get("type") == "path_line":
        value = str(evidence.get("path", ""))
    else:
        value = str(evidence.get("ref", ""))
    normalized = value.replace("\\", "/").lower()
    return any(marker in normalized for marker in HISTORICAL_AUDIT_REF_MARKERS)


def validate_evidence(alignment: dict[str, Any]) -> dict[str, dict[str, Any]]:
    items = alignment.get("evidence")
    require(isinstance(items, list), "evidence must be an array")
    evidence_by_id: dict[str, dict[str, Any]] = {}
    for index, item in enumerate(items):
        require(isinstance(item, dict), f"evidence[{index}] must be an object")
        evidence_type = item.get("type")
        require(evidence_type in EVIDENCE_TYPES, f"evidence[{index}].type is invalid")
        allowed_fields = (
            PATH_LINE_EVIDENCE_FIELDS
            if evidence_type == "path_line"
            else REF_EVIDENCE_FIELDS
        )
        require_known_fields(item, allowed_fields, f"evidence[{index}]")
        evidence_id = item.get("evidence_id")
        require_non_empty_string(evidence_id, f"evidence[{index}].evidence_id")
        require(
            evidence_id not in evidence_by_id,
            f"duplicate evidence_id: {evidence_id}",
        )
        require_non_empty_string(item.get("claim"), f"{evidence_id}.claim")
        if evidence_type == "path_line":
            path = item.get("path")
            line = item.get("line")
            snippet = item.get("expected_snippet")
            require_non_empty_string(path, f"{evidence_id}.path")
            require(
                isinstance(line, int) and line > 0,
                f"{evidence_id}.line must be a positive integer",
            )
            require_non_empty_string(snippet, f"{evidence_id}.expected_snippet")
            require("\n" not in snippet, f"{evidence_id}.expected_snippet must be single-line")
            line_text = read_line(str(path), int(line))
            require(
                str(snippet) in line_text,
                f"{evidence_id}.expected_snippet not found at {path}:{line}",
            )
        else:
            require_non_empty_string(item.get("ref"), f"{evidence_id}.ref")
        evidence_by_id[str(evidence_id)] = item
    return evidence_by_id


def validate_current_capabilities(
    alignment: dict[str, Any], evidence_by_id: dict[str, dict[str, Any]]
) -> set[str]:
    items = alignment.get("current_capability_profile")
    require(isinstance(items, list), "current_capability_profile must be an array")
    current_ids: set[str] = set()
    for index, item in enumerate(items):
        require(
            isinstance(item, dict),
            f"current_capability_profile[{index}] must be an object",
        )
        require_known_fields(
            item, CURRENT_CAPABILITY_FIELDS, f"current_capability_profile[{index}]"
        )
        capability_id = item.get("current_capability_id")
        require_non_empty_string(
            capability_id,
            f"current_capability_profile[{index}].current_capability_id",
        )
        require(
            capability_id not in current_ids,
            f"duplicate current_capability_id: {capability_id}",
        )
        current_ids.add(str(capability_id))
        require_non_empty_string(item.get("label"), f"{capability_id}.label")
        status = item.get("status")
        require(status in CURRENT_STATUSES, f"{capability_id}.status is invalid")
        refs = item.get("evidence_refs")
        require_string_list(
            refs,
            f"{capability_id}.evidence_refs",
            allow_empty=status != "supported",
        )
        unknown = sorted(set(refs) - evidence_by_id.keys())
        require(not unknown, f"{capability_id} has unknown evidence_refs: {', '.join(unknown)}")
        if status == "supported":
            invalid = sorted(
                ref
                for ref in refs
                if evidence_by_id[ref].get("type") not in CURRENT_SUPPORT_EVIDENCE_TYPES
            )
            require(
                not invalid,
                f"{capability_id} supported current capability requires current evidence",
            )
            historical = sorted(
                ref for ref in refs if is_historical_audit_evidence(evidence_by_id[ref])
            )
            require(
                not historical,
                f"{capability_id} supported current capability cannot rely on historical audit evidence",
            )
    return current_ids


def validate_assumptions(alignment: dict[str, Any]) -> set[str]:
    items = alignment.get("assumptions_or_unknowns")
    require(isinstance(items, list), "assumptions_or_unknowns must be an array")
    assumption_ids: set[str] = set()
    for index, item in enumerate(items):
        require(isinstance(item, dict), f"assumptions_or_unknowns[{index}] must be an object")
        require_known_fields(item, ASSUMPTION_FIELDS, f"assumptions_or_unknowns[{index}]")
        assumption_id = item.get("assumption_id")
        require_non_empty_string(assumption_id, f"assumptions_or_unknowns[{index}].assumption_id")
        require(
            assumption_id not in assumption_ids,
            f"duplicate assumption_id: {assumption_id}",
        )
        assumption_ids.add(str(assumption_id))
        require_non_empty_string(item.get("label"), f"{assumption_id}.label")
        require(
            item.get("status") in {"open", "accepted", "blocked"},
            f"{assumption_id}.status is invalid",
        )
        require_string_list(item.get("refs"), f"{assumption_id}.refs", allow_empty=True)
    return assumption_ids


def validate_gaps(
    alignment: dict[str, Any],
    target_ids: set[str],
    current_ids: set[str],
    evidence_by_id: dict[str, dict[str, Any]],
) -> dict[str, dict[str, Any]]:
    match = alignment.get("capability_match_draft")
    require(isinstance(match, dict), "capability_match_draft must be an object")
    require_known_fields(match, MATCH_DRAFT_FIELDS, "capability_match_draft")
    gaps = match.get("gaps")
    require(isinstance(gaps, list), "capability_match_draft.gaps must be an array")
    by_id: dict[str, dict[str, Any]] = {}
    for index, gap in enumerate(gaps):
        require(isinstance(gap, dict), f"capability_match_draft.gaps[{index}] must be an object")
        require_known_fields(gap, GAP_FIELDS, f"capability_match_draft.gaps[{index}]")
        gap_id = gap.get("gap_id")
        require_non_empty_string(gap_id, f"capability_match_draft.gaps[{index}].gap_id")
        require(gap_id not in by_id, f"duplicate gap_id: {gap_id}")
        target_id = gap.get("target_capability_id")
        require(
            target_id in target_ids,
            f"{gap_id}.target_capability_id does not match a target capability",
        )
        current_refs = gap.get("current_capability_ids")
        require_string_list(current_refs, f"{gap_id}.current_capability_ids", allow_empty=True)
        unknown_current = sorted(set(current_refs) - current_ids)
        require(
            not unknown_current,
            f"{gap_id} has unknown current_capability_ids: {', '.join(unknown_current)}",
        )
        status = gap.get("status")
        require(status in GAP_STATUSES, f"{gap_id}.status is invalid")
        evidence_refs = gap.get("evidence_refs")
        require_string_list(evidence_refs, f"{gap_id}.evidence_refs")
        unknown_evidence = sorted(set(evidence_refs) - evidence_by_id.keys())
        require(
            not unknown_evidence,
            f"{gap_id} has unknown evidence_refs: {', '.join(unknown_evidence)}",
        )
        invalid_evidence = sorted(
            ref
            for ref in evidence_refs
            if evidence_by_id[ref].get("type") not in CURRENT_SUPPORT_EVIDENCE_TYPES
        )
        require(
            not invalid_evidence,
            f"{gap_id}.evidence_refs must cite current evidence",
        )
        historical_evidence = sorted(
            ref for ref in evidence_refs if is_historical_audit_evidence(evidence_by_id[ref])
        )
        require(
            not historical_evidence,
            f"{gap_id}.evidence_refs cannot rely on historical audit evidence",
        )
        by_id[str(gap_id)] = gap
    return by_id


def validate_confirmation(
    alignment: dict[str, Any],
    target_sources: dict[str, str],
    assumption_ids: set[str],
    gaps: dict[str, dict[str, Any]],
) -> None:
    confirmation = alignment.get("user_confirmation")
    require(isinstance(confirmation, dict), "user_confirmation must be an object")
    require_known_fields(confirmation, USER_CONFIRMATION_FIELDS, "user_confirmation")
    level = confirmation.get("level")
    status = confirmation.get("status")
    require(level in CONFIRMATION_LEVELS, "user_confirmation.level is invalid")
    require(status in CONFIRMATION_STATUSES, "user_confirmation.status is invalid")
    require_non_empty_string(
        confirmation.get("confirmed_scope_ref"), "user_confirmation.confirmed_scope_ref"
    )
    confirmed_ids = confirmation.get("confirmed_target_capability_ids")
    require_string_list(
        confirmed_ids,
        "user_confirmation.confirmed_target_capability_ids",
        allow_empty=alignment["stage"] != "confirmed",
    )
    unknown_confirmed = sorted(set(confirmed_ids) - target_sources.keys())
    require(
        not unknown_confirmed,
        "user_confirmation has unknown confirmed_target_capability_ids: "
        + ", ".join(unknown_confirmed),
    )
    accepted = confirmation.get("accepted_assumption_ids")
    require_string_list(
        accepted, "user_confirmation.accepted_assumption_ids", allow_empty=True
    )
    unknown_assumptions = sorted(set(accepted) - assumption_ids)
    require(
        not unknown_assumptions,
        "user_confirmation has unknown accepted_assumption_ids: "
        + ", ".join(unknown_assumptions),
    )
    if alignment["stage"] == "confirmed":
        require(status == "confirmed", "confirmed alignment requires user_confirmation.status confirmed")
        require(level != "G3", "G3 cannot be confirmed for formal audit")
        gap_target_ids = {
            gap["target_capability_id"] for gap in gaps.values() if isinstance(gap, dict)
        }
        uncovered_targets = sorted(set(confirmed_ids) - gap_target_ids)
        require(
            not uncovered_targets,
            "confirmed target capabilities require capability_match_draft gaps: "
            + ", ".join(uncovered_targets),
        )
        if level == "G1":
            invalid_sources = sorted(
                target_id
                for target_id in confirmed_ids
                if target_sources[target_id] not in {"user_supplied", "repo_contract"}
            )
            require(
                not invalid_sources,
                "G1 confirmed scope requires user_supplied or repo_contract target claims",
            )
    else:
        require(status != "confirmed", "awaiting_user_confirmation cannot be confirmed")
        require(
            not confirmed_ids,
            "awaiting_user_confirmation must not confirm target capabilities",
        )


def validate_alignment(alignment: dict[str, Any]) -> None:
    validate_top_level(alignment)
    target_sources = validate_target_capabilities(alignment)
    evidence_by_id = validate_evidence(alignment)
    current_ids = validate_current_capabilities(alignment, evidence_by_id)
    assumption_ids = validate_assumptions(alignment)
    gaps = validate_gaps(alignment, set(target_sources), current_ids, evidence_by_id)
    validate_confirmation(alignment, target_sources, assumption_ids, gaps)
