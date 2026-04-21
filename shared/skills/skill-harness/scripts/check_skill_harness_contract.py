#!/usr/bin/env python3
"""Validate one skill-harness deterministic calibration fixture.

The checker stays intentionally small: each fixture is a single contract sample.
It validates calibration evidence shape and stable failure codes; it is not a
general candidate package validator.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any


REQUIRED_FIELDS = {
    "sample_id",
    "mode",
    "overall_verdict",
    "dimension_result",
    "finding_severity",
    "dimension",
    "failure_code",
    "fact_source",
    "json_consumer",
    "audit_proof_type",
    "file_line",
    "evidence",
    "impact",
    "proof_command",
    "manifest_command_exists",
    "active_alias",
    "hard_gate_position",
    "expected_result",
}
CALIBRATION_SAMPLE = "delivery-owner-practice-risk"
CALIBRATION_LABEL = "Correctness PASS / Practice FAIL"
FINAL_DIMENSIONS = {
    "Trigger",
    "Loading",
    "Decision",
    "Execution",
    "Verification",
    "Evolution",
    "Main Content Noise",
    "Chain Integration",
    "Engineering Control",
    "Directory Capability",
}
OVERALL_VERDICTS = {"PASS", "FAIL", "COMMENT"}
DIMENSION_RESULTS = {"PASS", "FAIL", "WARN", "NOT_APPLICABLE"}
SEVERITIES = {"S1", "S2", "S3", "INFO"}
AUDIT_PROOF_TYPES = {"file_evidence", "fixture_proof", "fresh_proving"}
LOCATION_REF = re.compile(r"^[^:\n]+:\d+$")


def fail(message: str) -> None:
    """Print a stable failure message and exit nonzero."""
    print(f"[FAIL] {message}", file=sys.stderr)
    raise SystemExit(1)


def load_json(path: Path) -> dict[str, Any]:
    """Load a fixture JSON object from disk."""
    try:
        with path.open(encoding="utf-8") as handle:
            data = json.load(handle)
    except FileNotFoundError:
        fail(f"file not found: {path}")
    except json.JSONDecodeError as exc:
        fail(f"invalid JSON in {path}: {exc}")
    if not isinstance(data, dict):
        fail(f"top-level JSON must be object: {path}")
    return data


def require_string(sample: dict[str, Any], field: str) -> str:
    """Return a nonempty string field or fail for an invalid fixture shape."""
    value = sample.get(field)
    if not isinstance(value, str):
        fail(f"{field} must be string")
    if field not in {"failure_code", "json_consumer"} and not value.strip():
        fail(f"{field} must be nonempty")
    return value


def require_bool(sample: dict[str, Any], field: str) -> bool:
    """Return a boolean field or fail for an invalid fixture shape."""
    value = sample.get(field)
    if not isinstance(value, bool):
        fail(f"{field} must be boolean")
    return value


def require_enum(sample: dict[str, Any], field: str, allowed: set[str]) -> str:
    """Return a string enum field or fail with a deterministic message."""
    value = require_string(sample, field)
    if value not in allowed:
        choices = ", ".join(sorted(allowed))
        fail(f"{field} must be one of: {choices}")
    return value


def require_evidence(sample: dict[str, Any]) -> list[str]:
    """Return evidence refs, requiring every entry to be a string."""
    value = sample.get("evidence")
    if not isinstance(value, list):
        fail("evidence must be array")
    if any(not isinstance(item, str) or not item.strip() for item in value):
        fail("evidence entries must be nonempty strings")
    return value


def is_missing_string(sample: dict[str, Any], field: str) -> bool:
    """Return whether a field is absent, not a string, or blank."""
    value = sample.get(field)
    return not isinstance(value, str) or not value.strip()


def validate_shape(sample: dict[str, Any]) -> None:
    """Validate the T2 fixture contract before applying gate rules."""
    if "proof_type" in sample:
        fail("proof_type is not allowed; use audit_proof_type")
    missing = sorted(REQUIRED_FIELDS - set(sample))
    if missing:
        fail(f"missing fields: {', '.join(missing)}")
    for field in (
        "sample_id",
        "mode",
        "overall_verdict",
        "dimension",
        "dimension_result",
        "finding_severity",
        "failure_code",
        "fact_source",
        "json_consumer",
        "audit_proof_type",
        "file_line",
        "impact",
        "proof_command",
        "hard_gate_position",
        "expected_result",
    ):
        require_string(sample, field)
    require_evidence(sample)
    require_bool(sample, "manifest_command_exists")
    require_bool(sample, "active_alias")
    require_enum(sample, "overall_verdict", OVERALL_VERDICTS)
    require_enum(sample, "dimension", FINAL_DIMENSIONS)
    require_enum(sample, "dimension_result", DIMENSION_RESULTS)
    require_enum(sample, "finding_severity", SEVERITIES)
    require_enum(sample, "audit_proof_type", AUDIT_PROOF_TYPES)
    if require_string(sample, "expected_result") not in {"pass", "fail"}:
        fail("expected_result must be pass or fail")
    if sample["mode"] == "active_audit_output" and "legacy_baseline_label" in sample:
        fail("active_audit_output must not include legacy_baseline_label")


def detect_failure_code(sample: dict[str, Any]) -> str:
    """Return the first contract failure code, or an empty string when valid."""
    if sample["dimension_result"] == "FAIL" and not sample["evidence"]:
        return "NEED_EVIDENCE"
    if sample["dimension_result"] == "FAIL" and is_missing_string(sample, "recommendation"):
        return "MISSING_RECOMMENDATION"
    if sample["dimension_result"] == "FAIL" and not LOCATION_REF.match(sample["file_line"]):
        return "INVALID_FILE_LINE"
    if not sample["manifest_command_exists"]:
        return "MISSING_COMMAND"
    if sample["active_alias"]:
        return "ACTIVE_ALIAS"
    if sample["fact_source"] == "markdown" and sample["json_consumer"]:
        return "MARKDOWN_FACT_SOURCE"
    if sample["hard_gate_position"] == "tail":
        return "CONTENT_ORDER"
    if sample["fact_source"] == "json" and not sample["json_consumer"]:
        return "JSON_WITHOUT_CONSUMER"
    if (
        sample["sample_id"] == CALIBRATION_SAMPLE
        and sample.get("legacy_baseline_label") != CALIBRATION_LABEL
    ):
        return "CALIBRATION_MISMATCH"
    return ""


def validate_sample(sample: dict[str, Any]) -> None:
    """Validate one fixture and enforce its declared pass or fail outcome."""
    validate_shape(sample)
    actual_code = detect_failure_code(sample)
    declared_code = sample["failure_code"]
    if actual_code:
        if declared_code != actual_code:
            fail(f"FAILURE_CODE_MISMATCH expected={declared_code} actual={actual_code}")
        fail(actual_code)
    if sample["expected_result"] != "pass":
        fail(f"EXPECTED_FAILURE_WITHOUT_RULE: {sample['sample_id']}")
    if declared_code:
        fail(f"UNUSED_FAILURE_CODE: {declared_code}")


def main(argv: list[str]) -> None:
    """Run fixture validation from the command line."""
    if len(argv) != 2:
        fail("usage: check_skill_harness_contract.py <case.json>")
    path = Path(argv[1])
    sample = load_json(path)
    validate_sample(sample)
    print(f"[PASS] {sample['sample_id']}")


if __name__ == "__main__":
    main(sys.argv)
