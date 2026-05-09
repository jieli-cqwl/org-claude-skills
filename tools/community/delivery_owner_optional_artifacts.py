#!/usr/bin/env python3
"""Optional delivery-owner readiness artifacts and freshness checks."""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

from normalize_canonical_artifact import load_json

OPTIONAL_PHASE_FILES = ("fix-result.json",)


def collect_optional_validation_artifact_paths(phase_dir: Path) -> list[Path]:
    """Return optional phase artifacts that become mandatory once present."""

    return [
        phase_dir / relative_path
        for relative_path in OPTIONAL_PHASE_FILES
        if (phase_dir / relative_path).is_file()
    ]


def parse_timestamp(value: object, label: str) -> datetime:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"fix-result freshness missing timestamp: {label}")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ValueError(f"fix-result freshness invalid timestamp: {label}") from exc
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def assert_not_before_fix(fix_time: datetime, value: object, label: str) -> None:
    if parse_timestamp(value, label) < fix_time:
        raise ValueError(f"fix-result freshness violation: {label} predates fix-result.produced_at")


def assert_optional_fix_result_freshness(phase_dir: Path) -> None:
    fix_path = phase_dir / "fix-result.json"
    if not fix_path.is_file():
        return

    fix_result = load_json(fix_path)
    delivery_state = load_json(phase_dir / "delivery-state.json")
    signoff = load_json(phase_dir / "signoff-package.json")
    user_decision = load_json(phase_dir / "user-decision.json")

    if fix_result.get("completion_status") != "FIXED":
        raise ValueError("fix-result freshness requires completion_status=FIXED at readiness")
    for field in ("active_tasks_version_ref", "active_tasks_version_ref"):
        if fix_result.get(field) != delivery_state.get(field):
            raise ValueError(f"fix-result freshness requires {field} to match delivery-state")

    fix_time = parse_timestamp(fix_result.get("produced_at"), "fix-result.produced_at")
    assert_not_before_fix(fix_time, signoff.get("produced_at"), "signoff-package.produced_at")
    assert_not_before_fix(fix_time, signoff.get("last_observed_at"), "signoff-package.last_observed_at")
    assert_not_before_fix(fix_time, user_decision.get("produced_at"), "user-decision.produced_at")
