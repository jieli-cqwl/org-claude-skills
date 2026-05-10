#!/usr/bin/env python3
"""Grade skill-refiner fixture dogfood output against expected anchors.

Anchors target the v3 skill-refiner-result schema (schema_version 3.0.0).
Each SA-N anchor checks a different invariant that the refiner must satisfy
for the eval case to be considered faithfully executed.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Callable

SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_ROOT = SCRIPT_DIR.parent
SKILL_REL_PREFIX = Path("shared/skills/skill-refiner")

V3_DIMENSIONS = {
    "Trigger",
    "Responsibility",
    "Input",
    "Flow",
    "Output",
    "Resource",
    "Determinism",
    "Eval",
    "Runtime",
}
DIAGNOSIS_STATUSES = {"PASS", "ISSUE", "BLOCKED"}
OPERATIONS = {"optimize", "create", "rewrite", "replace", "split", "move", "delete"}
EXPECTED_SCHEMA_VERSION = "3.0.0"


# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------


def discover_repo_root() -> Path | None:
    for parent in SCRIPT_DIR.parents:
        if (parent / SKILL_REL_PREFIX / "SKILL.md").is_file():
            return parent
    return None


REPO_ROOT = discover_repo_root()


def skill_prefixed_path(path: Path) -> Path | None:
    prefix = SKILL_REL_PREFIX.parts
    if path.parts[: len(prefix)] != prefix:
        return None
    suffix = Path(*path.parts[len(prefix) :])
    return SKILL_ROOT / suffix


def candidate_paths(raw: str) -> list[Path]:
    path = Path(raw)
    if path.is_absolute():
        return [path]

    candidates: list[Path] = []
    prefixed = skill_prefixed_path(path)
    if prefixed is not None:
        candidates.append(prefixed)
    candidates.append(SKILL_ROOT / path)
    candidates.append(Path.cwd() / path)
    if REPO_ROOT is not None:
        candidates.append(REPO_ROOT / path)

    unique: list[Path] = []
    seen: set[str] = set()
    for item in candidates:
        key = str(item)
        if key not in seen:
            seen.add(key)
            unique.append(item)
    return unique


def resolve_path(raw: str, *, for_write: bool = False) -> Path:
    candidates = candidate_paths(raw)
    for path in candidates:
        if path.exists():
            return path.resolve()
    if for_write:
        for path in candidates:
            if path.parent.exists():
                return path.resolve()
    return candidates[0].resolve()


def display_path(path: Path) -> str:
    for root in (REPO_ROOT, SKILL_ROOT, Path.cwd()):
        if root is None:
            continue
        try:
            return path.relative_to(root).as_posix()
        except ValueError:
            continue
    return path.as_posix()


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def eval_case(evals: dict[str, Any], eval_id: str) -> dict[str, Any]:
    for item in evals.get("evals", []):
        if item.get("id") == eval_id:
            return item
    raise SystemExit(f"eval case not found: {eval_id}")


# ---------------------------------------------------------------------------
# Small typed accessors
# ---------------------------------------------------------------------------


def _dict(result: dict[str, Any], key: str) -> dict[str, Any]:
    value = result.get(key)
    return value if isinstance(value, dict) else {}


def _list(result: dict[str, Any], key: str) -> list[Any]:
    value = result.get(key)
    return value if isinstance(value, list) else []


def _non_empty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _string_array(value: Any, *, min_items: int = 1) -> bool:
    return (
        isinstance(value, list)
        and len(value) >= min_items
        and all(_non_empty_string(item) for item in value)
    )


# ---------------------------------------------------------------------------
# Anchor checks (SA-1 .. SA-12) — v3 schema
# ---------------------------------------------------------------------------


def check_sa_1(result: dict[str, Any]) -> bool:
    """Quality standard read + problem cards target v3 dimensions."""
    quality = _dict(result, "quality_standard")
    if quality.get("read") is not True:
        return False
    cards = _list(result, "problem_cards")
    if not cards:
        return False
    return all(
        isinstance(card, dict) and card.get("dimension") in V3_DIMENSIONS
        for card in cards
    )


def check_sa_2(result: dict[str, Any]) -> bool:
    """Professional domain is explicit and practice flow has >=4 real steps."""
    domain = _dict(result, "professional_domain")
    required_fields = {"name", "responsibilities", "non_goals", "success_boundary"}
    if not required_fields <= set(domain):
        return False
    if not _non_empty_string(domain.get("name")):
        return False
    if not _string_array(domain.get("responsibilities")):
        return False
    if not isinstance(domain.get("non_goals"), list):
        return False
    if not _non_empty_string(domain.get("success_boundary")):
        return False
    return _string_array(result.get("practice_flow"), min_items=4)


def check_sa_3(result: dict[str, Any]) -> bool:
    """Problem cards have the full v3 structure."""
    cards = _list(result, "problem_cards")
    if not cards:
        return False
    required = {
        "dimension",
        "phenomenon",
        "why_problem",
        "target_shape",
        "change_scope",
        "verification",
        "stop_condition",
    }
    for card in cards:
        if not isinstance(card, dict) or not required <= set(card):
            return False
        if card.get("dimension") not in V3_DIMENSIONS:
            return False
        for key in (
            "phenomenon",
            "why_problem",
            "target_shape",
            "verification",
            "stop_condition",
        ):
            if not _non_empty_string(card.get(key)):
                return False
        if not _string_array(card.get("change_scope")):
            return False
    return True


def check_sa_4(result: dict[str, Any]) -> bool:
    """Execution actually touched files (not a plan-only run)."""
    execution = _dict(result, "execution")
    modified = execution.get("modified_files") or []
    created = execution.get("created_files") or []
    deleted = execution.get("deleted_files") or []
    if not (
        isinstance(modified, list)
        and isinstance(created, list)
        and isinstance(deleted, list)
    ):
        return False
    return bool(modified) or bool(created) or bool(deleted)


def check_sa_5(result: dict[str, Any]) -> bool:
    """At least one verification command passed."""
    commands = _list(result, "verification_commands")
    if not commands:
        return False
    return any(
        isinstance(cmd, dict)
        and cmd.get("status") == "pass"
        and _non_empty_string(cmd.get("command"))
        and _non_empty_string(cmd.get("evidence"))
        for cmd in commands
    )


def check_sa_6(result: dict[str, Any]) -> bool:
    """Strategy freeze is intact: all required fields, no pre-freeze writes."""
    strategy = _dict(result, "strategy")
    required = {
        "final_operation",
        "scope",
        "exclusions",
        "risk",
        "no_file_changes_before_confirmation",
        "confirmed_by",
        "evidence",
    }
    if not required <= set(strategy):
        return False
    if strategy.get("final_operation") not in OPERATIONS:
        return False
    if not _string_array(strategy.get("scope")):
        return False
    if not isinstance(strategy.get("exclusions"), list):
        return False
    if not _non_empty_string(strategy.get("risk")):
        return False
    if strategy.get("no_file_changes_before_confirmation") is not True:
        return False
    if not _non_empty_string(strategy.get("confirmed_by")):
        return False
    return _non_empty_string(strategy.get("evidence"))


def check_sa_7(result: dict[str, Any]) -> bool:
    """Diagnosis covers all 9 v3 dimensions, each with a valid status."""
    diagnosis = _list(result, "diagnosis")
    seen: set[str] = set()
    for entry in diagnosis:
        if not isinstance(entry, dict):
            return False
        dimension = entry.get("dimension")
        status = entry.get("status")
        if dimension not in V3_DIMENSIONS or status not in DIAGNOSIS_STATUSES:
            return False
        seen.add(dimension)
    return seen == V3_DIMENSIONS


def check_sa_8(result: dict[str, Any]) -> bool:
    """Stage gate: strategy confirmed before execution; execution respects it."""
    strategy = _dict(result, "strategy")
    execution = _dict(result, "execution")
    return (
        strategy.get("no_file_changes_before_confirmation") is True
        and execution.get("started_after_strategy_confirmed") is True
    )


def check_sa_9(result: dict[str, Any]) -> bool:
    """scene_facts fields are all present and non-empty."""
    scene = _dict(result, "scene_facts")
    required = {
        "real_scenario",
        "business_constraint",
        "expected_outcome",
        "observed_pain",
        "protected_capability",
        "entry_point",
        "open_questions",
    }
    if not required <= set(scene):
        return False
    return all(_non_empty_string(scene.get(key)) for key in required)


def check_sa_10(result: dict[str, Any]) -> bool:
    """ISSUE/BLOCKED diagnosis entries carry the full reasoning bundle."""
    diagnosis = _list(result, "diagnosis")
    if not diagnosis:
        return False
    for entry in diagnosis:
        if not isinstance(entry, dict):
            return False
        if entry.get("status") in {"ISSUE", "BLOCKED"}:
            for key in (
                "evidence",
                "target_shape",
                "candidate_strategy",
                "verification",
            ):
                if not _non_empty_string(entry.get(key)):
                    return False
    return True


def check_sa_11(result: dict[str, Any]) -> bool:
    """optimization_goal is explicit: objective + success standards + exclusions."""
    goal = _dict(result, "optimization_goal")
    if not {"objective", "success_standards", "exclusions"} <= set(goal):
        return False
    if not _non_empty_string(goal.get("objective")):
        return False
    if not _string_array(goal.get("success_standards")):
        return False
    return isinstance(goal.get("exclusions"), list)


def check_sa_12(result: dict[str, Any]) -> bool:
    """Completion assessment is pass; final operation is a legal op."""
    assessment = _dict(result, "completion_assessment")
    if assessment.get("overall_status") != "pass":
        return False
    if not _string_array(assessment.get("checks")):
        return False
    if not isinstance(assessment.get("residual_risks"), list):
        return False
    strategy = _dict(result, "strategy")
    return strategy.get("final_operation") in OPERATIONS


ANCHOR_CHECKS: dict[str, tuple[Callable[[dict[str, Any]], bool], str]] = {
    "SA-1": (
        check_sa_1,
        "quality standard read and problem cards target v3 dimensions",
    ),
    "SA-2": (
        check_sa_2,
        "professional domain is explicit and practice flow has >=4 steps",
    ),
    "SA-3": (
        check_sa_3,
        "problem cards carry dimension, phenomenon, why_problem, target_shape, change_scope, verification, stop_condition",
    ),
    "SA-4": (
        check_sa_4,
        "execution actually modified / created / deleted at least one file",
    ),
    "SA-5": (
        check_sa_5,
        "at least one verification command passed with command + evidence",
    ),
    "SA-6": (
        check_sa_6,
        "strategy freeze has all required fields and forbids pre-freeze writes",
    ),
    "SA-7": (check_sa_7, "diagnosis covers all 9 v3 dimensions with a valid status"),
    "SA-8": (
        check_sa_8,
        "strategy freeze precedes execution; execution.started_after_strategy_confirmed is true",
    ),
    "SA-9": (
        check_sa_9,
        "scene_facts capture real_scenario, business_constraint, expected_outcome, observed_pain, protected_capability, entry_point, open_questions",
    ),
    "SA-10": (
        check_sa_10,
        "ISSUE/BLOCKED diagnosis entries carry evidence, target_shape, candidate_strategy, verification",
    ),
    "SA-11": (
        check_sa_11,
        "optimization_goal has objective + success_standards + exclusions",
    ),
    "SA-12": (
        check_sa_12,
        "completion_assessment overall_status is pass and strategy.final_operation is a supported operation",
    ),
}


def grade_anchor(anchor_id: str, result: dict[str, Any]) -> tuple[bool, str]:
    entry = ANCHOR_CHECKS.get(anchor_id)
    if entry is None:
        return False, f"unknown anchor {anchor_id}"
    check, evidence = entry
    return check(result), evidence


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Grade skill-refiner dogfood output against SA-* anchors (v3)."
    )
    parser.add_argument("--evals", required=True, help="Path to evals.json")
    parser.add_argument(
        "--result", required=True, help="Path to skill-refiner-result.json"
    )
    parser.add_argument(
        "--output", help="Optional output path for anchor fidelity JSON"
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    evals = load_json(resolve_path(args.evals))
    result_path = resolve_path(args.result)
    result = load_json(result_path)

    schema_version = result.get("schema_version")
    if schema_version != EXPECTED_SCHEMA_VERSION:
        raise SystemExit(
            f"result schema_version must be {EXPECTED_SCHEMA_VERSION}, got {schema_version!r}"
        )

    eval_id = result.get("eval_id")
    if not _non_empty_string(eval_id):
        raise SystemExit("result.eval_id is required")

    case = eval_case(evals, eval_id)
    expected = case.get("expected_anchors", [])
    if not expected:
        raise SystemExit("expected_anchors must not be empty")

    graded = []
    passed = 0
    for anchor_id in expected:
        ok, evidence = grade_anchor(anchor_id, result)
        if ok:
            passed += 1
        graded.append({"anchor_id": anchor_id, "passed": ok, "evidence": evidence})

    output = {
        "artifact_type": "skill-refiner-anchor-fidelity",
        "schema_version": EXPECTED_SCHEMA_VERSION,
        "eval_id": eval_id,
        "run_mode": result.get("run_mode"),
        "result_ref": display_path(result_path),
        "expected_anchor_count": len(expected),
        "passed_anchor_count": passed,
        "fidelity": round(passed / len(expected), 4),
        "anchors": graded,
    }

    if args.output:
        out_path = resolve_path(args.output, for_write=True)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(
            json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )

    print(json.dumps(output, ensure_ascii=False, indent=2))
    if passed != len(expected):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
