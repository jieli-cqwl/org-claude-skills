#!/usr/bin/env python3
"""Freshness checks for delivery-owner signoff readiness."""

from __future__ import annotations

from datetime import datetime
from pathlib import Path

from normalize_canonical_artifact import load_json


FIXED_EVIDENCE_FILES = (
    ("code-review-result.produced_at", "code-review-result.json"),
    ("qa-result.produced_at", "qa-result.json"),
    ("consistency-audit-result.produced_at", "consistency-audit-result.json"),
)
TASK_EVIDENCE_GLOBS = (
    ("developer-report.produced_at", "unit-*/tasks/*/developer-report.json"),
    ("verify-result.produced_at", "unit-*/tasks/*/verify-result.json"),
)
OPTIONAL_EVIDENCE_FILES = (("fix-result.produced_at", "fix-result.json"),)


def parse_timestamp(value: object, label: str) -> datetime:
    if not isinstance(value, str) or not value:
        raise ValueError(f"signoff freshness missing timestamp: {label}")
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ValueError(f"signoff freshness invalid timestamp: {label}") from exc


def produced_at_for(path: Path, label: str) -> tuple[datetime, str]:
    payload = load_json(path)
    return parse_timestamp(payload.get("produced_at"), label), path.name


def collect_evidence_timestamps(phase_dir: Path) -> list[tuple[datetime, str]]:
    timestamps: list[tuple[datetime, str]] = []
    for label, relative_path in FIXED_EVIDENCE_FILES:
        timestamps.append(produced_at_for(phase_dir / relative_path, label))
    for label, pattern in TASK_EVIDENCE_GLOBS:
        for path in sorted(phase_dir.glob(pattern)):
            timestamps.append(produced_at_for(path, f"{label}:{path.relative_to(phase_dir)}"))
    for label, relative_path in OPTIONAL_EVIDENCE_FILES:
        path = phase_dir / relative_path
        if path.exists():
            timestamps.append(produced_at_for(path, label))
    if not timestamps:
        raise ValueError("signoff freshness requires at least one evidence timestamp")
    return timestamps


def assert_not_before(reference: tuple[datetime, str], value: object, label: str) -> None:
    reference_time, reference_source = reference
    actual_time = parse_timestamp(value, label)
    if actual_time < reference_time:
        raise ValueError(
            "signoff freshness violation: "
            f"{label} predates latest evidence {reference_source}"
        )


def assert_signoff_evidence_freshness(phase_dir: Path) -> None:
    latest_evidence = max(collect_evidence_timestamps(phase_dir), key=lambda item: item[0])
    signoff = load_json(phase_dir / "signoff-package.json")
    decision = load_json(phase_dir / "user-decision.json")

    assert_not_before(latest_evidence, signoff.get("produced_at"), "signoff-package.produced_at")
    assert_not_before(latest_evidence, signoff.get("last_observed_at"), "signoff-package.last_observed_at")
    assert_not_before(latest_evidence, decision.get("produced_at"), "user-decision.produced_at")
    signoff_produced_at = parse_timestamp(signoff.get("produced_at"), "signoff-package.produced_at")
    assert_not_before((signoff_produced_at, "signoff-package.produced_at"), decision.get("produced_at"), "user-decision.produced_at")
