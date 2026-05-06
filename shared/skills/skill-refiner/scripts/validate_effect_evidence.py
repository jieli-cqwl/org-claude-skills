#!/usr/bin/env python3
"""Validate skill-refiner fixture-backed comparative effect evidence."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_SKILL = Path("shared/skills/skill-refiner")
REQUIRED_SCENARIOS = {
    "continue-polishing-next-cut",
    "final-operation-create-gate",
    "all-ring-noisy-skill-refinement",
    "supersedes-drift-gate",
    "github-radar-external-practice",
}
TOP_FIELDS = {
    "artifact_type",
    "schema_version",
    "evaluation_scope",
    "scenarios",
    "verification_commands",
}
SCOPE_FIELDS = {
    "kind",
    "claim_boundary",
    "success_standard",
    "evidence_refs",
}
SCENARIO_FIELDS = {
    "id",
    "small_requirement",
    "failure_mode",
    "required_anchors",
    "best_practice_evidence",
    "current",
    "baseline",
    "winner",
    "verdict",
}
VARIANT_FIELDS = {
    "artifact_refs",
    "passed_anchors",
    "missing_anchors",
    "blocked_failure_modes",
    "score",
    "evidence_summary",
}


def repo_root() -> Path:
    for parent in SCRIPT_DIR.parents:
        if (parent / REPO_SKILL / "SKILL.md").is_file():
            return parent
    return Path.cwd()


ROOT = repo_root()


def load_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise SystemExit(f"cannot read {path}: {exc.strerror}") from exc
    except json.JSONDecodeError as exc:
        raise SystemExit(f"invalid JSON in {path}: {exc.msg}") from exc
    if not isinstance(data, dict):
        raise SystemExit(f"{path}: top-level value must be an object")
    return data


def require_fields(errors: list[str], item: Any, fields: set[str], ctx: str) -> bool:
    if not isinstance(item, dict):
        errors.append(f"{ctx} must be an object")
        return False
    actual = set(item)
    missing = sorted(fields - actual)
    extra = sorted(actual - fields)
    if missing:
        errors.append(f"{ctx} missing fields: {', '.join(missing)}")
    if extra:
        errors.append(f"{ctx} has unknown fields: {', '.join(extra)}")
    return not missing and not extra


def string_list(value: Any, ctx: str, errors: list[str], *, allow_empty: bool = False) -> list[str]:
    if not isinstance(value, list) or (not value and not allow_empty):
        errors.append(f"{ctx} must be a non-empty string list")
        return []
    result = [item for item in value if isinstance(item, str) and item.strip()]
    if len(result) != len(value):
        errors.append(f"{ctx} must contain only non-empty strings")
    if len(set(result)) != len(result):
        errors.append(f"{ctx} must not contain duplicates")
    return result


def check_existing_refs(errors: list[str], refs: Any, ctx: str) -> None:
    for ref in string_list(refs, ctx, errors):
        path = Path(ref)
        if not path.is_absolute():
            path = ROOT / path
        if not path.exists():
            errors.append(f"{ctx} missing referenced path: {ref}")


def validate_commands(errors: list[str], commands: Any) -> None:
    for command in string_list(commands, "verification_commands", errors):
        parts = command.split()
        if len(parts) != 2 or parts[0] not in {"bash", "python3"}:
            errors.append(f"verification_commands must use '<runner> <repo-relative-path>': {command}")
            continue
        path = ROOT / parts[1]
        if not path.exists():
            errors.append(f"verification_commands missing command target: {parts[1]}")


def validate_scope(errors: list[str], data: dict[str, Any]) -> None:
    scope = data.get("evaluation_scope")
    if not require_fields(errors, scope, SCOPE_FIELDS, "evaluation_scope"):
        return
    if scope.get("kind") != "fixture_backed_comparative_evidence":
        errors.append("evaluation_scope.kind must be fixture_backed_comparative_evidence")
    boundary = str(scope.get("claim_boundary", ""))
    if "not a live LLM benchmark" not in boundary:
        errors.append("evaluation_scope.claim_boundary must state this is not a live LLM benchmark")
    string_list(scope.get("success_standard"), "evaluation_scope.success_standard", errors)
    check_existing_refs(errors, scope.get("evidence_refs"), "evaluation_scope.evidence_refs")


def validate_variant(
    errors: list[str],
    variant: Any,
    ctx: str,
    required: set[str],
    expect_current: bool,
) -> int | None:
    if not require_fields(errors, variant, VARIANT_FIELDS, ctx):
        return None
    passed = set(
        string_list(variant.get("passed_anchors"), f"{ctx}.passed_anchors", errors, allow_empty=not expect_current)
    )
    missing = set(
        string_list(variant.get("missing_anchors"), f"{ctx}.missing_anchors", errors, allow_empty=expect_current)
    )
    check_existing_refs(errors, variant.get("artifact_refs"), f"{ctx}.artifact_refs")
    string_list(variant.get("blocked_failure_modes"), f"{ctx}.blocked_failure_modes", errors)
    if not isinstance(variant.get("evidence_summary"), str) or not variant["evidence_summary"].strip():
        errors.append(f"{ctx}.evidence_summary must be a non-empty string")
    score = variant.get("score")
    if not isinstance(score, int) or score < 0:
        errors.append(f"{ctx}.score must be a non-negative integer")
        return None
    if expect_current and not required <= passed:
        errors.append(f"{ctx}.passed_anchors must cover every required anchor")
    if expect_current and missing:
        errors.append(f"{ctx}.missing_anchors must be empty")
    if not expect_current and not missing:
        errors.append(f"{ctx}.missing_anchors must show at least one baseline gap")
    if not expect_current and required <= passed:
        errors.append(f"{ctx}.passed_anchors must not cover every required anchor")
    if not missing <= required:
        errors.append(f"{ctx}.missing_anchors contains anchors outside required_anchors")
    return score


def validate_best_practice(errors: list[str], scenario: dict[str, Any], required: set[str]) -> None:
    items = scenario.get("best_practice_evidence")
    if not isinstance(items, list) or not items:
        errors.append(f"{scenario.get('id')}.best_practice_evidence must be a non-empty list")
        return
    for idx, item in enumerate(items):
        ctx = f"{scenario.get('id')}.best_practice_evidence[{idx}]"
        if not isinstance(item, dict):
            errors.append(f"{ctx} must be an object")
            continue
        if set(item) != {"anchor", "ref", "evidence"}:
            errors.append(f"{ctx} must contain anchor, ref, and evidence")
            continue
        if item.get("anchor") not in required:
            errors.append(f"{ctx}.anchor must be listed in required_anchors")
        check_existing_refs(errors, [item.get("ref")], f"{ctx}.ref")
        if not isinstance(item.get("evidence"), str) or not item["evidence"].strip():
            errors.append(f"{ctx}.evidence must be a non-empty string")


def validate_scenario(errors: list[str], scenario: Any) -> str | None:
    if not require_fields(errors, scenario, SCENARIO_FIELDS, "scenario"):
        return None
    sid = scenario.get("id")
    if sid not in REQUIRED_SCENARIOS:
        errors.append(f"scenario.id is unknown: {sid}")
    for field in ("small_requirement", "failure_mode", "verdict"):
        if not isinstance(scenario.get(field), str) or not scenario[field].strip():
            errors.append(f"{sid}.{field} must be a non-empty string")
    required = set(string_list(scenario.get("required_anchors"), f"{sid}.required_anchors", errors))
    validate_best_practice(errors, scenario, required)
    current_score = validate_variant(errors, scenario.get("current"), f"{sid}.current", required, True)
    baseline_score = validate_variant(errors, scenario.get("baseline"), f"{sid}.baseline", required, False)
    if scenario.get("winner") != "current":
        errors.append(f"{sid}.winner must be current")
    if current_score is not None and baseline_score is not None and current_score <= baseline_score:
        errors.append(f"{sid}.current.score must be greater than baseline.score")
    return sid if isinstance(sid, str) else None


def validate(data: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    require_fields(errors, data, TOP_FIELDS, "top-level")
    if data.get("artifact_type") != "skill-refiner-effect-evidence":
        errors.append("artifact_type must be skill-refiner-effect-evidence")
    if data.get("schema_version") != 1:
        errors.append("schema_version must be 1")
    validate_scope(errors, data)
    scenarios = data.get("scenarios")
    if not isinstance(scenarios, list) or len(scenarios) != len(REQUIRED_SCENARIOS):
        errors.append(f"scenarios must contain exactly the required {len(REQUIRED_SCENARIOS)} cases")
        scenarios = []
    seen = {sid for scenario in scenarios if (sid := validate_scenario(errors, scenario))}
    if seen != REQUIRED_SCENARIOS:
        missing = sorted(REQUIRED_SCENARIOS - seen)
        extra = sorted(seen - REQUIRED_SCENARIOS)
        errors.append(f"scenario ids mismatch; missing={missing}, extra={extra}")
    validate_commands(errors, data.get("verification_commands"))
    return errors


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[1] in {"-h", "--help"}:
        print("usage: validate_effect_evidence.py <effect-evidence.json>")
        return 0 if len(argv) == 2 else 2
    path = Path(argv[1])
    data = load_json(path)
    errors = validate(data)
    if errors:
        print("[FAIL] skill-refiner effect evidence invalid", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(f"[PASS] skill-refiner effect evidence valid: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
