#!/usr/bin/env python3
"""Validate that optimization-plan fields are consumed by boundaries and commands."""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


def fail(message: str) -> None:
    print(f"[FAIL] {message}", file=sys.stderr)
    raise SystemExit(1)


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def ids_from(entries: Any, key: str) -> set[str]:
    if not isinstance(entries, list):
        fail(f"{key} container must be array")
    return {str(entry.get("finding_id")) for entry in entries if isinstance(entry, dict)}


def main(argv: list[str]) -> None:
    if len(argv) != 2:
        fail("usage: validate_plan_consumption.py <optimization-plan.json>")
    plan = load_json(Path(argv[1]))
    accepted = {str(item) for item in plan.get("accepted_findings", [])}
    if not accepted:
        fail("accepted_findings must not be empty")
    boundary_ids = ids_from(plan.get("file_boundaries"), "file_boundaries")
    contracts = plan.get("verification_contracts")
    if not isinstance(contracts, list):
        fail("verification_contracts container must be array")
    command_ids = ids_from(contracts, "verification_contracts")
    missing_boundary = sorted(accepted - boundary_ids)
    missing_command = sorted(accepted - command_ids)
    if missing_boundary:
        fail(f"accepted findings without file boundaries: {', '.join(missing_boundary)}")
    if missing_command:
        fail(f"accepted findings without verification contracts: {', '.join(missing_command)}")
    allowed_dimensions = {"D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8"}
    for contract in contracts:
        if not isinstance(contract, dict):
            fail("verification contract entries must be objects")
        finding_id = str(contract.get("finding_id", ""))
        dimension = contract.get("dimension")
        if dimension not in allowed_dimensions:
            fail(f"{finding_id} invalid verification dimension")
        for field in ("success_standard_ref", "expected_behavior", "command", "expected_output"):
            value = contract.get(field)
            if not isinstance(value, str) or not value.strip():
                fail(f"{finding_id} missing verification {field}")
        if not str(contract["success_standard_ref"]).startswith(f"{finding_id}:"):
            fail(f"{finding_id} success_standard_ref must bind to finding id")


if __name__ == "__main__":
    main(sys.argv)
