#!/usr/bin/env python3
"""Run the standard-chain validator pipeline in fail-closed order."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

PIPELINE = [
    "normalize_canonical_artifact.py",
    "validate_canonical_schema.py",
    "validate_canonical_rules.py",
    "resolve_evidence_refs.py",
    "validate_projection_manifest.py",
]

LEGACY_CANONICAL_ONLY_PATHS = [
    "brief.md",
    "prd.md",
    "design.md",
    "plan.md",
    "tasks.md",
    "qa-report.md",
    "code-review-report.md",
    "acceptance-summary.md",
    "waivers.md",
]
LEGACY_CANONICAL_ONLY_GLOBS = [
    "unit-*/test-cases.md",
    "unit-*/dev-report.md",
    "unit-*/tasks/*/developer-report-Task-*.md",
]
REQUIRED_CATALOG_DEFAULT_PATHS = {
    "brief": "docs/{feature}/brief.json",
    "phase-prd": "docs/{feature}/phase-{N}/phase-prd.json",
    "unit-definition": "docs/{feature}/phase-{N}/units/UNIT-{N}.json",
    "design": "docs/{feature}/phase-{N}/design.json",
    "test-cases": "docs/{feature}/phase-{N}/unit-{N}/test-cases.json",
    "plan": "docs/{feature}/phase-{N}/plan.json",
    "tasks": "docs/{feature}/phase-{N}/tasks.json",
    "developer-report": "docs/{feature}/phase-{N}/unit-{N}/tasks/{task_id}/developer-report.json",
    "verify-result": "docs/{feature}/phase-{N}/unit-{N}/tasks/{task_id}/verify-result.json",
    "code-review-result": "docs/{feature}/phase-{N}/code-review-result.json",
    "qa-result": "docs/{feature}/phase-{N}/qa-result.json",
    "delivery-state": "docs/{feature}/phase-{N}/delivery-state.json",
    "signoff-package": "docs/{feature}/phase-{N}/signoff-package.json",
    "user-decision": "docs/{feature}/phase-{N}/user-decision.json",
    "artifact-registry": "docs/{feature}/phase-{N}/artifact-registry.json",
    "projection-manifest": "docs/{feature}/phase-{N}/views/phase-operational.projection-manifest.json",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase-dir", type=Path, required=True)
    parser.add_argument("--catalog", type=Path)
    parser.add_argument("--enforce-canonical-only", action="store_true")
    return parser.parse_args()


def assert_canonical_only_layout(phase_dir: Path) -> None:
    feature_dir = phase_dir.parent
    for relative_path in LEGACY_CANONICAL_ONLY_PATHS:
        candidate = feature_dir / relative_path if relative_path == "brief.md" else phase_dir / relative_path
        if candidate.exists():
            raise FileExistsError(f"canonical-only phase must not keep legacy runtime source: {candidate}")
    for pattern in LEGACY_CANONICAL_ONLY_GLOBS:
        matches = sorted(phase_dir.glob(pattern))
        if matches:
            raise FileExistsError(
                f"canonical-only phase must not keep legacy runtime source: {matches[0]}"
            )


def assert_catalog_contract(catalog_path: Path) -> None:
    payload = json.loads(catalog_path.read_text(encoding="utf-8"))
    artifacts = payload.get("artifacts")
    if not isinstance(artifacts, dict):
        raise ValueError("standard-chain catalog missing artifacts map")
    for artifact_type, default_path in REQUIRED_CATALOG_DEFAULT_PATHS.items():
        entry = artifacts.get(artifact_type)
        if not isinstance(entry, dict):
            raise ValueError(f"standard-chain catalog missing artifact: {artifact_type}")
        if entry.get("default_path") != default_path:
            raise ValueError(
                f"standard-chain catalog drift for {artifact_type}: "
                f"{entry.get('default_path')} != {default_path}"
            )


def run_phase_validation(phase_dir: Path) -> None:
    tools_dir = Path(__file__).resolve().parent
    for script_name in PIPELINE:
        script = tools_dir / script_name
        if not script.is_file():
            raise FileNotFoundError(script_name)
        subprocess.run(
            [sys.executable, str(script), "--phase-dir", str(phase_dir)],
            check=True,
        )


def main() -> None:
    args = parse_args()
    phase_dir = args.phase_dir.resolve()
    if args.catalog is not None:
        assert_catalog_contract(args.catalog.resolve())
    if args.enforce_canonical_only or args.phase_dir is not None:
        assert_canonical_only_layout(phase_dir)
    run_phase_validation(phase_dir)


if __name__ == "__main__":
    main()
