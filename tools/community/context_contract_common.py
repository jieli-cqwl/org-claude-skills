"""Shared primitives for context contract validation."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import NoReturn

ACTIVE_STATUSES = {"managed", "migrated"}
PHASES = {"bootstrap", "enforce", "cleanup"}
STANDARD_STAGES = {
    "PLANNING",
    "TASK_DISPATCH",
    "TASK_EXECUTION",
    "TASK_VERIFICATION",
    "PHASE_REVIEW",
    "PHASE_QA",
    "SIGNOFF_PENDING",
    "SIGNOFF_RECORDED",
    "CLOSED",
    "BLOCKED",
    "REPLAN_PENDING",
}
WORKLOG_REQUIRED = [
    "actor",
    "context_owner",
    "mode",
    "stage",
    "scope_ref",
    "handoff_status",
    "state_ref",
    "next",
    "next_ref",
]
SUPPORTING_REQUIRED = ["purpose", "serves", "reason_here"]


@dataclass
class ContractFailure(Exception):
    reason: str
    path: str
    expected: str
    actual: str
    next_action: str


def block(
    reason: str, path: Path | str, expected: str, actual: object, next_action: str
) -> NoReturn:
    raise ContractFailure(reason, str(path), expected, str(actual), next_action)


def emit_failure(error: ContractFailure) -> None:
    print("decision: block")
    print(f"reason: {error.reason}")
    print(f"path: {error.path}")
    print(f"expected: {error.expected}")
    print(f"actual: {error.actual}")
    print(f"next_action: {error.next_action}")
