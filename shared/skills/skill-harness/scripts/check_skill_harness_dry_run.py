"""Validate skill-harness dry-run calibration reports."""
from __future__ import annotations

import re
import shlex
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[4]
DELIVERY_OWNER_PATH = "shared/skills/delivery-owner/SKILL.md"
LOCATION_REF = re.compile(r"^[^:\n]+:\d+$")
FINAL_DIMENSIONS = set("Trigger|Loading|Decision|Execution|Verification|Evolution|Main Content Noise|Chain Integration|Engineering Control|Directory Capability".split("|"))
REQUIRED_FINDING_FIELDS = set("success_criterion_ref implementation_boundary_ref dimension dimension_spread file_line high_value_finding proof_or_gate_ref next_implementation_object expected_benefit stop_condition non_duplicate".split())
HIGH_VALUE_DIMENSIONS = {"Engineering Control", "Chain Integration"}
LOW_VALUE_DIMENSIONS = {"Trigger", "Loading", "Main Content Noise"}
ALLOWED_GATE_REFS = {"machine_gate:failure_state", "fixture_gate:fixture_command", "fresh_proving:proof_command", "user_decision_gate:authority_proof_refs"}


def fail(message: str) -> None:
    print(f"[FAIL] {message}", file=sys.stderr)
    raise SystemExit(1)


def missing(value: Any) -> bool:
    return value in (None, "", [], {})


def delivery_owner_line(ref: Any) -> bool:
    if not isinstance(ref, str) or not LOCATION_REF.match(ref):
        return False
    raw_path, raw_line = ref.rsplit(":", 1)
    if raw_path != DELIVERY_OWNER_PATH:
        return False
    lines = (REPO_ROOT / raw_path).read_text(encoding="utf-8").splitlines()
    line_no = int(raw_line)
    return 8 < line_no <= len(lines) and bool(lines[line_no - 1].strip()) and lines[line_no - 1].strip() != "---"


def abstract_finding(text: Any) -> bool:
    if not isinstance(text, str) or not text.strip():
        return True
    words = re.findall(r"[\w-]+", text)
    return len(words) < 8 or not any(token in text for token in ("delivery-owner", "standard-chain", "gate", "canonical"))


def invalid_dimension_spread(spread: Any) -> bool:
    return not isinstance(spread, list) or not spread or any(not isinstance(item, str) or item not in FINAL_DIMENSIONS for item in spread)


def invalid_dimension(dimension: Any, spread: Any) -> bool:
    return dimension not in FINAL_DIMENSIONS or not isinstance(spread, list) or dimension not in spread


def valid_command_ref(ref: str) -> bool:
    try:
        parts = shlex.split(ref)
    except ValueError:
        return False
    if len(parts) < 2 or parts[0] not in {"bash", "python3", "python"}:
        return False
    script = Path(parts[1])
    if script.is_absolute() or ".." in script.parts:
        return False
    candidate = REPO_ROOT / script
    return candidate.is_file() and candidate.relative_to(REPO_ROOT).parts[:1] != ("docs",)


def valid_proof_or_gate_ref(ref: Any) -> bool:
    if not isinstance(ref, str) or not ref.strip():
        return False
    return ref in ALLOWED_GATE_REFS or valid_command_ref(ref)


def finding_reasons(row: Any) -> list[str]:
    if not isinstance(row, dict):
        return ["finding-not-object"]
    reasons = [key for key in REQUIRED_FINDING_FIELDS if missing(row.get(key))]
    spread = row.get("dimension_spread")
    if invalid_dimension_spread(spread):
        reasons.append("invalid-dimension-spread")
    dimension = row.get("dimension")
    if invalid_dimension(dimension, spread):
        reasons.append("invalid-dimension")
    if row.get("non_duplicate") is not True:
        reasons.append("duplicate-flag")
    if abstract_finding(row.get("high_value_finding")):
        reasons.append("abstract-finding")
    if not delivery_owner_line(row.get("file_line")):
        reasons.append("invalid-file-line")
    if not valid_proof_or_gate_ref(row.get("proof_or_gate_ref")):
        reasons.append("invalid-proof-or-gate-ref")
    return reasons


def duplicate_reasons(findings: list[Any]) -> list[str]:
    seen: set[tuple[str, str]] = set()
    reasons: list[str] = []
    for row in findings:
        if not isinstance(row, dict):
            continue
        key = (str(row.get("high_value_finding", "")).strip().lower(), str(row.get("next_implementation_object", "")).strip().lower())
        if key in seen and all(key):
            reasons.append("duplicate-finding")
        seen.add(key)
    return reasons


def dimension_reasons(findings: list[Any]) -> list[str]:
    dimensions = {row.get("dimension") for row in findings if isinstance(row, dict) and isinstance(row.get("dimension"), str)}
    reasons: list[str] = []
    if len(dimensions) < 2:
        reasons.append("insufficient-dimension-spread")
    if dimensions and dimensions <= LOW_VALUE_DIMENSIONS:
        reasons.append("low-value-dimension-spread")
    if not dimensions & HIGH_VALUE_DIMENSIONS:
        reasons.append("missing-engineering-or-chain-finding")
    return reasons


def dry_run_reasons(sample: dict[str, Any]) -> list[str]:
    findings = sample.get("findings")
    if not isinstance(findings, list):
        return ["findings-not-array"]
    reasons = ["too-few-findings"] if len(findings) < 3 else []
    reasons.extend(reason for row in findings for reason in finding_reasons(row))
    reasons.extend(dimension_reasons(findings))
    reasons.extend(duplicate_reasons(findings))
    return reasons


def validate_dry_run_contract(sample: dict[str, Any]) -> None:
    verdict = sample.get("dry_run_verdict")
    if verdict not in {"CONTINUE", "STOP"}:
        fail("DRY_RUN_VERDICT_INVALID")
    if sample.get("target_skill_path") != DELIVERY_OWNER_PATH:
        fail("DRY_RUN_TARGET_INVALID")
    reasons = dry_run_reasons(sample)
    if reasons:
        fail(f"DRY_RUN_STOP: {reasons[0]}")
    if verdict == "STOP":
        fail("DRY_RUN_STOP_WITHOUT_TRIGGER")
    print(f"[PASS] {sample.get('sample_id', 'skill-harness-dry-run')}")
