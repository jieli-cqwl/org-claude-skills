#!/usr/bin/env python3
"""Validate delivery-owner kickoff input readiness for a standard-chain phase."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


def load_json(path: Path, failures: list[str], label: str) -> dict[str, Any]:
    if not path.is_file():
        failures.append(f"missing required artifact: {label} ({path})")
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        failures.append(f"invalid JSON for {label}: {exc}")
        return {}
    if not isinstance(data, dict):
        failures.append(f"{label} must be a JSON object")
        return {}
    return data


def normalize_unit_ids(phase_prd: dict[str, Any], phase_dir: Path) -> list[str]:
    raw = phase_prd.get("unit_index")
    unit_ids: list[str] = []
    if isinstance(raw, list):
        for item in raw:
            if isinstance(item, str) and item.strip():
                unit_ids.append(item.strip())
            elif isinstance(item, dict):
                value = item.get("unit_id") or item.get("id")
                if isinstance(value, str) and value.strip():
                    unit_ids.append(value.strip())
    if unit_ids:
        return unit_ids
    units_dir = phase_dir / "units"
    return sorted(path.stem for path in units_dir.glob("UNIT-*.json"))


def active_registry_entries(
    phase_dir: Path,
    registry: dict[str, Any],
    failures: list[str],
) -> list[dict[str, Any]]:
    active_revision_id = registry.get("active_revision_id")
    if not isinstance(active_revision_id, str) or not active_revision_id:
        failures.append("artifact-registry.active_revision_id is missing")
        return []

    revisions = registry.get("revisions")
    if not isinstance(revisions, list):
        failures.append("artifact-registry.revisions must be a list")
        return []

    active_revision = None
    for revision in revisions:
        if isinstance(revision, dict) and revision.get("revision_id") == active_revision_id:
            active_revision = revision
            break
    if active_revision is None:
        failures.append(f"artifact-registry active revision not found: {active_revision_id}")
        return []

    entries = active_revision.get("entries")
    if not isinstance(entries, list) or not entries:
        failures.append("artifact-registry active revision has no entries")
        return []

    active_entries: list[dict[str, Any]] = []
    feature_dir = phase_dir.parent.resolve()
    for entry in entries:
        if not isinstance(entry, dict):
            failures.append("artifact-registry entry must be an object")
            continue
        if entry.get("active_for_consumption") is not True:
            continue
        if entry.get("lifecycle_state") != "FINALIZED":
            failures.append(f"artifact-registry entry is not FINALIZED: {entry.get('artifact_id')}")
            continue
        artifact_path = entry.get("artifact_path")
        if not isinstance(artifact_path, str) or not artifact_path:
            failures.append(f"artifact-registry entry missing artifact_path: {entry.get('artifact_id')}")
            continue
        if Path(artifact_path).is_absolute():
            failures.append(f"artifact-registry active path must be relative: {artifact_path}")
            continue
        resolved = (phase_dir / artifact_path).resolve()
        try:
            resolved.relative_to(feature_dir)
        except ValueError:
            failures.append(f"artifact-registry active path escapes feature boundary: {artifact_path}")
            continue
        if not resolved.is_file():
            failures.append(f"artifact-registry active path is missing: {artifact_path}")
            continue
        active_entries.append(entry)
    return active_entries


def require_active_types(entries: list[dict[str, Any]], failures: list[str]) -> None:
    present = {
        entry.get("artifact_type")
        for entry in entries
        if isinstance(entry.get("artifact_type"), str)
    }
    required = {
        "brief",
        "phase-prd",
        "unit-definition",
        "design",
        "plan",
        "tasks",
        "test-cases",
    }
    missing = sorted(required - present)
    if missing:
        failures.append(f"artifact-registry active revision missing types: {', '.join(missing)}")


def require_unit_registry_entries(
    entries: list[dict[str, Any]],
    unit_ids: list[str],
    failures: list[str],
) -> None:
    unit_paths = {
        entry.get("artifact_path")
        for entry in entries
        if entry.get("artifact_type") == "unit-definition"
    }
    for unit_id in unit_ids:
        artifact_path = f"units/{unit_id}.json"
        if artifact_path not in unit_paths:
            failures.append(
                "artifact-registry active revision missing unit-definition "
                f"for {artifact_path}"
            )


def validate_registry_payloads(
    phase_dir: Path,
    entries: list[dict[str, Any]],
    failures: list[str],
) -> None:
    for entry in entries:
        artifact_path = entry.get("artifact_path")
        if not isinstance(artifact_path, str) or not artifact_path:
            continue
        payload = load_json(
            (phase_dir / artifact_path).resolve(),
            failures,
            f"artifact-registry payload {artifact_path}",
        )
        for key in ("artifact_id", "artifact_type"):
            registry_value = entry.get(key)
            payload_value = payload.get(key)
            if registry_value != payload_value:
                failures.append(
                    "artifact-registry payload drift: "
                    f"{artifact_path} {key} registry={registry_value!r} payload={payload_value!r}"
                )


def validate_plan_confirmation(plan: dict[str, Any], failures: list[str]) -> None:
    confirmation = plan.get("user_confirmation")
    if not isinstance(confirmation, dict):
        failures.append("plan.user_confirmation is required before delivery-owner kickoff")
        return
    status = confirmation.get("status")
    if status not in {"CONFIRMED", "APPROVED"}:
        failures.append(f"plan.user_confirmation.status must be CONFIRMED or APPROVED, got {status!r}")


def validate_tasks(tasks: dict[str, Any], failures: list[str]) -> None:
    task_list = tasks.get("tasks")
    if not isinstance(task_list, list) or not task_list:
        failures.append("tasks.tasks must be a non-empty list")
        return
    seen: set[str] = set()
    for index, task in enumerate(task_list):
        if not isinstance(task, dict):
            failures.append(f"tasks.tasks[{index}] must be an object")
            continue
        task_id = task.get("task_id")
        if not isinstance(task_id, str) or not task_id:
            failures.append(f"tasks.tasks[{index}].task_id is required")
            continue
        if task_id in seen:
            failures.append(f"duplicate task_id in tasks.json: {task_id}")
        seen.add(task_id)


def validate_test_cases(test_cases: dict[str, Any], label: str, failures: list[str]) -> None:
    design_gap_report = test_cases.get("design_gap_report")
    if not isinstance(design_gap_report, dict):
        failures.append(f"{label}.design_gap_report is required")
    else:
        gaps = design_gap_report.get("gaps", [])
        if not isinstance(gaps, list):
            failures.append(f"{label}.design_gap_report.gaps must be a list")
        else:
            for gap in gaps:
                if isinstance(gap, dict) and gap.get("blocking") is True:
                    failures.append(f"{label} has blocking design gap: {gap.get('gap_id', '<unknown>')}")

    qa_handoff = test_cases.get("qa_handoff_contract")
    if not isinstance(qa_handoff, list) or not qa_handoff:
        failures.append(f"{label}.qa_handoff_contract must be a non-empty list")

    cross_unit = test_cases.get("cross_unit_obligations")
    if not isinstance(cross_unit, list):
        failures.append(f"{label}.cross_unit_obligations must be a list")


def validate_phase(phase_dir: Path) -> list[str]:
    failures: list[str] = []
    phase_dir = phase_dir.resolve()
    feature_dir = phase_dir.parent

    brief = load_json(feature_dir / "brief.json", failures, "brief.json")
    phase_prd = load_json(phase_dir / "phase-prd.json", failures, "phase-prd.json")
    load_json(phase_dir / "design.json", failures, "design.json")
    plan = load_json(phase_dir / "plan.json", failures, "plan.json")
    tasks = load_json(phase_dir / "tasks.json", failures, "tasks.json")
    registry = load_json(phase_dir / "artifact-registry.json", failures, "artifact-registry.json")

    if brief.get("artifact_type") not in {None, "brief"}:
        failures.append("brief.json artifact_type must be brief when present")
    validate_plan_confirmation(plan, failures)
    validate_tasks(tasks, failures)

    entries = active_registry_entries(phase_dir, registry, failures)
    validate_registry_payloads(phase_dir, entries, failures)
    require_active_types(entries, failures)

    unit_ids = normalize_unit_ids(phase_prd, phase_dir)
    if not unit_ids:
        failures.append("phase-prd.unit_index must identify at least one UNIT")
    require_unit_registry_entries(entries, unit_ids, failures)

    for unit_id in unit_ids:
        unit_path = phase_dir / "units" / f"{unit_id}.json"
        load_json(unit_path, failures, f"units/{unit_id}.json")

        unit_slug = unit_id.lower()
        test_cases_path = phase_dir / unit_slug / "test-cases.json"
        test_cases = load_json(test_cases_path, failures, f"{unit_slug}/test-cases.json")
        if test_cases:
            validate_test_cases(test_cases, f"{unit_slug}/test-cases.json", failures)

    return failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--phase-dir", required=True, help="Path to docs/{feature}/phase-{N}")
    args = parser.parse_args()

    failures = validate_phase(Path(args.phase_dir))
    if failures:
        for failure in failures:
            print(f"[FAIL] {failure}", file=sys.stderr)
        return 1

    print("delivery-owner input readiness passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
