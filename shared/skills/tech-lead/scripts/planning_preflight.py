#!/usr/bin/env python3
"""Validate the canonical inputs required before tech-lead planning."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate tech-lead planning inputs.")
    parser.add_argument(
        "--phase-dir", required=True, help="Path to docs/{feature}/phase-{N}."
    )
    parser.add_argument(
        "--require-tasks",
        action="store_true",
        help="Also require tasks.json for completion gates.",
    )
    return parser.parse_args()


def artifact(name: str, path: Path, owner: str) -> dict[str, str]:
    return {"name": name, "path": str(path), "owner": owner}


def missing(required: list[dict[str, str]]) -> list[dict[str, str]]:
    return [item for item in required if not Path(item["path"]).is_file()]


def has_any(pattern_root: Path, pattern: str) -> bool:
    return any(pattern_root.glob(pattern))


def build_required(phase_dir: Path, require_tasks: bool) -> list[dict[str, str]]:
    feature_dir = phase_dir.parent
    required = [
        artifact("brief.json", feature_dir / "brief.json", "product-director"),
        artifact("phase-prd.json", phase_dir / "phase-prd.json", "product-manager"),
        artifact("design.json", phase_dir / "design.json", "design"),
        artifact(
            "artifact-registry.json",
            phase_dir / "artifact-registry.json",
            "standard-chain",
        ),
    ]
    if require_tasks:
        required.append(
            artifact("tasks.json", phase_dir / "tasks.json", "tech-lead"),
        )
    return required


def build_result(phase_dir: Path, require_tasks: bool) -> dict[str, Any]:
    required = build_required(phase_dir, require_tasks)
    missing_items = missing(required)
    pattern_checks = [
        {
            "name": "UNIT-*.json",
            "path": str(phase_dir / "units"),
            "owner": "product-manager",
            "exists": has_any(phase_dir, "units/UNIT-*.json"),
        },
        {
            "name": "unit-*/test-cases.json",
            "path": str(phase_dir),
            "owner": "test-design",
            "exists": has_any(phase_dir, "unit-*/test-cases.json"),
        },
    ]
    missing_patterns = [
        {"name": item["name"], "path": item["path"], "owner": item["owner"]}
        for item in pattern_checks
        if not item["exists"]
    ]
    gaps = [
        {
            "gap": item["name"],
            "path": item["path"],
            "owner": item["owner"],
            "impact": "planning input is not canonical or not present",
        }
        for item in [*missing_items, *missing_patterns]
    ]
    status = "BLOCKED" if gaps else "READY"
    return {
        "artifact_type": "tech-lead-planning-preflight",
        "schema_version": "1.0.0",
        "phase_dir": str(phase_dir),
        "status": status,
        "required_artifacts": required,
        "required_patterns": pattern_checks,
        "blocking_gaps": gaps,
        "next_action": "continue to WBS planning"
        if status == "READY"
        else "return user decision package",
    }


def main() -> int:
    args = parse_args()
    phase_dir = Path(args.phase_dir).resolve()
    result = build_result(phase_dir, args.require_tasks)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["status"] == "READY" else 2


if __name__ == "__main__":
    sys.exit(main())
