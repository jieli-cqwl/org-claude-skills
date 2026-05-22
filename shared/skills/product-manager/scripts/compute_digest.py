#!/usr/bin/env python3
"""Compute canonical locked_field_digest for Director-owned artifacts.

This script is the authoritative tool for producing the SHA-256 digest that
preflight_check.py verifies. Using jq or other tooling to compute the digest
is error-prone because the canonical form requires exact flags:
  json.dumps(ensure_ascii=False, sort_keys=True, separators=(",", ":"))

Usage:
  compute_digest.py --brief path/to/brief.json
  compute_digest.py --phase-prd path/to/phase-prd.json
  compute_digest.py --brief path/to/brief.json --write   # rewrite digest in-place
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any


def resolve_runtime_root(script_path: Path) -> Path:
    resolved = script_path.resolve()
    candidates = []
    candidates.extend(parent for parent in resolved.parents[:5])
    for value in (
        os.environ.get("CODEX_HOME"),
        os.environ.get("CLAUDE_HOME"),
        str(Path.home() / ".codex"),
        str(Path.home() / ".claude"),
    ):
        if value:
            candidates.append(Path(value))

    for candidate in candidates:
        if (candidate / "tools" / "community" / "validate_product_closure.py").is_file():
            return candidate
    return resolved.parents[4]


RUNTIME_ROOT = resolve_runtime_root(Path(__file__))
sys.path.insert(0, str(RUNTIME_ROOT / "tools" / "community"))

from validate_product_closure import (  # noqa: E402
    DIRECTOR_LOCK_FIELDS,
    snapshot_digest,
)


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse CLI args; requires exactly one of --brief/--phase-prd."""
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--brief", type=Path, help="Path to brief.json")
    source.add_argument("--phase-prd", type=Path, help="Path to phase-prd.json")
    parser.add_argument(
        "--write",
        action="store_true",
        help="Write the computed digest back into the file's director_confirmation.locked_field_digest",
    )
    return parser.parse_args(argv)


def resolve_target(args: argparse.Namespace) -> tuple[Path, str]:
    """Return (file_path, expected artifact_type) based on which flag was provided."""
    if args.brief is not None:
        return args.brief, "brief"
    return args.phase_prd, "phase-prd"


def load_payload(path: Path) -> dict[str, Any]:
    """Read and parse a Director-owned JSON artifact; raise SystemExit on errors."""
    if not path.is_file():
        raise SystemExit(f"file not found: {path}")
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"malformed JSON: {path}: {exc}") from exc
    if not isinstance(payload, dict):
        raise SystemExit(f"top-level JSON must be an object: {path}")
    return payload


def compute(payload: dict[str, Any], artifact_type: str, label: str) -> str:
    """Validate locked_fields schema and return the canonical SHA-256 digest.

    Fails fast (SystemExit) if artifact_type mismatches or locked_fields
    diverges from the Director schema defined in DIRECTOR_LOCK_FIELDS.
    """
    actual_type = payload.get("artifact_type")
    if actual_type != artifact_type:
        raise SystemExit(
            f"{label} artifact_type mismatch: expected={artifact_type!r} actual={actual_type!r}"
        )
    confirmation = payload.get("director_confirmation")
    if not isinstance(confirmation, dict):
        raise SystemExit(f"{label} missing director_confirmation")
    locked_fields = confirmation.get("locked_fields")
    if not isinstance(locked_fields, dict):
        raise SystemExit(
            f"{label} director_confirmation.locked_fields must be an object"
        )

    expected_keys = set(DIRECTOR_LOCK_FIELDS[artifact_type])
    actual_keys = set(locked_fields)
    if actual_keys != expected_keys:
        missing = sorted(expected_keys - actual_keys)
        extra = sorted(actual_keys - expected_keys)
        raise SystemExit(
            f"{label} locked_fields must exactly match Director schema:\n"
            f"  expected = {sorted(expected_keys)}\n"
            f"  missing  = {missing}\n"
            f"  extra    = {extra}"
        )

    return snapshot_digest(locked_fields)


def write_back(path: Path, payload: dict[str, Any], digest: str) -> None:
    """Rewrite the file in place with the freshly-computed digest."""
    payload["director_confirmation"]["locked_field_digest"] = digest
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main(argv: list[str]) -> int:
    """CLI entry: prints the digest; with --write also patches the file."""
    args = parse_args(argv)
    path, artifact_type = resolve_target(args)
    payload = load_payload(path)
    digest = compute(payload, artifact_type, path.name)

    if args.write:
        write_back(path, payload, digest)
        print(f"{digest}  (written to {path})")
    else:
        print(digest)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
