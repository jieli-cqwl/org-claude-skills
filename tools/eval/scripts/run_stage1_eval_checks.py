#!/usr/bin/env python3
"""Run the Stage 1 deterministic eval gate."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[3]


@dataclass(frozen=True)
class EvalCheck:
    key: str
    script: str


CHECKS = [
    EvalCheck("dry_run_graders", "tools/eval/scripts/run_stage1_dry_run_graders.py"),
    EvalCheck("resume_chain", "tools/eval/scripts/grade_e2e_resume001_chain.py"),
    EvalCheck("artifact_structure_contracts", "tools/eval/scripts/validate_stage1_artifact_contracts.py"),
    EvalCheck("stage2_intake_gate", "tools/eval/scripts/validate_stage2_intake_gate.py"),
    EvalCheck("stage2_product_director_handoff", "tools/eval/scripts/validate_stage2_product_director_handoff_materials.py"),
    EvalCheck("stage2_confirmed_brief_package", "tools/eval/scripts/validate_stage2_confirmed_brief_materials.py"),
    EvalCheck("stage2_product_manager_package", "tools/eval/scripts/validate_stage2_product_manager_materials.py"),
    EvalCheck("stage2_design_package", "tools/eval/scripts/validate_stage2_design_materials.py"),
    EvalCheck("stage2_test_design_package", "tools/eval/scripts/validate_stage2_test_design_materials.py"),
    EvalCheck("stage2_tech_lead_package", "tools/eval/scripts/validate_stage2_tech_lead_materials.py"),
]


def run_check(check: EvalCheck, repo_root: Path) -> dict[str, Any]:
    script = repo_root / check.script
    if not script.is_file():
        return {
            "check": check.key,
            "status": "fail",
            "exit_code": 127,
            "error": f"missing script: {check.script}",
        }
    completed = subprocess.run(
        [sys.executable, str(script), "--repo-root", str(repo_root)],
        cwd=repo_root,
        text=True,
        capture_output=True,
        check=False,
    )
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError as exc:
        return {
            "check": check.key,
            "status": "fail",
            "exit_code": completed.returncode,
            "error": f"non-json output: {exc}",
            "stdout": completed.stdout,
            "stderr": completed.stderr,
        }

    return {
        "check": check.key,
        "status": "pass" if completed.returncode == 0 and payload.get("status") == "pass" else "fail",
        "exit_code": completed.returncode,
        "payload": payload,
        **({"stderr": completed.stderr} if completed.stderr else {}),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=ROOT, help="Repository root.")
    args = parser.parse_args()

    repo_root = args.repo_root.resolve()
    results = [run_check(check, repo_root) for check in CHECKS]
    failed_checks = [result["check"] for result in results if result.get("status") != "pass"]
    summary = {
        "status": "fail" if failed_checks else "pass",
        "failed_checks": failed_checks,
        "checks": results,
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2, sort_keys=True))
    return 1 if failed_checks else 0


if __name__ == "__main__":
    raise SystemExit(main())
