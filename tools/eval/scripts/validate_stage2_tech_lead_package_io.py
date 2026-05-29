from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[3]


def first_output_line(completed: subprocess.CompletedProcess[str]) -> str:
    detail = (
        completed.stderr or completed.stdout or f"exit={completed.returncode}"
    ).strip()
    return next((line for line in detail.splitlines() if line.strip()), detail)


def run_command(args: list[str]) -> str | None:
    completed = subprocess.run(
        args, cwd=ROOT, text=True, capture_output=True, check=False
    )
    if completed.returncode == 0:
        return None
    return first_output_line(completed)


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def write_package_files(package: dict[str, Any], root: Path) -> Path:
    test_design_package = package["test_design_package"]
    design_package = test_design_package["design_package"]
    pm_package = design_package["product_manager_package"]
    feature_dir = root / "docs" / "stage2-feature"
    phase_dir = feature_dir / "phase-1"
    units_dir = phase_dir / "units"
    unit_work_dir = phase_dir / "unit-1"
    units_dir.mkdir(parents=True, exist_ok=True)
    unit_work_dir.mkdir(parents=True, exist_ok=True)
    write_json(feature_dir / "brief.json", pm_package["brief"])
    write_json(phase_dir / "phase-prd.json", pm_package["phase_prd"])
    for unit in pm_package.get("units", []):
        if isinstance(unit, dict) and isinstance(unit.get("unit_id"), str):
            write_json(units_dir / f"{unit['unit_id']}.json", unit)
    write_json(phase_dir / "design.json", design_package["design"])
    write_json(unit_work_dir / "test-cases.json", test_design_package["test_cases"])
    write_json(phase_dir / "plan.json", package["plan"])
    write_json(phase_dir / "tasks.json", package["tasks"])
    write_json(phase_dir / "artifact-registry.json", package["artifact_registry"])
    return phase_dir


def planning_preflight_failure(phase_dir: Path) -> str | None:
    return run_command(
        [
            sys.executable,
            str(ROOT / "shared/skills/tech-lead/scripts/planning_preflight.py"),
            "--phase-dir",
            str(phase_dir),
            "--require-tasks",
        ]
    )


def semantic_integrity_failure(phase_dir: Path) -> str | None:
    return run_command(
        [
            sys.executable,
            str(ROOT / "tools/community/validate_standard_chain_phase.py"),
            "--phase-dir",
            str(phase_dir),
        ]
    )


def delivery_owner_intake_failure(phase_dir: Path) -> str | None:
    return run_command(
        [
            "bash",
            str(
                ROOT / "shared/skills/delivery-owner/scripts/intake_preflight_check.sh"
            ),
            "--phase-dir",
            str(phase_dir),
        ]
    )
