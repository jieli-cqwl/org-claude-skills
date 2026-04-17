#!/usr/bin/env python3
"""Validate skill-optimizer eval results before final aggregation."""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


RAW_COMMAND_FIELDS = {"shell", "raw_command"}
REQUIRED_FAILURE_CATEGORIES = {"missing_argument", "wrong_argument", "permission_denied", "format_injection"}


def fail(message: str) -> None:
    """Print a stable validation failure and exit nonzero."""
    print(f"[FAIL] {message}", file=sys.stderr)
    raise SystemExit(1)


def load_json(path: Path) -> dict[str, Any]:
    """Load a JSON object from disk."""
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


def command_ids(manifest: dict[str, Any]) -> set[str]:
    """Collect manifest command ids."""
    scripts = manifest.get("scripts")
    if not isinstance(scripts, list):
        fail("manifest scripts must be list")
    return {script["id"] for script in scripts if isinstance(script, dict) and isinstance(script.get("id"), str)}


def scan_raw_command(value: Any, path: str = "$") -> None:
    """Reject raw shell fields anywhere in the artifact."""
    if isinstance(value, dict):
        for key, nested in value.items():
            if key in RAW_COMMAND_FIELDS:
                fail(f"raw shell field found at {path}.{key}")
            scan_raw_command(nested, f"{path}.{key}")
    if isinstance(value, list):
        for index, nested in enumerate(value):
            scan_raw_command(nested, f"{path}[{index}]")


def validate_5_10_30(artifact: dict[str, Any]) -> None:
    """Keep 5/10/30 as usability evidence only."""
    evidence = artifact.get("usability_evidence", {}).get("five_ten_thirty", {})
    if evidence.get("counts_as_quality_benefit") is not False:
        fail("5/10/30 counted as quality benefit")
    if artifact.get("quality_benefit"):
        fail("quality_benefit is forbidden for eval results")
    for claim in artifact.get("quality_claims", []):
        if isinstance(claim, dict) and claim.get("source") == "5/10/30":
            fail("quality claim uses 5/10/30 source")


def validate_results(artifact: dict[str, Any], valid_command_ids: set[str]) -> None:
    """Validate categories, decisions, and command ids."""
    if artifact.get("artifact_type") != "eval-results":
        fail("artifact_type must be eval-results")
    draft = artifact.get("verification_result_draft_input", {})
    if draft.get("consumer") != "build_verification_result.py":
        fail("missing verification-result draft consumer")
    results = artifact.get("results")
    if not isinstance(results, list) or not results:
        fail("results must be nonempty")
    categories = {result.get("category") for result in results}
    missing_failure = sorted(REQUIRED_FAILURE_CATEGORIES - categories)
    if missing_failure:
        fail("missing failure path coverage: " + ", ".join(missing_failure))
    failures = []
    for result in results:
        if not isinstance(result, dict):
            fail("result entry must be object")
        if result.get("status") != "PASS":
            failures.append(str(result.get("case_id", "<unknown>")))
        if result.get("expected_decision") != result.get("observed_decision"):
            failures.append(str(result.get("case_id", "<unknown>")) + ":decision")
        command_id = result.get("run_command_id")
        if command_id and command_id not in valid_command_ids:
            fail(f"{result.get('case_id', '<unknown>')} unknown run_command_id: {command_id}")
    if failures:
        fail("eval failures: " + ", ".join(failures))
    summary = artifact.get("summary", {})
    if summary.get("failed") != 0 or summary.get("passed") != summary.get("total"):
        fail("summary reports failed evals")


def main(argv: list[str]) -> None:
    """Validate eval-results JSON from the command line."""
    if len(argv) != 3:
        fail("usage: validate_eval_results.py <eval-results.json> <manifest.json>")
    artifact = load_json(Path(argv[1]))
    manifest = load_json(Path(argv[2]))
    scan_raw_command(artifact)
    validate_5_10_30(artifact)
    validate_results(artifact, command_ids(manifest))


if __name__ == "__main__":
    main(sys.argv)
