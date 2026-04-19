#!/usr/bin/env python3
"""Validate one skill-harness deterministic contract fixture.

The checker stays intentionally small: each fixture is a single contract sample,
and each failing sample maps to one stable failure code consumed by shell gates.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


REQUIRED_FIELDS = {
    "sample_id",
    "mode",
    "overall_verdict",
    "finding_severity",
    "dimension",
    "failure_code",
    "fact_source",
    "json_consumer",
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
CALIBRATION_VERDICT = "Correctness PASS / Practice FAIL"


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


def require_evidence(sample: dict[str, Any]) -> list[str]:
    """Return evidence refs, requiring every entry to be a string."""
    value = sample.get("evidence")
    if not isinstance(value, list):
        fail("evidence must be array")
    if any(not isinstance(item, str) or not item.strip() for item in value):
        fail("evidence entries must be nonempty strings")
    return value


def validate_shape(sample: dict[str, Any]) -> None:
    """Validate the T2 fixture contract before applying gate rules."""
    missing = sorted(REQUIRED_FIELDS - set(sample))
    if missing:
        fail(f"missing fields: {', '.join(missing)}")
    for field in (
        "sample_id",
        "mode",
        "overall_verdict",
        "finding_severity",
        "dimension",
        "failure_code",
        "fact_source",
        "json_consumer",
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
    if require_string(sample, "expected_result") not in {"pass", "fail"}:
        fail("expected_result must be pass or fail")


def detect_failure_code(sample: dict[str, Any]) -> str:
    """Return the first contract failure code, or an empty string when valid."""
    if sample["finding_severity"] == "FAIL" and not sample["evidence"]:
        return "NEED_EVIDENCE"
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
        and sample["overall_verdict"] != CALIBRATION_VERDICT
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
