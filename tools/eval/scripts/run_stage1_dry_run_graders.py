#!/usr/bin/env python3
"""Run deterministic graders for Stage 1 standard-chain dry-run artifacts."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class GraderCase:
    key: str
    script: str
    input_path: str
    output_path: str
    evaluator_path: str


CASES = [
    GraderCase(
        key="td-002",
        script="tools/eval/scripts/grade_td002_dry_run.py",
        input_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/td-002/input.md",
        output_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/td-002/test-design/output.md",
        evaluator_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/td-002/test-design/evaluator-output.md",
    ),
    GraderCase(
        key="tl-002",
        script="tools/eval/scripts/grade_tl002_dry_run.py",
        input_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/tl-002/input.md",
        output_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/tl-002/tech-lead/output.md",
        evaluator_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/tl-002/tech-lead/evaluator-output.md",
    ),
    GraderCase(
        key="do-002",
        script="tools/eval/scripts/grade_do002_dry_run.py",
        input_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/do-002/input.md",
        output_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/do-002/delivery-owner/output.md",
        evaluator_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/do-002/delivery-owner/evaluator-output.md",
    ),
    GraderCase(
        key="pd-003",
        script="tools/eval/scripts/grade_pd003_dry_run.py",
        input_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/pd-003/input.md",
        output_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/pd-003/product-director/output.md",
        evaluator_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/pd-003/product-director/evaluator-output.md",
    ),
    GraderCase(
        key="pm-003",
        script="tools/eval/scripts/grade_pm003_dry_run.py",
        input_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/pm-003/input.md",
        output_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/pm-003/product-manager/output.md",
        evaluator_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/pm-003/product-manager/evaluator-output.md",
    ),
    GraderCase(
        key="des-003",
        script="tools/eval/scripts/grade_des003_dry_run.py",
        input_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/des-003/input.md",
        output_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/des-003/design/output.md",
        evaluator_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/des-003/design/evaluator-output.md",
    ),
    GraderCase(
        key="td-003",
        script="tools/eval/scripts/grade_td003_dry_run.py",
        input_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/td-003/input.md",
        output_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/td-003/test-design/output.md",
        evaluator_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/td-003/test-design/evaluator-output.md",
    ),
    GraderCase(
        key="tl-003",
        script="tools/eval/scripts/grade_tl003_dry_run.py",
        input_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/tl-003/input.md",
        output_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/tl-003/tech-lead/output.md",
        evaluator_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/tl-003/tech-lead/evaluator-output.md",
    ),
    GraderCase(
        key="do-003",
        script="tools/eval/scripts/grade_do003_dry_run.py",
        input_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/do-003/input.md",
        output_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/do-003/delivery-owner/output.md",
        evaluator_path="tests/fixtures/stage1-agent-delivery-operating-system/dry-runs/do-003/delivery-owner/evaluator-output.md",
    ),
]


def repo_root_from_script() -> Path:
    return Path(__file__).resolve().parents[3]


def case_by_key(key: str) -> GraderCase:
    for case in CASES:
        if case.key == key:
            return case
    valid = ", ".join(case.key for case in CASES)
    raise SystemExit(f"unknown case: {key}; valid cases: {valid}")


def require_file(path: Path) -> None:
    if not path.is_file():
        raise SystemExit(f"missing required file: {path}")


def run_case(case: GraderCase, repo_root: Path) -> dict:
    script = repo_root / case.script
    input_path = repo_root / case.input_path
    output_path = repo_root / case.output_path
    evaluator_path = repo_root / case.evaluator_path
    for path in [script, input_path, output_path, evaluator_path]:
        require_file(path)

    completed = subprocess.run(
        [
            sys.executable,
            str(script),
            "--input",
            str(input_path),
            "--output",
            str(output_path),
            "--evaluator",
            str(evaluator_path),
        ],
        cwd=repo_root,
        text=True,
        capture_output=True,
        check=False,
    )
    try:
        payload = json.loads(completed.stdout)
    except json.JSONDecodeError as exc:
        raise SystemExit(
            f"{case.key} grader did not return JSON: exit={completed.returncode}, stdout={completed.stdout!r}, stderr={completed.stderr!r}"
        ) from exc
    payload["case_key"] = case.key
    payload["exit_code"] = completed.returncode
    if completed.stderr:
        payload["stderr"] = completed.stderr
    return payload


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", action="append", dest="case_keys", help="Run one case key. May be repeated.")
    parser.add_argument("--list-cases", action="store_true", help="List supported case keys and exit.")
    parser.add_argument("--repo-root", type=Path, default=repo_root_from_script(), help="Repository root.")
    args = parser.parse_args()

    if args.list_cases:
        for case in CASES:
            print(case.key)
        return 0

    selected = [case_by_key(key) for key in args.case_keys] if args.case_keys else CASES
    repo_root = args.repo_root.resolve()
    results = [run_case(case, repo_root) for case in selected]
    failed = [result["case_key"] for result in results if result.get("status") != "pass" or result.get("exit_code") != 0]
    summary = {
        "status": "fail" if failed else "pass",
        "failed_cases": failed,
        "cases": results,
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
