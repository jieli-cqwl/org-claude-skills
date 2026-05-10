#!/usr/bin/env python3
"""Validate product-manager Director handoff inputs."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from json import JSONDecodeError
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(REPO_ROOT / "tools" / "community"))

from validate_product_closure import assert_confirmation, assert_director_lock  # noqa: E402


FAILURE_OWNER = {
    "MISSING_INPUT": "product-manager",
    "SCHEMA_FAILURE": "product-manager",
    "DIRECTOR_HANDOFF_FAILED": "product-director",
    "PHASE_BOUNDARY_DRIFT": "product-director",
    "CANONICAL_SCHEMA_FAILURE": "product-manager",
    "CANONICAL_RULES_FAILURE": "product-manager",
    "PRIORITY_INCONSISTENCY_FAILURE": "product-manager",
    "TERMINOLOGY_DRIFT_FAILURE": "product-manager",
}

SCRIPT_DIR = Path(__file__).resolve().parent


class PreflightFailure(Exception):
    def __init__(self, code: str, reason: str):
        super().__init__(reason)
        self.code = code
        self.reason = reason


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--brief", type=Path)
    parser.add_argument("--phase-prd", type=Path)
    parser.add_argument("--phase-dir", type=Path)
    return parser.parse_args(argv)


def failure_payload(exc: PreflightFailure) -> dict[str, Any]:
    return {
        "status": "BLOCKED",
        "failure_code": exc.code,
        "owner": FAILURE_OWNER[exc.code],
        "reason": exc.reason,
    }


def load_json(path: Path, failure_code: str = "MISSING_INPUT") -> dict[str, Any]:
    if path.suffix != ".json":
        raise PreflightFailure(failure_code, f"canonical JSON path required: {path}")
    if not path.is_file():
        raise PreflightFailure(failure_code, f"missing required file: {path}")
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except JSONDecodeError as exc:
        raise PreflightFailure(
            "SCHEMA_FAILURE", f"malformed JSON: {path}: {exc}"
        ) from exc
    if not isinstance(payload, dict):
        raise PreflightFailure(
            "SCHEMA_FAILURE", f"top-level JSON must be an object: {path}"
        )
    return payload


def resolve_paths(args: argparse.Namespace) -> tuple[Path, Path, str]:
    if args.phase_dir is not None:
        if args.brief is not None or args.phase_prd is not None:
            raise PreflightFailure(
                "MISSING_INPUT",
                "--phase-dir cannot be combined with --brief or --phase-prd",
            )
        phase_dir = args.phase_dir
        if not phase_dir.is_dir():
            raise PreflightFailure("MISSING_INPUT", f"phase-dir not found: {phase_dir}")
        return (
            phase_dir.parent / "brief.json",
            phase_dir / "phase-prd.json",
            phase_dir.name,
        )

    if args.brief is None or args.phase_prd is None:
        raise PreflightFailure(
            "MISSING_INPUT", "provide --phase-dir or both --brief and --phase-prd"
        )
    return args.brief, args.phase_prd, args.phase_prd.parent.name


def assert_artifact_type(payload: dict[str, Any], expected: str, label: str) -> None:
    if payload.get("artifact_type") != expected:
        raise PreflightFailure(
            "SCHEMA_FAILURE", f"{label} artifact_type must be {expected}"
        )


def validate_director_lock(payload: dict[str, Any], label: str) -> None:
    try:
        assert_confirmation(payload, "director_confirmation", "passed", label)
        assert_director_lock(payload, label)
    except ValueError as exc:
        raise PreflightFailure("DIRECTOR_HANDOFF_FAILED", str(exc)) from exc


def validate_phase_boundary(
    brief: dict[str, Any], phase: dict[str, Any], phase_id: str
) -> None:
    delivery_plan = brief.get("delivery_plan")
    if not isinstance(delivery_plan, list):
        raise PreflightFailure(
            "PHASE_BOUNDARY_DRIFT", "brief delivery_plan must be an array"
        )
    matches = [
        item
        for item in delivery_plan
        if isinstance(item, dict) and item.get("phase_id") == phase_id
    ]
    if not matches:
        raise PreflightFailure(
            "PHASE_BOUNDARY_DRIFT",
            f"brief delivery_plan missing current Phase boundary: {phase_id}",
        )
    timebox = matches[0].get("iteration_timebox_days")
    if (
        isinstance(timebox, bool)
        or not isinstance(timebox, int)
        or timebox < 1
        or timebox > 14
    ):
        raise PreflightFailure(
            "PHASE_BOUNDARY_DRIFT",
            f"brief delivery_plan current Phase must include iteration_timebox_days between 1 and 14: {phase_id}",
        )
    if (
        not isinstance(phase.get("phase_goal"), str)
        or not phase.get("phase_goal", "").strip()
    ):
        raise PreflightFailure(
            "PHASE_BOUNDARY_DRIFT", "phase-prd phase_goal is missing"
        )


def run_canonical_validator(
    script_name: str,
    failure_code: str,
    phase_dir: Path,
) -> None:
    """Run a canonical validator as subprocess; raise PreflightFailure on non-zero exit.

    Canonical validators treat design.json/plan.json as optional, so they can
    run on pure PM output (brief + phase-prd + units). We invoke them as
    subprocess because they call sys.exit directly on failure; capturing stdout
    and stderr lets us surface the first error line in the preflight payload.
    """
    script_path = REPO_ROOT / "tools" / "community" / script_name
    completed = subprocess.run(
        [sys.executable, str(script_path), "--phase-dir", str(phase_dir)],
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        detail = (
            completed.stderr or completed.stdout or f"exit={completed.returncode}"
        ).strip()
        first_line = next(
            (line for line in detail.splitlines() if line.strip()), detail
        )
        raise PreflightFailure(failure_code, f"{script_name}: {first_line}")


def run_pm_cross_unit_check(
    script_name: str,
    failure_code: str,
    phase_dir: Path,
) -> None:
    """Run a PM-local cross-UNIT consistency check (priority / terminology).

    Mirrors run_canonical_validator but targets scripts that live next to this
    preflight (shared/skills/product-manager/scripts/), because priority
    consistency and terminology drift are PM-owned semantic checks, not
    repo-wide canonical rules.
    """
    script_path = SCRIPT_DIR / script_name
    completed = subprocess.run(
        [sys.executable, str(script_path), "--phase-dir", str(phase_dir)],
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        detail = (
            completed.stderr or completed.stdout or f"exit={completed.returncode}"
        ).strip()
        first_line = next(
            (line for line in detail.splitlines() if line.strip()), detail
        )
        raise PreflightFailure(failure_code, f"{script_name}: {first_line}")


def assert_units_present(phase_dir: Path) -> None:
    """Raise if the phase has no units/ directory or no UNIT-*.json files.

    Canonical validation requires at least one UNIT to run; if the PM run
    hasn't produced UNITs yet, surface a specific missing-input error so
    callers know why PM closure cannot be asserted.
    """
    units_dir = phase_dir / "units"
    if not units_dir.is_dir() or not list(units_dir.glob("UNIT-*.json")):
        raise PreflightFailure(
            "MISSING_INPUT",
            f"phase-dir missing units/UNIT-*.json for canonical validation: {phase_dir}",
        )


def validate(args: argparse.Namespace) -> dict[str, Any]:
    brief_path, phase_prd_path, phase_id = resolve_paths(args)
    brief = load_json(brief_path)
    phase = load_json(phase_prd_path)
    assert_artifact_type(brief, "brief", "brief.json")
    assert_artifact_type(phase, "phase-prd", "phase-prd.json")
    validate_director_lock(brief, "brief.json")
    validate_director_lock(phase, "phase-prd.json")
    validate_phase_boundary(brief, phase, phase_id)

    # Run canonical schema + rules only when we have a phase-dir with units present,
    # which is the precondition these validators need. In --brief/--phase-prd mode
    # the UNIT split hasn't happened yet, so we leave those checks to later calls
    # with --phase-dir. This closes the 7 structural drift classes (missing
    # chain_registry_digest, authoritative_fields, wrong producer, UNIT shape,
    # cross_unit_dependencies form, design_decision_candidates shape, fact_refs
    # cross-artifact rule) at the PM handoff, instead of leaking to /design.
    canonical_ran = False
    if args.phase_dir is not None:
        assert_units_present(args.phase_dir)
        run_canonical_validator(
            "validate_canonical_schema.py", "CANONICAL_SCHEMA_FAILURE", args.phase_dir
        )
        run_canonical_validator(
            "validate_canonical_rules.py", "CANONICAL_RULES_FAILURE", args.phase_dir
        )
        # Cross-UNIT semantic checks: priority graph consistency + terminology
        # drift. These are PM-owned, not covered by canonical schema/rules, and
        # the SKILL.md names them as M-S4/M-S7 mechanical gates.
        run_pm_cross_unit_check(
            "check_priority_consistency.py",
            "PRIORITY_INCONSISTENCY_FAILURE",
            args.phase_dir,
        )
        run_pm_cross_unit_check(
            "check_terminology_consistency.py",
            "TERMINOLOGY_DRIFT_FAILURE",
            args.phase_dir,
        )
        canonical_ran = True

    return {
        "status": "PASS",
        "brief": str(brief_path),
        "phase_id": phase_id,
        "phase_prd": str(phase_prd_path),
        "canonical_validated": canonical_ran,
    }


def main(argv: list[str]) -> int:
    try:
        args = parse_args(argv)
        result = validate(args)
    except PreflightFailure as exc:
        print(json.dumps(failure_payload(exc), ensure_ascii=False, sort_keys=True))
        return 1
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
