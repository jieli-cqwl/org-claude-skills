#!/usr/bin/env python3
"""Resolve and validate active evidence refs for standard-chain scenarios."""

from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path

from canonical_ref_resolver import split_artifact_ref
from normalize_canonical_artifact import load_scenario

ALLOWED_RELATION_TYPES = {"proves", "observes", "blocks", "traces"}


def parse_timestamp(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def assert_anchor_exists(target_path: Path, anchor: str) -> None:
    text = target_path.read_text(encoding="utf-8")
    if anchor not in text:
        raise ValueError(f"missing anchor: {anchor}")


def assert_evidence_fresh(evidence: dict) -> None:
    if evidence.get("superseded_by_ref"):
        raise ValueError("superseded evidence cannot stay active")
    observed_at = evidence.get("observed_at")
    if not observed_at:
        raise ValueError("missing observed_at for active evidence")
    consumer_produced_at = evidence.get("consumer_produced_at")
    if consumer_produced_at and parse_timestamp(observed_at) > parse_timestamp(consumer_produced_at):
        raise ValueError("evidence observed after consumer artifact was produced")
    signoff_produced_at = evidence.get("signoff_produced_at")
    if signoff_produced_at and parse_timestamp(observed_at) < parse_timestamp(signoff_produced_at):
        raise ValueError("stale signoff evidence")
    valid_until = evidence.get("valid_until")
    if valid_until and consumer_produced_at and parse_timestamp(valid_until) < parse_timestamp(consumer_produced_at):
        raise ValueError("stale evidence")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", type=Path)
    parser.add_argument("--phase-dir", type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    scenario, phase_root = load_scenario(args.fixture, args.phase_dir)
    for evidence in scenario.get("evidence_records", []):
        split_artifact_ref(evidence["ref_target"])
        if evidence.get("relation_type") not in ALLOWED_RELATION_TYPES:
            raise ValueError(f"illegal relation_type: {evidence.get('relation_type')}")
        target_path = phase_root / evidence["target_path"]
        if not target_path.is_file():
            raise FileNotFoundError(target_path)
        assert_anchor_exists(target_path, evidence["anchor"])
        assert_evidence_fresh(evidence)


if __name__ == "__main__":
    main()
