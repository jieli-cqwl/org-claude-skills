from __future__ import annotations

from pathlib import Path
from typing import Any

from intake_common import IntakeFailure, load_json, nonempty_strings


def active_registry_entries(registry: dict[str, Any]) -> list[dict[str, Any]]:
    active_revision_id = registry.get("active_revision_id")
    revisions = registry.get("revisions")
    if not isinstance(active_revision_id, str) or not isinstance(revisions, list):
        raise IntakeFailure(
            "INVALID_ARTIFACT_REGISTRY",
            "NEEDS_INPUT",
            "delivery-owner",
            "artifact-registry.json must contain active_revision_id and revisions",
            ["artifact-registry.json"],
        )
    for revision in revisions:
        if (
            isinstance(revision, dict)
            and revision.get("revision_id") == active_revision_id
        ):
            entries = revision.get("entries")
            if isinstance(entries, list):
                return [entry for entry in entries if isinstance(entry, dict)]
    raise IntakeFailure(
        "INVALID_ARTIFACT_REGISTRY",
        "NEEDS_INPUT",
        "delivery-owner",
        f"artifact-registry active revision not found: {active_revision_id}",
        ["artifact-registry.active_revision_id"],
    )


def active_test_case_paths(phase_dir: Path, registry: dict[str, Any]) -> list[Path]:
    paths: list[Path] = []
    for entry in active_registry_entries(registry):
        if (
            entry.get("artifact_type") != "test-cases"
            or entry.get("active_for_consumption") is not True
        ):
            continue
        artifact_path = entry.get("artifact_path")
        if isinstance(artifact_path, str) and artifact_path.strip():
            paths.append(phase_dir / artifact_path)
    if not paths:
        paths = sorted(phase_dir.glob("unit-*/test-cases.json"))
    if not paths:
        raise IntakeFailure(
            "MISSING_QA_HANDOFF",
            "NEEDS_BASELINE",
            "test-design",
            "no test-cases artifact found for QA handoff",
            ["test-cases"],
        )
    return paths


def assert_design_gap_report(
    path: Path, phase_dir: Path, payload: dict[str, Any]
) -> None:
    design_gap_report = payload.get("design_gap_report")
    gaps = design_gap_report.get("gaps") if isinstance(design_gap_report, dict) else []
    if isinstance(gaps, list):
        blocking = [
            gap.get("gap_id", "<unknown>")
            for gap in gaps
            if isinstance(gap, dict) and gap.get("blocking") is True
        ]
        if blocking:
            raise IntakeFailure(
                "BLOCKING_DESIGN_GAP",
                "NEEDS_BASELINE",
                "design",
                f"test-cases has blocking design gaps: {', '.join(map(str, blocking))}",
                ["test-cases.design_gap_report"],
            )


def qa_handoff_ids(
    path: Path, phase_dir: Path, payload: dict[str, Any]
) -> tuple[list, set[str]]:
    qa_handoff = payload.get("qa_handoff_contract")
    if not isinstance(qa_handoff, list) or not qa_handoff:
        raise IntakeFailure(
            "MISSING_QA_HANDOFF",
            "NEEDS_BASELINE",
            "test-design",
            f"{path.relative_to(phase_dir)} must contain non-empty qa_handoff_contract",
            ["test-cases.qa_handoff_contract"],
        )
    handoff_ids = {
        str(row.get("obligation_id", "")).strip()
        for row in qa_handoff
        if isinstance(row, dict) and str(row.get("obligation_id", "")).strip()
    }
    if len(handoff_ids) != len(qa_handoff):
        raise IntakeFailure(
            "INVALID_QA_HANDOFF",
            "NEEDS_BASELINE",
            "test-design",
            f"{path.relative_to(phase_dir)} qa_handoff_contract must contain unique obligation_id values",
            ["test-cases.qa_handoff_contract.obligation_id"],
        )
    return qa_handoff, handoff_ids


def assert_cross_unit_obligations(
    path: Path,
    phase_dir: Path,
    payload: dict[str, Any],
    handoff_ids: set[str],
) -> None:
    cross_unit_obligations = payload.get("cross_unit_obligations")
    if not isinstance(cross_unit_obligations, list):
        raise IntakeFailure(
            "MISSING_CROSS_UNIT_OBLIGATIONS",
            "NEEDS_BASELINE",
            "test-design",
            f"{path.relative_to(phase_dir)} must contain cross_unit_obligations",
            ["test-cases.cross_unit_obligations"],
        )
    for index, obligation in enumerate(cross_unit_obligations, start=1):
        if not isinstance(obligation, dict):
            raise IntakeFailure(
                "INVALID_CROSS_UNIT_OBLIGATION",
                "NEEDS_BASELINE",
                "test-design",
                f"{path.relative_to(phase_dir)} cross_unit_obligations[{index}] must be an object",
                ["test-cases.cross_unit_obligations"],
            )
        if obligation.get("composition_status") != "COMPOSABLE":
            raise IntakeFailure(
                "CROSS_UNIT_OBLIGATION_NOT_COMPOSABLE",
                "NEEDS_BASELINE",
                "test-design",
                f"{path.relative_to(phase_dir)} cross-unit obligation is not composable",
                ["test-cases.cross_unit_obligations.composition_status"],
            )
        if obligation.get("gap_refs"):
            raise IntakeFailure(
                "CROSS_UNIT_OBLIGATION_GAP",
                "NEEDS_BASELINE",
                "test-design",
                f"{path.relative_to(phase_dir)} cross-unit obligation has unresolved gap_refs",
                ["test-cases.cross_unit_obligations.gap_refs"],
            )
        missing_refs = [
            ref
            for ref in nonempty_strings(obligation.get("handoff_obligation_refs"))
            if ref not in handoff_ids
        ]
        if missing_refs:
            raise IntakeFailure(
                "CROSS_UNIT_OBLIGATION_DRIFT",
                "NEEDS_BASELINE",
                "test-design",
                f"{path.relative_to(phase_dir)} cross-unit obligations reference missing QA handoff ids: {', '.join(missing_refs)}",
                ["test-cases.cross_unit_obligations.handoff_obligation_refs"],
            )


def validate_test_cases(phase_dir: Path, registry: dict[str, Any]) -> int:
    handoff_count = 0
    for path in active_test_case_paths(phase_dir, registry):
        payload = load_json(path, str(path.relative_to(phase_dir)))
        assert_design_gap_report(path, phase_dir, payload)
        qa_handoff, handoff_ids = qa_handoff_ids(path, phase_dir, payload)
        assert_cross_unit_obligations(path, phase_dir, payload, handoff_ids)
        handoff_count += len(qa_handoff)
    return handoff_count
