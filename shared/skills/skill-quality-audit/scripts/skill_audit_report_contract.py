"""Shared contract rules for skill-quality-audit report validation."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

REQUIRED_DIMENSIONS = (
    "Real Use Capability",
    "Trigger And Routing",
    "Instruction Contract",
    "Content Behavior Induction",
    "Workflow Causality",
    "Output And Handoff",
    "Determinism And Validation",
    "Runtime Integration",
    "Evidence And Evals",
    "Noise And Maintainability",
)
REQUIRED_DIMENSION_SET = set(REQUIRED_DIMENSIONS)
REQUIRED_SCOPE_SURFACES = (
    "SKILL.md",
    "agents/openai.yaml",
    "references",
    "scripts",
    "templates",
    "contracts",
    "test prompts",
    "evals",
    "fixtures",
    "runtime surface",
    "install hooks",
    "gate plan",
    "run-all",
    "focused runner",
    "README",
    "downstream consumers",
)
REQUIRED_SCOPE_SURFACE_SET = set(REQUIRED_SCOPE_SURFACES)
VALID_VERDICTS = {"fit", "conditional", "unfit", "blocked"}
VALID_SEVERITIES = {"P0", "P1", "P2", "P3"}
VALID_EVIDENCE_LEVELS = {"E0", "E1", "E2", "E3", "E4"}
EVIDENCE_LEVEL_ORDER = {
    level: index for index, level in enumerate(("E0", "E1", "E2", "E3", "E4"))
}
TOP_LEVEL_FIELDS = {
    "artifact_type",
    "audit_mode",
    "target_skill",
    "capability_baseline_ref",
    "confirmed_target_capability_ids",
    "verdict",
    "overall_score",
    "verdict_reason",
    "artifact_paths",
    "scope_evidence",
    "dimension_scores",
    "content_behavior_audit",
    "findings",
    "repair_handoff",
    "validation",
    "executed_verification",
    "residual_risk",
}
ARTIFACT_PATH_FIELDS = {"report_json", "summary_markdown"}
SCOPE_FIELDS = {"surface", "status", "evidence"}
DIMENSION_FIELDS = {"dimension", "score", "evidence_level", "reason"}
CONTENT_BEHAVIOR_AUDIT_FIELDS = {
    "target_capability_id",
    "instruction_hygiene",
    "attention_economy",
    "behavior_induction",
    "failure_mode_coverage",
    "unproven_risk_disposition",
    "evidence_refs",
    "evidence_checks",
}
CONTENT_BEHAVIOR_FIELDS = (
    "instruction_hygiene",
    "attention_economy",
    "behavior_induction",
    "failure_mode_coverage",
    "unproven_risk_disposition",
)
CONTENT_BEHAVIOR_STATUSES = {"supported", "partial", "missing", "blocked"}
CONTENT_BEHAVIOR_EVIDENCE_CHECK_FIELDS = {
    "field",
    "path",
    "line",
    "expected_snippet",
    "claim",
}
FINDING_FIELDS = {
    "id",
    "severity",
    "title",
    "confirmed_gap_refs",
    "evidence_level",
    "evidence",
    "evidence_checks",
    "claim_review",
    "severity_calibration",
    "impact",
    "repair_target",
    "verification_hint",
}
EVIDENCE_CHECK_FIELDS = {"path", "line", "expected_snippet", "claim"}
CLAIM_REVIEW_FIELDS = {"required_claims", "refutation_check", "status"}
SEVERITY_CALIBRATION_FIELDS = {"calibrated_severity", "team_use_impact", "rationale"}
HANDOFF_FIELDS = {"target", "action", "owner"}
VALIDATION_FIELDS = {"status", "alignment", "report"}
VALIDATOR_EVIDENCE_FIELDS = {"status", "command", "output"}
EXECUTED_VERIFICATION_FIELDS = {
    "id",
    "command",
    "status",
    "output",
    "evidence",
    "supports",
}
PATH_TOKEN = r"/?(?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+\.[A-Za-z0-9_.-]+"
FILE_LINE_RE = re.compile(rf"(?:^|[\s'\"(`\[]){PATH_TOKEN}:\d+(?:\b|[)\]`'\".,;])")
PATHISH_RE = re.compile(
    rf"(?:^|[\s'\"(`\[]){PATH_TOKEN}(?:\b|[)\]`'\".,;])|"
    rf"(?:^|[\s'\"(`\[])/?(?:[A-Za-z0-9_.-]+/)+[A-Za-z0-9_.-]+/(?:\b|[)\]`'\".,;])"
)
PATH_CANDIDATE_RE = re.compile(
    r"/?(?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+(?:\.[A-Za-z0-9_.-]+|/)"
)


def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def require_known_fields(item: dict[str, Any], allowed: set[str], label: str) -> None:
    unknown = sorted(set(item) - allowed)
    require(not unknown, f"{label} has unknown fields: {', '.join(unknown)}")


def has_file_line_ref(text: str) -> bool:
    return bool(FILE_LINE_RE.search(text))


def has_pathish_ref(text: str) -> bool:
    return bool(PATHISH_RE.search(text))


def existing_path_refs(text: str) -> list[str]:
    refs: list[str] = []
    for match in PATH_CANDIDATE_RE.finditer(text):
        value = match.group(0).strip("`'\"()[],;")
        path = Path(value)
        if not path.is_absolute() and ".." in path.parts:
            continue
        if path.exists():
            refs.append(value)
    return refs


def evidence_level_at_least(level: str, minimum: str) -> bool:
    return EVIDENCE_LEVEL_ORDER[level] >= EVIDENCE_LEVEL_ORDER[minimum]


def read_line(path_text: str, line_number: int) -> str:
    path = Path(path_text)
    require(
        not path.is_absolute(), f"evidence_checks path must be relative: {path_text}"
    )
    require(
        ".." not in path.parts,
        f"evidence_checks path must stay inside the repository: {path_text}",
    )
    require(path.is_file(), f"evidence_checks path does not exist: {path_text}")
    lines = path.read_text(encoding="utf-8").splitlines()
    require(
        line_number <= len(lines),
        f"evidence_checks line out of range: {path_text}:{line_number}",
    )
    return lines[line_number - 1]


def validate_evidence_checks(finding: dict[str, Any], label: str) -> None:
    checks = finding.get("evidence_checks")
    require(isinstance(checks, list) and checks, f"{label} requires evidence_checks")
    evidence = finding["evidence"]
    for index, check in enumerate(checks):
        require(
            isinstance(check, dict),
            f"{label}.evidence_checks[{index}] must be an object",
        )
        require_known_fields(
            check, EVIDENCE_CHECK_FIELDS, f"{label}.evidence_checks[{index}]"
        )
        path = check.get("path")
        line = check.get("line")
        snippet = check.get("expected_snippet")
        claim = check.get("claim")
        require(
            isinstance(path, str) and path.strip(),
            f"{label}.evidence_checks[{index}].path is required",
        )
        require(
            isinstance(line, int) and line > 0,
            f"{label}.evidence_checks[{index}].line must be a positive integer",
        )
        require(
            isinstance(snippet, str) and snippet.strip(),
            f"{label}.evidence_checks[{index}].expected_snippet is required",
        )
        require(
            "\n" not in snippet,
            f"{label}.evidence_checks[{index}].expected_snippet must be single-line",
        )
        require(
            isinstance(claim, str) and claim.strip(),
            f"{label}.evidence_checks[{index}].claim is required",
        )
        require(
            f"{path}:{line}" in evidence,
            f"{label}.evidence must cite evidence_checks path:line {path}:{line}",
        )
        line_text = read_line(path, line)
        require(
            snippet in line_text,
            f"{label}.evidence_checks[{index}] expected_snippet not found at {path}:{line}",
        )


def validate_findings(report: dict[str, Any]) -> None:
    findings = report.get("findings")
    require(isinstance(findings, list), "findings must be an array")
    for index, finding in enumerate(findings):
        require(isinstance(finding, dict), f"findings[{index}] must be an object")
        require_known_fields(finding, FINDING_FIELDS, f"findings[{index}]")
        severity = finding.get("severity")
        require(severity in VALID_SEVERITIES, f"findings[{index}].severity is invalid")
        level = finding.get("evidence_level")
        require(
            level in VALID_EVIDENCE_LEVELS,
            f"findings[{index}].evidence_level is invalid",
        )
        for field in (
            "id",
            "title",
            "evidence",
            "impact",
            "repair_target",
            "verification_hint",
        ):
            require(
                isinstance(finding.get(field), str) and finding[field],
                f"findings[{index}].{field} is required",
            )
        require(
            isinstance(finding.get("confirmed_gap_refs"), list)
            and finding["confirmed_gap_refs"]
            and all(
                isinstance(value, str) and value
                for value in finding["confirmed_gap_refs"]
            ),
            f"findings[{index}].confirmed_gap_refs must be non-empty strings",
        )
        if "claim_review" in finding:
            validate_claim_review(
                finding["claim_review"], f"findings[{index}].claim_review"
            )
        if "severity_calibration" in finding:
            validate_severity_calibration(
                finding["severity_calibration"],
                f"findings[{index}].severity_calibration",
            )
        if severity in {"P0", "P1"}:
            validate_high_severity_finding(finding, str(severity), str(level), index)


def validate_content_behavior_audit(report: dict[str, Any]) -> None:
    items = report.get("content_behavior_audit")
    require(
        isinstance(items, list) and items,
        "content_behavior_audit must be a non-empty array",
    )
    confirmed = set(report.get("confirmed_target_capability_ids", []))
    seen: set[str] = set()
    for index, item in enumerate(items):
        require(
            isinstance(item, dict),
            f"content_behavior_audit[{index}] must be an object",
        )
        require_known_fields(
            item, CONTENT_BEHAVIOR_AUDIT_FIELDS, f"content_behavior_audit[{index}]"
        )
        target_id = item.get("target_capability_id")
        require(
            isinstance(target_id, str) and target_id,
            f"content_behavior_audit[{index}].target_capability_id is required",
        )
        require(
            target_id in confirmed,
            f"content_behavior_audit[{index}] target_capability_id must be report-confirmed",
        )
        require(target_id not in seen, f"duplicate content_behavior_audit target: {target_id}")
        seen.add(str(target_id))
        for field in CONTENT_BEHAVIOR_FIELDS:
            require(
                item.get(field) in CONTENT_BEHAVIOR_STATUSES,
                f"content_behavior_audit[{index}].{field} is invalid",
            )
        evidence_refs = item.get("evidence_refs")
        require(
            isinstance(evidence_refs, list)
            and evidence_refs
            and all(isinstance(value, str) and value for value in evidence_refs),
            f"content_behavior_audit[{index}].evidence_refs must be non-empty strings",
        )
        validate_content_behavior_evidence_checks(
            item, f"content_behavior_audit[{index}]"
        )
    missing = sorted(confirmed - seen)
    require(
        not missing,
        "content_behavior_audit must cover confirmed target capabilities: "
        + ", ".join(missing),
    )


def validate_content_behavior_evidence_checks(
    item: dict[str, Any], label: str
) -> None:
    checks = item.get("evidence_checks")
    require(
        isinstance(checks, list) and checks,
        f"{label}.evidence_checks must be a non-empty array",
    )
    checked_fields: set[str] = set()
    for index, check in enumerate(checks):
        require(
            isinstance(check, dict), f"{label}.evidence_checks[{index}] must be an object"
        )
        require_known_fields(
            check,
            CONTENT_BEHAVIOR_EVIDENCE_CHECK_FIELDS,
            f"{label}.evidence_checks[{index}]",
        )
        field = check.get("field")
        require(
            field in CONTENT_BEHAVIOR_FIELDS,
            f"{label}.evidence_checks[{index}].field is invalid",
        )
        path = check.get("path")
        line = check.get("line")
        snippet = check.get("expected_snippet")
        claim = check.get("claim")
        require(
            isinstance(path, str) and path.strip(),
            f"{label}.evidence_checks[{index}].path is required",
        )
        require(
            isinstance(line, int) and line > 0,
            f"{label}.evidence_checks[{index}].line must be a positive integer",
        )
        require(
            isinstance(snippet, str) and snippet.strip(),
            f"{label}.evidence_checks[{index}].expected_snippet is required",
        )
        require(
            "\n" not in snippet,
            f"{label}.evidence_checks[{index}].expected_snippet must be single-line",
        )
        require(
            isinstance(claim, str) and claim.strip(),
            f"{label}.evidence_checks[{index}].claim is required",
        )
        line_text = read_line(path, line)
        require(
            snippet in line_text,
            f"{label}.evidence_checks[{index}] expected_snippet not found at {path}:{line}",
        )
        checked_fields.add(str(field))
    supported_fields = {
        field for field in CONTENT_BEHAVIOR_FIELDS if item.get(field) == "supported"
    }
    missing = sorted(supported_fields - checked_fields)
    require(
        not missing,
        f"{label}.evidence_checks must cover supported fields: " + ", ".join(missing),
    )


def content_behavior_ready_for_fit(report: dict[str, Any]) -> bool:
    for item in report.get("content_behavior_audit", []):
        for field in CONTENT_BEHAVIOR_FIELDS:
            if item.get(field) != "supported":
                return False
    return True


def resolve_report_artifact(path_text: str) -> Path:
    path = Path(path_text)
    require(
        ".." not in path.parts,
        f"artifact path must stay inside a safe location: {path_text}",
    )
    return path


def validate_summary(report: dict[str, Any]) -> None:
    paths = report.get("artifact_paths", {})
    summary_value = paths.get("summary_markdown")
    require(
        isinstance(summary_value, str) and summary_value.strip(),
        "artifact_paths.summary_markdown is required",
    )
    summary_path = resolve_report_artifact(summary_value)
    require(
        summary_path.is_file(),
        f"summary_markdown does not exist: {summary_value}",
    )
    summary_text = summary_path.read_text(encoding="utf-8")
    require(summary_text.strip(), f"summary_markdown is empty: {summary_value}")

    for index, finding in enumerate(report.get("findings", [])):
        if finding.get("severity") not in {"P0", "P1"}:
            continue
        label = (
            f"summary_markdown for {finding.get('severity')} "
            f"finding {finding.get('id', index)}"
        )
        for field in (
            "id",
            "severity",
            "title",
            "impact",
            "repair_target",
            "verification_hint",
        ):
            value = finding.get(field)
            require(
                isinstance(value, str) and value in summary_text,
                f"{label} must include {field}",
            )
        evidence_refs = []
        for check in finding.get("evidence_checks", []):
            if isinstance(check, dict):
                evidence_refs.append(f"{check.get('path')}:{check.get('line')}")
        require(
            evidence_refs and any(ref in summary_text for ref in evidence_refs),
            f"{label} must include evidence_checks path:line",
        )


def validate_claim_review(claim_review: Any, label: str) -> None:
    require(
        isinstance(claim_review, dict) and claim_review,
        f"{label} must be a non-empty object when present",
    )
    require_known_fields(claim_review, CLAIM_REVIEW_FIELDS, label)
    claims = claim_review.get("required_claims")
    require(
        isinstance(claims, list)
        and claims
        and all(isinstance(claim, str) and claim for claim in claims),
        f"{label}.required_claims must be non-empty strings",
    )
    refutation = claim_review.get("refutation_check")
    require(
        isinstance(refutation, str) and refutation,
        f"{label}.refutation_check is required",
    )
    require(
        claim_review.get("status") in {"supported", "refuted", "blocked"},
        f"{label}.status is invalid",
    )


def validate_severity_calibration(severity_calibration: Any, label: str) -> None:
    require(
        isinstance(severity_calibration, dict) and severity_calibration,
        f"{label} must be a non-empty object when present",
    )
    require_known_fields(severity_calibration, SEVERITY_CALIBRATION_FIELDS, label)
    require(
        severity_calibration.get("calibrated_severity") in VALID_SEVERITIES,
        f"{label}.calibrated_severity is invalid",
    )
    for field in ("team_use_impact", "rationale"):
        require(
            isinstance(severity_calibration.get(field), str)
            and severity_calibration[field],
            f"{label}.{field} is required",
        )


def validate_high_severity_finding(
    finding: dict[str, Any], severity: str, level: str, index: int
) -> None:
    label = f"{severity} finding {finding.get('id', index)}"
    require(
        evidence_level_at_least(level, "E2"),
        f"{severity} finding {finding.get('id', index)} requires evidence_level E2 or higher",
    )
    require(
        has_file_line_ref(finding["evidence"]),
        f"{severity} finding {finding.get('id', index)} evidence must include file:line evidence",
    )
    validate_evidence_checks(finding, label)
    claim_review = finding.get("claim_review")
    require(isinstance(claim_review, dict), f"{label} requires claim_review")
    require_known_fields(claim_review, CLAIM_REVIEW_FIELDS, f"{label}.claim_review")
    claims = claim_review.get("required_claims")
    require(
        isinstance(claims, list)
        and claims
        and all(isinstance(claim, str) and claim for claim in claims),
        f"{label}.claim_review.required_claims must be non-empty strings",
    )
    require(
        claim_review.get("status") == "supported",
        f"{label}.claim_review.status must be supported",
    )
    refutation = claim_review.get("refutation_check")
    require(
        isinstance(refutation, str) and has_file_line_ref(refutation),
        f"{label}.claim_review.refutation_check must cite file:line",
    )
    severity_calibration = finding.get("severity_calibration")
    require(
        isinstance(severity_calibration, dict), f"{label} requires severity_calibration"
    )
    require_known_fields(
        severity_calibration,
        SEVERITY_CALIBRATION_FIELDS,
        f"{label}.severity_calibration",
    )
    require(
        severity_calibration.get("calibrated_severity") == severity,
        f"{label}.severity_calibration.calibrated_severity must match severity",
    )
    for field in ("team_use_impact", "rationale"):
        require(
            isinstance(severity_calibration.get(field), str)
            and severity_calibration[field],
            f"{label}.severity_calibration.{field} is required",
        )
    for field in ("repair_target", "verification_hint"):
        require(
            isinstance(finding.get(field), str) and finding[field],
            f"{severity} finding {finding.get('id', index)} missing {field}",
        )
