#!/usr/bin/env python3
"""Validate research retain evidence."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_SKILL = Path("shared/skills/research")
TOP_FIELDS = {
    "artifact_type",
    "schema_version",
    "evaluation_scope",
    "comparative_summary",
    "scenarios",
    "contract_checks",
    "verification_commands",
}
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
    "claim",
    "current_score",
    "baseline_score",
    "winner",
    "critical_failure",
    "current_evidence_terms",
    "baseline_gap",
    "evidence_refs",
}


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
    missing = sorted(fields - set(item))
    extra = sorted(set(item) - fields)
    if missing:
        errors.append(f"{ctx} missing fields: {', '.join(missing)}")
    if extra:
        errors.append(f"{ctx} has unknown fields: {', '.join(extra)}")
    return not missing and not extra


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


def rel_path(ref: str, errors: list[str], ctx: str) -> Path | None:
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


def check_refs(errors: list[str], refs: Any, ctx: str) -> None:
    for idx, ref in enumerate(string_list(refs, errors, ctx)):
        rel_path(ref, errors, f"{ctx}[{idx}]")


def round2(value: float) -> float:
    return round(value + 1e-9, 2)


def current_corpus() -> str:
    refs = [
        ROOT / "shared/skills/research/SKILL.md",
        ROOT / "shared/skills/research/test-prompts.json",
        ROOT / "shared/skills/research/evals/evals.json",
        ROOT / "shared/skills/research/evals/lifecycle-review.json",
    ]
    return "\n".join(path.read_text(encoding="utf-8") for path in refs).lower()


def validate_scope(errors: list[str], data: dict[str, Any]) -> None:
    scope = data.get("evaluation_scope")
    if not isinstance(scope, dict):
        errors.append("evaluation_scope must be an object")
        return
    if scope.get("kind") != "static_contract_and_recorded_eval_gate":
        errors.append("evaluation_scope.kind must be static_contract_and_recorded_eval_gate")
    boundary = str(scope.get("claim_boundary", "")).lower()
    if "retain" not in boundary or "not an external blind llm run" not in boundary:
        errors.append("evaluation_scope.claim_boundary must name retain and the non-external-blind boundary")
    check_refs(errors, scope.get("evidence_refs"), "evaluation_scope.evidence_refs")


def validate_scenarios(errors: list[str], data: dict[str, Any]) -> None:
    corpus = current_corpus()
    scenarios = data.get("scenarios")
    if not isinstance(scenarios, list) or len(scenarios) < 7:
        errors.append("scenarios must contain at least seven cases")
        scenarios = []
    current_scores: list[float] = []
    baseline_scores: list[float] = []
    winners: list[str] = []
    critical_failures = 0
    seen: set[str] = set()
    for idx, scenario in enumerate(scenarios):
        ctx = f"scenarios[{idx}]"
        if not require_fields(errors, scenario, SCENARIO_FIELDS, ctx):
            continue
        sid = scenario.get("id")
        if not isinstance(sid, str) or not sid.strip():
            errors.append(f"{ctx}.id must be a non-empty string")
        elif sid in seen:
            errors.append(f"{ctx}.id duplicated: {sid}")
        else:
            seen.add(sid)
        for field in ("claim", "baseline_gap"):
            if not isinstance(scenario.get(field), str) or not scenario[field].strip():
                errors.append(f"{ctx}.{field} must be a non-empty string")
        for field in ("current_score", "baseline_score"):
            value = scenario.get(field)
            if not isinstance(value, (int, float)) or not 0 <= value <= 5:
                errors.append(f"{ctx}.{field} must be a 0-5 number")
        current = float(scenario.get("current_score", 0) or 0)
        baseline = float(scenario.get("baseline_score", 0) or 0)
        current_scores.append(current)
        baseline_scores.append(baseline)
        expected_winner = "current" if current > baseline else "baseline" if baseline > current else "tie"
        winner = scenario.get("winner")
        winners.append(str(winner))
        if winner != expected_winner:
            errors.append(f"{ctx}.winner must be {expected_winner}")
        if scenario.get("critical_failure") not in {True, False}:
            errors.append(f"{ctx}.critical_failure must be boolean")
        elif scenario.get("critical_failure"):
            critical_failures += 1
        for term in string_list(scenario.get("current_evidence_terms"), errors, f"{ctx}.current_evidence_terms"):
            if term.lower() not in corpus:
                errors.append(f"{ctx}.current_evidence_terms missing from research corpus: {term}")
        check_refs(errors, scenario.get("evidence_refs"), f"{ctx}.evidence_refs")
    summary = data.get("comparative_summary")
    if not require_fields(errors, summary, SUMMARY_FIELDS, "comparative_summary"):
        return
    expected = {
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
        "critical_failures": critical_failures,
    }
    for key, expected_value in expected.items():
        actual = summary.get(key)
        if isinstance(expected_value, float):
            if not isinstance(actual, (int, float)) or abs(float(actual) - expected_value) > 0.01:
                errors.append(f"comparative_summary.{key} must be {expected_value}")
        elif actual != expected_value:
            errors.append(f"comparative_summary.{key} must be {expected_value}")
    if summary.get("current_avg", 0) < 4:
        errors.append("comparative_summary.current_avg must be >= 4")
    if summary.get("baseline_avg", 5) > 3:
        errors.append("comparative_summary.baseline_avg must be <= 3")
    if summary.get("uplift", 0) < 1:
        errors.append("comparative_summary.uplift must be >= 1")
    if summary.get("current_wins", 0) < 7:
        errors.append("comparative_summary.current_wins must be >= 7")
    if summary.get("critical_failures") != 0:
        errors.append("comparative_summary.critical_failures must be 0")


def validate_contract_checks(errors: list[str], data: dict[str, Any]) -> None:
    checks = data.get("contract_checks")
    if not isinstance(checks, list) or len(checks) < 5:
        errors.append("contract_checks must contain at least five checks")
        return
    for idx, check in enumerate(checks):
        ctx = f"contract_checks[{idx}]"
        if not isinstance(check, dict):
            errors.append(f"{ctx} must be an object")
            continue
        command = check.get("command")
        if not isinstance(command, str) or not command.strip():
            errors.append(f"{ctx}.command must be a non-empty string")
        else:
            parts = command.split()
            if len(parts) >= 2 and parts[0] in {"bash", "python3"}:
                rel_path(parts[1], errors, f"{ctx}.command target")
        if check.get("status") != "pass":
            errors.append(f"{ctx}.status must be pass")
        if not isinstance(check.get("evidence"), str) or not check["evidence"].strip():
            errors.append(f"{ctx}.evidence must be a non-empty string")


def validate_commands(errors: list[str], data: dict[str, Any]) -> None:
    commands = string_list(data.get("verification_commands"), errors, "verification_commands", min_items=5)
    for idx, command in enumerate(commands):
        parts = command.split()
        if len(parts) < 2 or parts[0] not in {"bash", "python3", "jq"}:
            errors.append(f"verification_commands[{idx}] must start with bash, python3, or jq")
            continue
        if parts[1].endswith(".sh") or parts[1].endswith(".py") or parts[1].endswith(".json"):
            rel_path(parts[1], errors, f"verification_commands[{idx}] target")


def validate(data: Any) -> list[str]:
    errors: list[str] = []
    if not require_fields(errors, data, TOP_FIELDS, "top-level"):
        return errors
    if data.get("artifact_type") != "research-retain-evidence":
        errors.append("artifact_type must be research-retain-evidence")
    if data.get("schema_version") != 1:
        errors.append("schema_version must be 1")
    validate_scope(errors, data)
    validate_scenarios(errors, data)
    validate_contract_checks(errors, data)
    validate_commands(errors, data)
    return errors


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[1] in {"-h", "--help"}:
        print("usage: validate_retain_evidence.py <research-retain-evidence.json>")
        return 0 if len(argv) == 2 else 2
    data = load_json(Path(argv[1]))
    errors = validate(data)
    if errors:
        print("[FAIL] research retain evidence invalid", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(f"[PASS] research retain evidence valid: {argv[1]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
