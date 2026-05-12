#!/usr/bin/env python3
"""Validate the skill-refiner retain gate evidence artifact."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_SKILL = Path("shared/skills/skill-refiner")
TOP_FIELDS = {
    "artifact_type",
    "schema_version",
    "evaluation_scope",
    "blind_pairwise",
    "real_use_pilots",
    "lifecycle_update",
    "verification_commands",
}
SCOPE_FIELDS = {
    "kind",
    "claim_boundary",
    "source_run",
    "current_arm",
    "baseline_arm",
    "evidence_refs",
}
PAIRWISE_FIELDS = {"scoring_scale", "summary", "scenarios"}
SUMMARY_FIELDS = {
    "scenario_count",
    "current_wins",
    "baseline_wins",
    "ties",
    "current_avg",
    "baseline_avg",
    "uplift",
    "critical_failures",
}
SCENARIO_FIELDS = {
    "id",
    "source_artifacts",
    "blind_arm_order",
    "criteria",
    "current_score",
    "baseline_score",
    "winner",
    "critical_failure",
    "outcome_signal",
    "rationale",
}
SOURCE_FIELDS = {"current_response_ref", "baseline_response_ref"}
CRITERION_FIELDS = {
    "name",
    "max_points",
    "current_points",
    "baseline_points",
    "current_evidence_terms",
    "baseline_gap",
}
PILOT_FIELDS = {
    "id",
    "result_ref",
    "validator_command",
    "scope",
    "target_operation",
    "outcome",
    "evidence_refs",
}
LIFECYCLE_FIELDS = {"decision", "review_date", "retain_allowed", "evidence_refs"}


def repo_root() -> Path:
    for parent in SCRIPT_DIR.parents:
        if (parent / REPO_SKILL / "SKILL.md").is_file():
            return parent
    return Path.cwd()


ROOT = repo_root()


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise SystemExit(f"cannot read {path}: {exc.strerror}") from exc
    except json.JSONDecodeError as exc:
        raise SystemExit(f"invalid JSON in {path}: {exc.msg}") from exc


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


def rel_path(ref: Any, errors: list[str], ctx: str) -> Path | None:
    if not isinstance(ref, str) or not ref.strip():
        errors.append(f"{ctx} must be a non-empty string")
        return None
    path = Path(ref)
    if path.is_absolute():
        errors.append(f"{ctx} must be repo-relative: {ref}")
        return None
    full_path = ROOT / path
    if not full_path.exists():
        errors.append(f"{ctx} missing referenced path: {ref}")
        return None
    return full_path


def string_list(value: Any, errors: list[str], ctx: str, *, min_items: int = 1) -> list[str]:
    if not isinstance(value, list) or len(value) < min_items:
        errors.append(f"{ctx} must be a string list with at least {min_items} item(s)")
        return []
    result = [item for item in value if isinstance(item, str) and item.strip()]
    if len(result) != len(value):
        errors.append(f"{ctx} must contain only non-empty strings")
    if len(set(result)) != len(result):
        errors.append(f"{ctx} must not contain duplicates")
    return result


def check_refs(errors: list[str], refs: Any, ctx: str) -> None:
    for idx, ref in enumerate(string_list(refs, errors, ctx)):
        rel_path(ref, errors, f"{ctx}[{idx}]")


def response_text(response: dict[str, Any]) -> str:
    chunks = [
        str(response.get("decision", "")),
        str(response.get("recommended_owner", "")),
        str(response.get("reason_summary", "")),
    ]
    for key in ("next_steps", "risk_notes"):
        value = response.get(key)
        if isinstance(value, list):
            chunks.extend(str(item) for item in value)
    return "\n".join(chunks).lower()


def load_response(
    errors: list[str],
    ref: str,
    ctx: str,
    expected_id: str,
    expected_arm: str,
) -> dict[str, Any] | None:
    path = rel_path(ref, errors, ctx)
    if path is None:
        return None
    data = load_json(path)
    if not isinstance(data, dict):
        errors.append(f"{ctx} must point to an object JSON response")
        return None
    if data.get("scenario_id") != expected_id:
        errors.append(f"{ctx} scenario_id mismatch: {data.get('scenario_id')!r}")
    if data.get("arm") != expected_arm:
        errors.append(f"{ctx} arm mismatch: {data.get('arm')!r}")
    return data


def round2(value: float) -> float:
    return round(value + 1e-9, 2)


def validate_scope(errors: list[str], data: dict[str, Any]) -> None:
    scope = data.get("evaluation_scope")
    if not require_fields(errors, scope, SCOPE_FIELDS, "evaluation_scope"):
        return
    if scope.get("kind") != "blind_pairwise_recorded_triad_outputs":
        errors.append("evaluation_scope.kind must be blind_pairwise_recorded_triad_outputs")
    boundary = str(scope.get("claim_boundary", "")).lower()
    if "retain" not in boundary or "recorded" not in boundary:
        errors.append("evaluation_scope.claim_boundary must name the retain claim and recorded-output boundary")
    source_run = rel_path(scope.get("source_run"), errors, "evaluation_scope.source_run")
    if source_run is not None and not source_run.is_dir():
        errors.append("evaluation_scope.source_run must reference a run directory")
    if scope.get("current_arm") != "skill_refiner":
        errors.append("evaluation_scope.current_arm must be skill_refiner")
    if scope.get("baseline_arm") != "baseline":
        errors.append("evaluation_scope.baseline_arm must be baseline")
    check_refs(errors, scope.get("evidence_refs"), "evaluation_scope.evidence_refs")


def validate_criterion(errors: list[str], item: Any, ctx: str, current_blob: str) -> tuple[float, float, float]:
    if not require_fields(errors, item, CRITERION_FIELDS, ctx):
        return 0.0, 0.0, 0.0
    name = item.get("name")
    if not isinstance(name, str) or not name.strip():
        errors.append(f"{ctx}.name must be a non-empty string")
    for field in ("max_points", "current_points", "baseline_points"):
        value = item.get(field)
        if not isinstance(value, (int, float)) or value < 0:
            errors.append(f"{ctx}.{field} must be a non-negative number")
    max_points = float(item.get("max_points", 0) or 0)
    current_points = float(item.get("current_points", 0) or 0)
    baseline_points = float(item.get("baseline_points", 0) or 0)
    if current_points > max_points:
        errors.append(f"{ctx}.current_points must not exceed max_points")
    if baseline_points > max_points:
        errors.append(f"{ctx}.baseline_points must not exceed max_points")
    for term in string_list(item.get("current_evidence_terms"), errors, f"{ctx}.current_evidence_terms"):
        if term.lower() not in current_blob:
            errors.append(f"{ctx}.current_evidence_terms missing from current response: {term}")
    if not isinstance(item.get("baseline_gap"), str) or not item["baseline_gap"].strip():
        errors.append(f"{ctx}.baseline_gap must be a non-empty string")
    return current_points, baseline_points, max_points


def validate_scenario(errors: list[str], scenario: Any) -> tuple[float, float, str | None, bool]:
    if not require_fields(errors, scenario, SCENARIO_FIELDS, "blind_pairwise.scenario"):
        return 0.0, 0.0, None, False
    sid = scenario.get("id")
    if not isinstance(sid, str) or not sid.strip():
        errors.append("blind_pairwise.scenario.id must be a non-empty string")
        sid = ""
    artifacts = scenario.get("source_artifacts")
    if not require_fields(errors, artifacts, SOURCE_FIELDS, f"{sid}.source_artifacts"):
        return 0.0, 0.0, sid or None, False
    current = load_response(
        errors,
        artifacts.get("current_response_ref"),
        f"{sid}.source_artifacts.current_response_ref",
        sid,
        "skill_refiner",
    )
    load_response(
        errors,
        artifacts.get("baseline_response_ref"),
        f"{sid}.source_artifacts.baseline_response_ref",
        sid,
        "baseline",
    )
    blind_order = string_list(scenario.get("blind_arm_order"), errors, f"{sid}.blind_arm_order", min_items=2)
    if set(blind_order) != {"A", "B"}:
        errors.append(f"{sid}.blind_arm_order must contain A and B once")
    current_blob = response_text(current or {})
    criteria = scenario.get("criteria")
    if not isinstance(criteria, list) or len(criteria) < 3:
        errors.append(f"{sid}.criteria must contain at least three criteria")
        criteria = []
    current_points = 0.0
    baseline_points = 0.0
    max_points = 0.0
    for idx, item in enumerate(criteria):
        current_delta, baseline_delta, max_delta = validate_criterion(
            errors, item, f"{sid}.criteria[{idx}]", current_blob
        )
        current_points += current_delta
        baseline_points += baseline_delta
        max_points += max_delta
    if max_points <= 0:
        errors.append(f"{sid}.criteria max_points total must be positive")
    expected_current = round2((current_points / max_points) * 5) if max_points else 0.0
    expected_baseline = round2((baseline_points / max_points) * 5) if max_points else 0.0
    current_score = scenario.get("current_score")
    baseline_score = scenario.get("baseline_score")
    if not isinstance(current_score, (int, float)) or not 0 <= current_score <= 5:
        errors.append(f"{sid}.current_score must be a 0-5 number")
        current_score = 0.0
    if not isinstance(baseline_score, (int, float)) or not 0 <= baseline_score <= 5:
        errors.append(f"{sid}.baseline_score must be a 0-5 number")
        baseline_score = 0.0
    if abs(float(current_score) - expected_current) > 0.01:
        errors.append(f"{sid}.current_score must equal criteria-derived score {expected_current}")
    if abs(float(baseline_score) - expected_baseline) > 0.01:
        errors.append(f"{sid}.baseline_score must equal criteria-derived score {expected_baseline}")
    winner = scenario.get("winner")
    expected_winner = "tie"
    if current_score > baseline_score:
        expected_winner = "current"
    elif baseline_score > current_score:
        expected_winner = "baseline"
    if winner != expected_winner:
        errors.append(f"{sid}.winner must be {expected_winner}")
    if scenario.get("critical_failure") not in {True, False}:
        errors.append(f"{sid}.critical_failure must be boolean")
    for field in ("outcome_signal", "rationale"):
        if not isinstance(scenario.get(field), str) or not scenario[field].strip():
            errors.append(f"{sid}.{field} must be a non-empty string")
    return float(current_score), float(baseline_score), winner if isinstance(winner, str) else None, bool(scenario.get("critical_failure"))


def validate_blind_pairwise(errors: list[str], data: dict[str, Any]) -> None:
    pairwise = data.get("blind_pairwise")
    if not require_fields(errors, pairwise, PAIRWISE_FIELDS, "blind_pairwise"):
        return
    scale = pairwise.get("scoring_scale")
    if not isinstance(scale, dict) or scale.get("min") != 0 or scale.get("max") != 5:
        errors.append("blind_pairwise.scoring_scale must define min=0 and max=5")
    summary = pairwise.get("summary")
    require_fields(errors, summary, SUMMARY_FIELDS, "blind_pairwise.summary")
    scenarios = pairwise.get("scenarios")
    if not isinstance(scenarios, list) or len(scenarios) < 6:
        errors.append("blind_pairwise.scenarios must contain at least six scenarios")
        scenarios = []
    scores = [validate_scenario(errors, scenario) for scenario in scenarios]
    current_scores = [score[0] for score in scores]
    baseline_scores = [score[1] for score in scores]
    winners = [score[2] for score in scores]
    critical_failures = [score[3] for score in scores]
    expected_summary = {
        "scenario_count": len(scenarios),
        "current_wins": winners.count("current"),
        "baseline_wins": winners.count("baseline"),
        "ties": winners.count("tie"),
        "current_avg": round2(sum(current_scores) / len(current_scores)) if current_scores else 0,
        "baseline_avg": round2(sum(baseline_scores) / len(baseline_scores)) if baseline_scores else 0,
        "uplift": round2(
            (sum(current_scores) / len(current_scores))
            - (sum(baseline_scores) / len(baseline_scores))
        )
        if current_scores
        else 0,
        "critical_failures": sum(1 for item in critical_failures if item),
    }
    if isinstance(summary, dict):
        for key, expected in expected_summary.items():
            actual = summary.get(key)
            if isinstance(expected, float):
                if not isinstance(actual, (int, float)) or abs(float(actual) - expected) > 0.01:
                    errors.append(f"blind_pairwise.summary.{key} must be {expected}")
            elif actual != expected:
                errors.append(f"blind_pairwise.summary.{key} must be {expected}")
        if summary.get("current_avg", 0) < 4:
            errors.append("blind_pairwise.summary.current_avg must be >= 4")
        if summary.get("baseline_avg", 5) > 3:
            errors.append("blind_pairwise.summary.baseline_avg must be <= 3")
        if summary.get("uplift", 0) < 1:
            errors.append("blind_pairwise.summary.uplift must be >= 1")
        if summary.get("current_wins", 0) < 5:
            errors.append("blind_pairwise.summary.current_wins must be >= 5")
        if summary.get("critical_failures") != 0:
            errors.append("blind_pairwise.summary.critical_failures must be 0")


def validate_real_use_pilots(errors: list[str], data: dict[str, Any]) -> None:
    pilots = data.get("real_use_pilots")
    if not isinstance(pilots, list) or len(pilots) < 3:
        errors.append("real_use_pilots must contain at least three pilots")
        return
    for idx, pilot in enumerate(pilots):
        ctx = f"real_use_pilots[{idx}]"
        if not require_fields(errors, pilot, PILOT_FIELDS, ctx):
            continue
        result_path = rel_path(pilot.get("result_ref"), errors, f"{ctx}.result_ref")
        if result_path is not None:
            result = load_json(result_path)
            if not isinstance(result, dict):
                errors.append(f"{ctx}.result_ref must point to an object JSON")
            else:
                if result.get("artifact_type") != "skill-refiner-result":
                    errors.append(f"{ctx}.result_ref artifact_type must be skill-refiner-result")
                schema_version = result.get("schema_version")
                if schema_version not in {"2.0.0", "3.0.0"}:
                    errors.append(f"{ctx}.result_ref schema_version must be 2.0.0 or 3.0.0")
                if result.get("target", {}).get("operation") != pilot.get("target_operation"):
                    errors.append(f"{ctx}.target_operation must match result target.operation")
                if result.get("completion_assessment", {}).get("overall_status") != "pass":
                    errors.append(f"{ctx}.result_ref completion_assessment.overall_status must be pass")
        command = pilot.get("validator_command")
        if not isinstance(command, str) or not command.strip():
            errors.append(f"{ctx}.validator_command must be a non-empty command")
        elif not (
            "validate_refinement_result.py" in command
            or command.startswith("bash tests/test-skill-refiner-")
        ):
            errors.append(
                f"{ctx}.validator_command must run validate_refinement_result.py "
                "or a dedicated skill-refiner dogfood test"
            )
        if pilot.get("outcome") != "pass":
            errors.append(f"{ctx}.outcome must be pass")
        for field in ("id", "scope", "target_operation"):
            if not isinstance(pilot.get(field), str) or not pilot[field].strip():
                errors.append(f"{ctx}.{field} must be a non-empty string")
        check_refs(errors, pilot.get("evidence_refs"), f"{ctx}.evidence_refs")


def validate_lifecycle_update(errors: list[str], data: dict[str, Any]) -> None:
    lifecycle = data.get("lifecycle_update")
    if not require_fields(errors, lifecycle, LIFECYCLE_FIELDS, "lifecycle_update"):
        return
    if lifecycle.get("decision") != "retain":
        errors.append("lifecycle_update.decision must be retain")
    if lifecycle.get("review_date") != "2026-05-12":
        errors.append("lifecycle_update.review_date must be 2026-05-12")
    if lifecycle.get("retain_allowed") is not True:
        errors.append("lifecycle_update.retain_allowed must be true")
    check_refs(errors, lifecycle.get("evidence_refs"), "lifecycle_update.evidence_refs")


def validate_commands(errors: list[str], data: dict[str, Any]) -> None:
    commands = string_list(data.get("verification_commands"), errors, "verification_commands", min_items=4)
    for idx, command in enumerate(commands):
        parts = command.split()
        if len(parts) < 2 or parts[0] not in {"bash", "python3", "jq"}:
            errors.append(f"verification_commands[{idx}] must start with bash, python3, or jq")
            continue
        target = parts[1]
        if target == "-m" and len(parts) >= 4:
            target = parts[3]
        if target.endswith(".sh") or target.endswith(".py") or target.endswith(".json"):
            rel_path(target, errors, f"verification_commands[{idx}] target")


def validate(data: Any) -> list[str]:
    errors: list[str] = []
    if not require_fields(errors, data, TOP_FIELDS, "top-level"):
        return errors
    if data.get("artifact_type") != "skill-refiner-retain-evidence":
        errors.append("artifact_type must be skill-refiner-retain-evidence")
    if data.get("schema_version") != 1:
        errors.append("schema_version must be 1")
    validate_scope(errors, data)
    validate_blind_pairwise(errors, data)
    validate_real_use_pilots(errors, data)
    validate_lifecycle_update(errors, data)
    validate_commands(errors, data)
    return errors


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[1] in {"-h", "--help"}:
        print("usage: validate_retain_evidence.py <retain-evidence.json>")
        return 0 if len(argv) == 2 else 2
    path = Path(argv[1])
    data = load_json(path)
    errors = validate(data)
    if errors:
        print("[FAIL] skill-refiner retain evidence invalid", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(f"[PASS] skill-refiner retain evidence valid: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
