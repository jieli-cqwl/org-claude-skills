#!/usr/bin/env python3
"""Compute or verify the PM owner self-checked review bundle digest."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path


def resolve_runtime_root(script_path: Path) -> Path:
    resolved = script_path.resolve()
    candidates = [
        *list(resolved.parents)[:5],
        Path.home() / ".codex",
        Path(os.environ.get("CODEX_HOME", Path.home() / ".codex")),
        Path.home() / ".claude",
        Path(os.environ.get("CLAUDE_HOME", Path.home() / ".claude")),
    ]

    for candidate in candidates:
        if (candidate / "tools" / "community" / "review_digest_common.py").is_file():
            return candidate
    return resolved.parents[4]


ROOT = resolve_runtime_root(Path(__file__))
sys.path.insert(0, str(ROOT / "tools" / "community"))

from normalize_canonical_artifact import load_json  # noqa: E402
from review_digest_common import canonical_bundle_digest  # noqa: E402


POST_REVIEW_FIELDS = {"review_conclusion", "issue_ledger", "delivery_confirmation"}


def phase_dir_refs(phase_dir: Path) -> list[str]:
    feature_dir = phase_dir.parent
    unit_refs = sorted(
        str(path.relative_to(feature_dir))
        for path in (phase_dir / "units").glob("UNIT-*.json")
    )
    refs = ["brief.json", str(phase_dir.relative_to(feature_dir) / "phase-prd.json")]
    refs.extend(unit_refs)
    if len(refs) < 3:
        raise ValueError("review bundle must include brief, phase-prd, and UNIT refs")
    return refs


def digest_for_phase(phase_dir: Path) -> tuple[list[str], str]:
    refs = phase_dir_refs(phase_dir)
    digest = canonical_bundle_digest(phase_dir.parent, refs, POST_REVIEW_FIELDS)
    return refs, digest


def check_artifact(artifact: Path, digest: str) -> None:
    payload = load_json(artifact)
    team = payload.get("review_conclusion", {}).get("agent_team_review")
    if not isinstance(team, dict):
        raise ValueError(f"{artifact} missing review_conclusion.agent_team_review")
    actual = team.get("reviewed_bundle_digest")
    if actual != digest:
        raise ValueError(
            f"{artifact} reviewed_bundle_digest mismatch: expected={digest} actual={actual!r}"
        )
    for index, reviewer in enumerate(team.get("reviewer_verdicts", [])):
        if reviewer.get("reviewed_bundle_digest") != digest:
            raise ValueError(
                f"{artifact} reviewer_verdicts[{index}].reviewed_bundle_digest mismatch"
            )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase-dir", type=Path, required=True)
    parser.add_argument("--check-artifact", type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    refs, digest = digest_for_phase(args.phase_dir.resolve())
    if args.check_artifact:
        check_artifact(args.check_artifact.resolve(), digest)
    print(
        json.dumps(
            {"reviewed_artifact_refs": refs, "reviewed_bundle_digest": digest}, indent=2
        )
    )


if __name__ == "__main__":
    try:
        main()
    except (FileNotFoundError, ValueError) as exc:
        raise SystemExit(str(exc)) from exc
