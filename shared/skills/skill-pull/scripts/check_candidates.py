#!/usr/bin/env python3
"""Check upstream candidate refs for managed external Skill sources."""

from __future__ import annotations

from pathlib import Path

from skill_pull_lib import (
    build_arg_parser,
    classify_candidates,
    load_candidate_fixture,
    load_source_locks,
    lookup_candidates,
    managed_locks,
    statuses_to_json,
    write_json,
)


def main() -> None:
    """Run candidate lookup and write structured status JSON."""
    parser = build_arg_parser("Check managed external Skill source candidates.")
    parser.add_argument("--source-lock", help="Path to SOURCES.yaml. Defaults to community/SOURCES.yaml.")
    parser.add_argument("--candidate-fixture", help="JSON fixture used instead of live upstream lookup.")
    parser.add_argument("--output-json", required=True, help="Path for candidate status JSON.")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    lock_path = Path(args.source_lock).resolve() if args.source_lock else repo_root / "community" / "SOURCES.yaml"
    locks = load_source_locks(lock_path)
    if args.candidate_fixture:
        candidates = load_candidate_fixture(Path(args.candidate_fixture))
    else:
        candidates = lookup_candidates(managed_locks(locks))

    statuses = classify_candidates(locks, candidates)
    write_json(
        Path(args.output_json),
        {
            "source_lock": str(lock_path),
            "statuses": statuses_to_json(statuses),
        },
    )


if __name__ == "__main__":
    main()
