#!/usr/bin/env python3
"""Run the standard-chain validator pipeline in fail-closed order."""

from __future__ import annotations

import argparse
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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase-dir", type=Path, required=True)
    return parser.parse_args()


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
    run_phase_validation(args.phase_dir.resolve())


if __name__ == "__main__":
    main()
