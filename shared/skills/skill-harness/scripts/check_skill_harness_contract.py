#!/usr/bin/env python3
"""Validate skill-harness calibration, field-consumer, and ownership fixtures.

The checker is deliberately repo-local and deterministic: it validates only the
fixture contracts that gate the active skill-harness runtime boundary.
"""
from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[4]
CALIBRATION_SAMPLE = "delivery-owner-practice-risk"
CALIBRATION_LABEL = "Correctness PASS / Practice FAIL"
LOCATION_REF = re.compile(r"^[^:\n]+:\d+$")
REQUIRED_FIELDS = set(
    "sample_id mode overall_verdict dimension_result finding_severity dimension "
    "failure_code fact_source json_consumer audit_proof_type file_line evidence impact "
    "proof_command manifest_command_exists active_alias hard_gate_position expected_result".split()
)
CALIBRATION_STRING_FIELDS = REQUIRED_FIELDS - {
    "evidence",
    "manifest_command_exists",
    "active_alias",
}
FINAL_DIMENSIONS = set(
    "Trigger|Loading|Decision|Execution|Verification|Evolution|Main Content Noise|"
    "Chain Integration|Engineering Control|Directory Capability".split("|")
)
OVERALL_VERDICTS = {"PASS", "FAIL", "COMMENT"}
DIMENSION_RESULTS = {"PASS", "FAIL", "WARN", "NOT_APPLICABLE"}
SEVERITIES = {"S1", "S2", "S3", "INFO"}
AUDIT_PROOF_TYPES = {"file_evidence", "fixture_proof", "fresh_proving"}
LEGACY_BASELINE_LABEL_MODES = {"baseline_smoke", "calibration_audit", "migration_audit"}
ALLOWED_RUNTIME_CONSUMERS = set(
    "check_skill_harness_contract.py human_projection hook_adapter release_gate runner validator".split()
)
FIELD_KEYS = set("field consumer read_purpose validation_command drop_condition failure_state".split())
VALIDATION_PREFIXES = {"bash", "python3", "python"}
KNOWN_VALIDATION_COMMANDS = {f"bash tests/test-skill-harness-{name}.sh" for name in (
    "field-consumers", "gates", "legacy-label-migration",
    "main-content-noise", "responsibility-contract", "runtime-noise")}
ASSET_KEYS = set(
    "asset_id source_path target_action consumer validation_command drop_condition failure_state".split()
)
ASSET_TARGET_KEYS = {"immediate_target_path", "target_path_when_triggered", "archive_boundary"}
ASSET_ACTIONS = set(
    "keep_inline_summary route_to_reference port_to_contract move_to_fixture "
    "triggered_artifact archive_only".split()
)
REQUIRED_ASSET_IDS = set(
    "audit-method runtime-noise-contract reference-contract permission-script-contract "
    "hook-adapter-contract subagent-handoff-contract field-consumers schemas evals examples "
    "templates-renderer optimization-plan verification-result old-runtime-entry old-agent-exposure "
    "permission-profiles source-map quality-dimension-mapping old-scripts-manifest "
    "old-audit-runner-scripts old-artifact-builders archive-readme-docs".split()
)


def fail(message: str) -> None:
    """Print a stable failure message and stop validation."""
    print(f"[FAIL] {message}", file=sys.stderr)
    raise SystemExit(1)


def load_json(path: Path) -> dict[str, Any]:
    """Load a fixture JSON object and reject malformed inputs."""
    try:
        data = json.load(path.open(encoding="utf-8"))
    except FileNotFoundError:
        fail(f"file not found: {path}")
    except json.JSONDecodeError as exc:
        fail(f"invalid JSON in {path}: {exc}")
    if not isinstance(data, dict):
        fail(f"top-level JSON must be object: {path}")
    return data


def require_string(sample: dict[str, Any], field: str) -> str:
    """Return a string field, allowing blank only for declared optional fields."""
    value = sample.get(field)
    if not isinstance(value, str):
        fail(f"{field} must be string")
    if field not in {"failure_code", "json_consumer"} and not value.strip():
        fail(f"{field} must be nonempty")
    return value


def require_bool(sample: dict[str, Any], field: str) -> bool:
    """Return a boolean field or fail with a deterministic shape error."""
    value = sample.get(field)
    if not isinstance(value, bool):
        fail(f"{field} must be boolean")
    return value


def require_enum(sample: dict[str, Any], field: str, allowed: set[str]) -> None:
    """Validate a string enum field against its active contract."""
    value = require_string(sample, field)
    if value not in allowed:
        fail(f"{field} must be one of: {', '.join(sorted(allowed))}")


def missing_string(sample: dict[str, Any], field: str) -> bool:
    """Return whether a field is absent, not a string, or blank."""
    value = sample.get(field)
    return not isinstance(value, str) or not value.strip()


def repo_path(raw_path: str) -> Path:
    """Resolve a repo-local path without absolute or parent traversal."""
    path = Path(raw_path)
    if path.is_absolute() or ".." in path.parts:
        fail(f"path must be repo-local: {raw_path}")
    return REPO_ROOT / path


def path_exists(raw_path: str) -> bool:
    """Return whether a repo-local path exists."""
    return repo_path(raw_path).exists()


def validate_consumer_ref(consumer: str, failure_code: str) -> None:
    """Require a known runtime consumer type or an existing repo path."""
    if consumer not in ALLOWED_RUNTIME_CONSUMERS and not path_exists(consumer):
        fail(failure_code)


def validation_script(command: str, failure_code: str) -> Path:
    """Resolve a controlled repo-local bash/python script command."""
    try:
        parts = shlex.split(command)
    except ValueError:
        fail(failure_code)
    if len(parts) < 2 or parts[0] not in VALIDATION_PREFIXES:
        fail(failure_code)
    script = repo_path(parts[1])
    if not script.is_file() or script.relative_to(REPO_ROOT).parts[:1] == ("docs",):
        fail(failure_code)
    return script


def run_controlled_smoke(command: str, failure_code: str) -> None:
    """Execute a validation command with the self-recursion guard enabled."""
    env = dict(os.environ)
    env["SKILL_HARNESS_FIELD_CONSUMER_SKIP_SELF"] = "1"
    try:
        subprocess.run(
            shlex.split(command), cwd=REPO_ROOT, env=env, timeout=30,
            check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    except (subprocess.SubprocessError, ValueError):
        fail(failure_code)


def validate_legacy_baseline_label(sample: dict[str, Any]) -> None:
    """Keep migration-only calibration labels out of active/default output."""
    if "legacy_baseline_label" in sample and sample["mode"] not in LEGACY_BASELINE_LABEL_MODES:
        fail(f"legacy_baseline_label is allowed only for: {', '.join(sorted(LEGACY_BASELINE_LABEL_MODES))}")
    if "legacy_baseline_label" in sample:
        require_string(sample, "legacy_baseline_label")


def validate_shape(sample: dict[str, Any]) -> None:
    """Validate the calibration fixture shape before applying gate rules."""
    if "proof_type" in sample:
        fail("proof_type is not allowed; use audit_proof_type")
    missing = sorted(REQUIRED_FIELDS - set(sample))
    if missing:
        fail(f"missing fields: {', '.join(missing)}")
    for field in CALIBRATION_STRING_FIELDS:
        require_string(sample, field)
    evidence = sample.get("evidence")
    if not isinstance(evidence, list):
        fail("evidence must be array")
    if any(not isinstance(item, str) or not item.strip() for item in evidence):
        fail("evidence entries must be nonempty strings")
    require_bool(sample, "manifest_command_exists")
    require_bool(sample, "active_alias")
    require_enum(sample, "overall_verdict", OVERALL_VERDICTS)
    require_enum(sample, "dimension", FINAL_DIMENSIONS)
    require_enum(sample, "dimension_result", DIMENSION_RESULTS)
    require_enum(sample, "finding_severity", SEVERITIES)
    require_enum(sample, "audit_proof_type", AUDIT_PROOF_TYPES)
    if require_string(sample, "expected_result") not in {"pass", "fail"}:
        fail("expected_result must be pass or fail")
    validate_legacy_baseline_label(sample)


def detect_failure_code(sample: dict[str, Any]) -> str:
    """Return the first calibration failure code, or blank when valid."""
    if sample["dimension_result"] == "FAIL" and not sample["evidence"]:
        return "NEED_EVIDENCE"
    if sample["dimension_result"] == "FAIL" and missing_string(sample, "recommendation"):
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
    if sample["sample_id"] == CALIBRATION_SAMPLE and sample.get("legacy_baseline_label") != CALIBRATION_LABEL:
        return "CALIBRATION_MISMATCH"
    return ""


def validate_sample(sample: dict[str, Any]) -> None:
    """Validate one calibration fixture and enforce its declared outcome."""
    validate_shape(sample)
    actual = detect_failure_code(sample)
    declared = sample["failure_code"]
    if actual:
        if declared != actual:
            fail(f"FAILURE_CODE_MISMATCH expected={declared} actual={actual}")
        fail(actual)
    if sample["expected_result"] != "pass":
        fail(f"EXPECTED_FAILURE_WITHOUT_RULE: {sample['sample_id']}")
    if declared:
        fail(f"UNUSED_FAILURE_CODE: {declared}")


def validate_field_row(row: dict[str, Any]) -> None:
    """Validate one runtime field consumer and execute its smoke command."""
    missing = sorted(FIELD_KEYS - row.keys())
    if missing:
        fail(f"FIELD_CONSUMER_MISSING_KEYS: {', '.join(missing)}")
    for field in FIELD_KEYS:
        if missing_string(row, field):
            if field == "drop_condition":
                fail("FIELD_CONSUMER_MISSING_DROP_CONDITION")
            fail(f"FIELD_CONSUMER_INCOMPLETE_ROW: {row.get('field', '<unknown>')}")
    validate_consumer_ref(row["consumer"], "FIELD_CONSUMER_INVALID_CONSUMER")
    validation_script(row["validation_command"], "FIELD_CONSUMER_INVALID_COMMAND")
    if os.environ.get("SKILL_HARNESS_FIELD_CONSUMER_SKIP_SELF") != "1":
        run_controlled_smoke(row["validation_command"], "FIELD_CONSUMER_VALIDATION_FAILED")


def validate_field_consumer_contract(sample: dict[str, Any]) -> None:
    """Validate field-consumer contract fixtures and schema rows."""
    fields = sample.get("fields")
    if not isinstance(fields, list) or not fields:
        fail("FIELD_CONSUMER_FIELDS_REQUIRED")
    for row in fields:
        if not isinstance(row, dict):
            fail("FIELD_CONSUMER_ROW_MUST_BE_OBJECT")
        validate_field_row(row)
    print(f"[PASS] {sample.get('sample_id', 'field-consumers')}")


def nonempty_string(row: dict[str, Any], key: str, failure_code: str) -> str:
    """Return a required nonblank string from an ownership row."""
    value = row.get(key)
    if not isinstance(value, str) or not value.strip():
        fail(failure_code)
    return value


def active_target(row: dict[str, Any]) -> str:
    """Validate exactly one ownership target mode and return its path."""
    present = [key for key in ASSET_TARGET_KEYS if row.get(key)]
    if len(present) != 1:
        fail("ASSET_OWNERSHIP_TARGET_MODE_CONFLICT" if len(present) > 1 else "ASSET_OWNERSHIP_MISSING_TARGET")
    key = present[0]
    if key == "target_path_when_triggered":
        target = row[key]
        if not isinstance(target, dict):
            fail("ASSET_OWNERSHIP_TRIGGERED_TARGET_INVALID")
        validate_consumer_ref(nonempty_string(target, "consumer", "ASSET_OWNERSHIP_TRIGGERED_TARGET_INVALID"),
                              "ASSET_OWNERSHIP_INVALID_CONSUMER")
        nonempty_string(target, "deferred_until", "ASSET_OWNERSHIP_TRIGGERED_TARGET_INVALID")
        target_path = nonempty_string(target, "path", "ASSET_OWNERSHIP_TRIGGERED_TARGET_INVALID")
    else:
        target_path = nonempty_string(row, key, "ASSET_OWNERSHIP_MISSING_TARGET")
    if not path_exists(target_path):
        fail("ASSET_OWNERSHIP_MISSING_TARGET")
    return target_path


def contains_reverse_reference(row: dict[str, Any], target_path: str, script: Path) -> bool:
    """Check consumer, validation, manifest, tests, or references mention the asset."""
    tokens = {row["asset_id"], row["source_path"], target_path}
    candidates = [script, REPO_ROOT / "shared/skills/skill-harness/scripts/manifest.json",
                  REPO_ROOT / "tests/test-skill-harness-directory-capability.sh"]
    if row["consumer"] not in ALLOWED_RUNTIME_CONSUMERS:
        consumer_path = repo_path(row["consumer"])
        if consumer_path.is_file():
            candidates.append(consumer_path)
    candidates.extend((REPO_ROOT / "shared/skills/skill-harness/references").glob("*.md"))
    return any(
        any(token in path.read_text(encoding="utf-8") for token in tokens if token)
        for path in candidates if path.is_file()
    )


def validate_asset_ownership(sample: dict[str, Any]) -> None:
    """Validate legacy skill-audit asset ownership rows."""
    assets = sample.get("assets")
    if not isinstance(assets, list) or not assets:
        fail("ASSET_OWNERSHIP_ASSETS_REQUIRED")
    seen_sources: set[str] = set()
    seen_ids: set[str] = set()
    smoke_ran: set[str] = set()
    for row in assets:
        if not isinstance(row, dict):
            fail("ASSET_OWNERSHIP_ROW_MUST_BE_OBJECT")
        missing = sorted(ASSET_KEYS - row.keys())
        if missing:
            fail(f"ASSET_OWNERSHIP_MISSING_KEYS: {', '.join(missing)}")
        for key in ASSET_KEYS:
            nonempty_string(row, key, "ASSET_OWNERSHIP_INCOMPLETE_ROW")
        if row["asset_id"] not in REQUIRED_ASSET_IDS:
            fail("ASSET_OWNERSHIP_UNKNOWN_ASSET_ID")
        if row["asset_id"] in seen_ids:
            fail("ASSET_OWNERSHIP_DUPLICATE_ASSET_ID")
        if row["target_action"] not in ASSET_ACTIONS:
            fail("ASSET_OWNERSHIP_INVALID_ACTION")
        if row["source_path"] in seen_sources:
            fail("ASSET_OWNERSHIP_DUPLICATE_SOURCE")
        if not path_exists(row["source_path"]):
            fail("ASSET_OWNERSHIP_MISSING_SOURCE")
        seen_ids.add(row["asset_id"])
        seen_sources.add(row["source_path"])
        target_path = active_target(row)
        validate_consumer_ref(row["consumer"], "ASSET_OWNERSHIP_INVALID_CONSUMER")
        if row["validation_command"] not in KNOWN_VALIDATION_COMMANDS:
            fail("ASSET_OWNERSHIP_INVALID_COMMAND")
        script = validation_script(row["validation_command"], "ASSET_OWNERSHIP_INVALID_COMMAND")
        if row["validation_command"] not in smoke_ran:
            run_controlled_smoke(row["validation_command"], "ASSET_OWNERSHIP_INVALID_COMMAND")
            smoke_ran.add(row["validation_command"])
        if not contains_reverse_reference(row, target_path, script):
            fail("ASSET_OWNERSHIP_MISSING_REVERSE_REFERENCE")
    missing_ids = sorted(REQUIRED_ASSET_IDS - seen_ids)
    if missing_ids:
        fail(f"ASSET_OWNERSHIP_MISSING_REQUIRED_IDS: {', '.join(missing_ids)}")
    print(f"[PASS] {sample.get('sample_id', 'legacy-asset-ownership')}")


def main(argv: list[str]) -> None:
    """Run fixture validation from the command line."""
    if len(argv) != 2:
        fail("usage: check_skill_harness_contract.py <case.json>")
    sample = load_json(Path(argv[1]))
    mode = sample.get("mode")
    if mode == "field_consumer_contract":
        validate_field_consumer_contract(sample)
    elif mode == "legacy_asset_ownership":
        validate_asset_ownership(sample)
    else:
        validate_sample(sample)
        print(f"[PASS] {sample['sample_id']}")


if __name__ == "__main__":
    main(sys.argv)
