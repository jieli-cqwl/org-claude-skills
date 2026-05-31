#!/usr/bin/env python3
"""Validate product-manager Director handoff inputs."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from json import JSONDecodeError
from pathlib import Path
from typing import Any


def resolve_runtime_root(script_path: Path) -> Path:
    resolved = script_path.resolve()
    candidates = [
        *list(resolved.parents)[:5],
        Path.home() / ".codex",
        Path(os.environ.get("CODEX_HOME", Path.home() / ".codex")),
        Path.home() / ".claude",
        Path(os.environ.get("CLAUDE_HOME", Path.home() / ".claude")),
    ]

    for candidate in candidates:
        if (
            candidate / "tools" / "community" / "validate_product_closure.py"
        ).is_file():
            return candidate
    return resolved.parents[4]


RUNTIME_ROOT = resolve_runtime_root(Path(__file__))
sys.path.insert(0, str(RUNTIME_ROOT / "tools" / "community"))

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
    "PM_PRE_UNIT_MODEL_FAILURE": "product-manager",
    "PM_SCOPE_MAPPING_FAILURE": "product-manager",
    "PM_RISK_CLOSURE_FAILURE": "product-manager",
    "PM_COVERAGE_MATRIX_FAILURE": "product-manager",
    "PM_TECHNICAL_EVIDENCE_FAILURE": "product-manager",
    "PM_RELEASE_READINESS_FAILURE": "product-manager",
    "PM_PRE_REVIEW_ISSUE_FAILURE": "product-manager",
    "PM_DESIGN_HANDOFF_FAILURE": "product-manager",
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
    parser.add_argument(
        "--pre-unit",
        action="store_true",
        help="validate PM-owned evidence/model/risk fields before UNIT split",
    )
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
    script_path = RUNTIME_ROOT / "tools" / "community" / script_name
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


PRE_UNIT_FIELDS = (
    "evidence_sources",
    "as_is_flows",
    "to_be_flows",
    "business_process_graphs",
    "feature_inventory",
    "module_capability_matrix",
    "entry_scene_inventory",
    "business_objects",
    "state_transitions",
    "role_permission_matrix",
    "risk_ledger",
    "coverage_matrix",
    "technical_evidence_requirements",
)


def require_non_empty_array(payload: dict[str, Any], field: str) -> list[Any]:
    value = payload.get(field)
    if not isinstance(value, list) or not value:
        raise PreflightFailure(
            "PM_PRE_UNIT_MODEL_FAILURE",
            f"phase-prd missing non-empty PM model field: {field}",
        )
    return value


def validate_evidence_sources(phase: dict[str, Any]) -> None:
    for item in require_non_empty_array(phase, "evidence_sources"):
        if not isinstance(item, dict):
            raise PreflightFailure(
                "PM_PRE_UNIT_MODEL_FAILURE",
                "evidence_sources items must be objects",
            )
        status = item.get("status")
        if status == "ASSUMPTION":
            missing = [
                field
                for field in ("gap_reason", "required_evidence", "blocks_fields")
                if not item.get(field)
            ]
            if missing:
                raise PreflightFailure(
                    "PM_PRE_UNIT_MODEL_FAILURE",
                    "ASSUMPTION evidence must carry gap_reason, required_evidence, and blocks_fields",
                )
        if item.get("source_type") == "screenshot":
            missing = [
                field
                for field in ("screenshot_ref", "captured_at", "entry_ref")
                if not item.get(field)
            ]
            if missing:
                raise PreflightFailure(
                    "PM_PRE_UNIT_MODEL_FAILURE",
                    "screenshot evidence must carry screenshot_ref, captured_at, and entry_ref",
                )


def validate_feature_inventory(phase: dict[str, Any]) -> None:
    for item in require_non_empty_array(phase, "feature_inventory"):
        if not isinstance(item, dict):
            raise PreflightFailure(
                "PM_SCOPE_MAPPING_FAILURE",
                "feature_inventory items must be objects",
            )
        status = item.get("scope_status")
        unit_refs = item.get("unit_refs")
        if not isinstance(unit_refs, list):
            raise PreflightFailure(
                "PM_SCOPE_MAPPING_FAILURE",
                "feature_inventory[].unit_refs must be an array",
            )
        if status == "IN_SCOPE" and not unit_refs:
            raise PreflightFailure(
                "PM_SCOPE_MAPPING_FAILURE",
                "IN_SCOPE feature_inventory item must map at least one UNIT",
            )
        if status == "OUT_OF_SCOPE":
            if unit_refs:
                raise PreflightFailure(
                    "PM_SCOPE_MAPPING_FAILURE",
                    "OUT_OF_SCOPE feature_inventory item must not map UNITs",
                )
            if not item.get("boundary_ref"):
                raise PreflightFailure(
                    "PM_SCOPE_MAPPING_FAILURE",
                    "OUT_OF_SCOPE feature_inventory item must carry boundary_ref",
                )
        if status == "NEEDS_DECISION":
            if unit_refs:
                raise PreflightFailure(
                    "PM_SCOPE_MAPPING_FAILURE",
                    "NEEDS_DECISION feature_inventory item must not map UNITs",
                )
            if not item.get("decision_needed"):
                raise PreflightFailure(
                    "PM_SCOPE_MAPPING_FAILURE",
                    "NEEDS_DECISION feature_inventory item must carry decision_needed",
                )


def validate_risk_ledger(phase: dict[str, Any]) -> None:
    for item in require_non_empty_array(phase, "risk_ledger"):
        if not isinstance(item, dict):
            raise PreflightFailure(
                "PM_RISK_CLOSURE_FAILURE", "risk_ledger items must be objects"
            )
        status = item.get("status")
        if status in {"OPEN", "BLOCKED"}:
            raise PreflightFailure(
                "PM_RISK_CLOSURE_FAILURE",
                f"risk_ledger contains non-closed risk status: {item.get('risk_id', '<unknown>')}={status}",
            )
        if not item.get("verification_target"):
            raise PreflightFailure(
                "PM_RISK_CLOSURE_FAILURE",
                f"risk_ledger item missing verification_target: {item.get('risk_id', '<unknown>')}",
            )
        if not item.get("mitigation_or_owner"):
            raise PreflightFailure(
                "PM_RISK_CLOSURE_FAILURE",
                f"risk_ledger item missing mitigation_or_owner: {item.get('risk_id', '<unknown>')}",
            )


def validate_coverage_matrix(phase: dict[str, Any]) -> None:
    for item in require_non_empty_array(phase, "coverage_matrix"):
        if not isinstance(item, dict):
            raise PreflightFailure(
                "PM_COVERAGE_MATRIX_FAILURE", "coverage_matrix items must be objects"
            )
        missing = [
            field
            for field in (
                "coverage_id",
                "scenario_ref",
                "business_type",
                "platform",
                "action_or_path",
                "support_status",
            )
            if not item.get(field)
        ]
        if not isinstance(item.get("evidence_targets"), list) or not item.get(
            "evidence_targets"
        ):
            missing.append("evidence_targets")
        if missing:
            raise PreflightFailure(
                "PM_COVERAGE_MATRIX_FAILURE",
                f"coverage_matrix item missing fields: {', '.join(missing)}",
            )
        status = item.get("support_status")
        if status in {"SUPPORTED", "CONDITIONAL"}:
            for field in ("unit_refs", "ac_refs"):
                if not isinstance(item.get(field), list) or not item.get(field):
                    raise PreflightFailure(
                        "PM_COVERAGE_MATRIX_FAILURE",
                        f"{status} coverage_matrix item must map {field}: {item.get('coverage_id', '<unknown>')}",
                    )
        if status == "UNSUPPORTED" and not item.get("decision_or_boundary_ref"):
            raise PreflightFailure(
                "PM_COVERAGE_MATRIX_FAILURE",
                f"UNSUPPORTED coverage_matrix item must carry decision_or_boundary_ref: {item.get('coverage_id', '<unknown>')}",
            )


def validate_technical_evidence_requirements(phase: dict[str, Any]) -> None:
    for item in require_non_empty_array(phase, "technical_evidence_requirements"):
        if not isinstance(item, dict):
            raise PreflightFailure(
                "PM_TECHNICAL_EVIDENCE_FAILURE",
                "technical_evidence_requirements items must be objects",
            )
        missing = [
            field
            for field in (
                "requirement_id",
                "domain",
                "business_invariant",
                "required_downstream_proof",
                "status",
            )
            if not item.get(field)
        ]
        if not isinstance(item.get("unit_refs"), list) or not item.get("unit_refs"):
            missing.append("unit_refs")
        if not isinstance(item.get("risk_refs"), list):
            missing.append("risk_refs")
        if missing:
            raise PreflightFailure(
                "PM_TECHNICAL_EVIDENCE_FAILURE",
                f"technical_evidence_requirements item missing fields: {', '.join(missing)}",
            )
        if item.get("status") == "BLOCKED":
            raise PreflightFailure(
                "PM_TECHNICAL_EVIDENCE_FAILURE",
                f"technical_evidence_requirements contains BLOCKED item: {item.get('requirement_id', '<unknown>')}",
            )


def validate_release_readiness(phase: dict[str, Any]) -> None:
    readiness = phase.get("release_readiness")
    if not isinstance(readiness, dict):
        raise PreflightFailure(
            "PM_RELEASE_READINESS_FAILURE", "release_readiness must be an object"
        )
    for field in (
        "supported_platforms",
        "conditional_platforms",
        "unsupported_platforms",
        "residual_risks",
    ):
        if not isinstance(readiness.get(field), list):
            raise PreflightFailure(
                "PM_RELEASE_READINESS_FAILURE",
                f"release_readiness.{field} must be an array",
            )
    for item in readiness.get("residual_risks", []):
        if not isinstance(item, dict):
            raise PreflightFailure(
                "PM_RELEASE_READINESS_FAILURE",
                "release_readiness.residual_risks items must be objects",
            )
        missing = [
            field
            for field in (
                "risk_id",
                "description",
                "owner",
                "target_resolution",
                "status",
            )
            if not item.get(field)
        ]
        if missing:
            raise PreflightFailure(
                "PM_RELEASE_READINESS_FAILURE",
                f"release_readiness residual risk missing fields: {', '.join(missing)}",
            )
        if item.get("status") in {"OPEN", "BLOCKED"}:
            raise PreflightFailure(
                "PM_RELEASE_READINESS_FAILURE",
                f"release_readiness contains open residual risk: {item.get('risk_id', '<unknown>')}={item.get('status')}",
            )


def validate_business_process_graphs(phase: dict[str, Any]) -> None:
    for graph in require_non_empty_array(phase, "business_process_graphs"):
        if not isinstance(graph, dict):
            raise PreflightFailure(
                "PM_PRE_UNIT_MODEL_FAILURE",
                "business_process_graphs items must be objects",
            )
        for node in graph.get("nodes", []):
            if not isinstance(node, dict):
                raise PreflightFailure(
                    "PM_PRE_UNIT_MODEL_FAILURE",
                    "business_process_graphs[].nodes items must be objects",
                )
            missing = [
                field
                for field in ("step_id", "label", "actor", "object_state")
                if not node.get(field)
            ]
            if missing:
                raise PreflightFailure(
                    "PM_PRE_UNIT_MODEL_FAILURE",
                    f"business_process_graphs node missing fields: {', '.join(missing)}",
                )
        for edge in graph.get("edges", []):
            if not isinstance(edge, dict):
                raise PreflightFailure(
                    "PM_PRE_UNIT_MODEL_FAILURE",
                    "business_process_graphs[].edges items must be objects",
                )
            missing = [
                field
                for field in (
                    "from_step",
                    "to_step",
                    "condition",
                    "object_state_change",
                )
                if not edge.get(field)
            ]
            if missing or not isinstance(edge.get("risk_refs"), list):
                detail = ", ".join(
                    missing
                    + ([] if isinstance(edge.get("risk_refs"), list) else ["risk_refs"])
                )
                raise PreflightFailure(
                    "PM_PRE_UNIT_MODEL_FAILURE",
                    f"business_process_graphs edge missing fields: {detail}",
                )


def validate_pre_review_issues(phase: dict[str, Any]) -> None:
    issues = phase.get("pre_review_issue_ledger", [])
    if issues is None:
        return
    if not isinstance(issues, list):
        raise PreflightFailure(
            "PM_PRE_REVIEW_ISSUE_FAILURE",
            "pre_review_issue_ledger must be an array",
        )
    open_statuses = {"OPEN", "BLOCKED", "MISSING", "PARTIAL"}
    for item in issues:
        if not isinstance(item, dict):
            raise PreflightFailure(
                "PM_PRE_REVIEW_ISSUE_FAILURE",
                "pre_review_issue_ledger items must be objects",
            )
        if item.get("status") in open_statuses:
            raise PreflightFailure(
                "PM_PRE_REVIEW_ISSUE_FAILURE",
                f"pre_review_issue_ledger contains unresolved item: {item.get('issue_id', '<unknown>')}={item.get('status')}",
            )


def validate_design_handoff_aliases(phase: dict[str, Any]) -> None:
    forbidden = {"decision", "affected_units", "handoff_target"}
    for item in phase.get("design_decision_candidates", []):
        if not isinstance(item, dict):
            raise PreflightFailure(
                "PM_DESIGN_HANDOFF_FAILURE",
                "design_decision_candidates items must be objects",
            )
        present = sorted(forbidden.intersection(item))
        if present:
            raise PreflightFailure(
                "PM_DESIGN_HANDOFF_FAILURE",
                f"design_decision_candidates contains forbidden aliases: {', '.join(present)}",
            )


def validate_pm_model_fields(phase: dict[str, Any]) -> None:
    for field in PRE_UNIT_FIELDS:
        require_non_empty_array(phase, field)
    validate_evidence_sources(phase)
    validate_business_process_graphs(phase)
    validate_feature_inventory(phase)
    validate_risk_ledger(phase)
    validate_coverage_matrix(phase)
    validate_technical_evidence_requirements(phase)
    validate_release_readiness(phase)
    validate_pre_review_issues(phase)
    validate_design_handoff_aliases(phase)


def validate(args: argparse.Namespace) -> dict[str, Any]:
    if args.pre_unit and args.phase_dir is None:
        raise PreflightFailure("MISSING_INPUT", "--pre-unit requires --phase-dir")
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
        validate_pm_model_fields(phase)
        if args.pre_unit:
            return {
                "status": "PASS",
                "brief": str(brief_path),
                "phase_id": phase_id,
                "phase_prd": str(phase_prd_path),
                "canonical_validated": False,
                "pm_pre_unit_validated": True,
            }
        assert_units_present(args.phase_dir)
        run_canonical_validator(
            "validate_canonical_schema.py", "CANONICAL_SCHEMA_FAILURE", args.phase_dir
        )
        run_canonical_validator(
            "validate_canonical_rules.py", "CANONICAL_RULES_FAILURE", args.phase_dir
        )
        # Cross-UNIT semantic checks: priority graph consistency + terminology
        # drift. These are PM-owned, not covered by canonical schema/rules, and
        # the SKILL.md names them as UNIT split/Self-check mechanical gates.
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
        "pm_pre_unit_validated": args.phase_dir is not None,
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
