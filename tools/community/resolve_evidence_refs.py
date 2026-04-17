#!/usr/bin/env python3
"""Resolve and validate active evidence refs for standard-chain scenarios."""

from __future__ import annotations

import argparse
import re
from datetime import datetime
from pathlib import Path

from canonical_ref_resolver import get_active_revision, split_artifact_ref
from normalize_canonical_artifact import collect_artifacts, load_scenario

ALLOWED_RELATION_TYPES = {"proves", "observes", "blocks", "traces"}


def parse_timestamp(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def assert_anchor_exists(target_path: Path, anchor: str) -> None:
    text = target_path.read_text(encoding="utf-8")
    pattern = rf"(?<![A-Za-z0-9_-]){re.escape(anchor)}(?![A-Za-z0-9_-])"
    if not re.search(pattern, text):
        raise ValueError(f"missing anchor: {anchor}")


def artifact_matches_ref(artifact: dict, artifact_type: str, artifact_id: str) -> bool:
    return artifact.get("artifact_type") == artifact_type and artifact.get("artifact_id") == artifact_id


def assert_registry_ref_active(registry: dict, artifact_type: str, artifact_id: str, version: str) -> bool:
    for entry in get_active_revision(registry).get("entries", []):
        if (
            entry.get("artifact_type") == artifact_type
            and entry.get("artifact_id") == artifact_id
            and entry.get("version") == version
        ):
            if entry.get("active_for_consumption") is not True:
                raise ValueError(f"ref_target is not active: {artifact_id}@{version}")
            if entry.get("lifecycle_state") != "FINALIZED":
                raise ValueError(f"ref_target is not finalized: {artifact_id}@{version}")
            return True
    return False


def assert_ref_target_resolves(scenario: dict, evidence: dict) -> None:
    ref_target = evidence["ref_target"]
    artifact_type, artifact_id, version, anchor = split_artifact_ref(ref_target)
    if evidence.get("anchor") != anchor:
        raise ValueError("evidence anchor must match ref_target anchor")
    artifacts = collect_artifacts(scenario)
    registries = [artifact for artifact in artifacts if artifact.get("artifact_type") == "artifact-registry"]
    if any(assert_registry_ref_active(registry, artifact_type, artifact_id, version) for registry in registries):
        return
    if registries:
        raise FileNotFoundError(ref_target)
    if any(artifact_matches_ref(artifact, artifact_type, artifact_id) for artifact in artifacts):
        return
    raise FileNotFoundError(ref_target)


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
        assert_ref_target_resolves(scenario, evidence)
        if evidence.get("relation_type") not in ALLOWED_RELATION_TYPES:
            raise ValueError(f"illegal relation_type: {evidence.get('relation_type')}")
        target_path = phase_root / evidence["target_path"]
        if not target_path.is_file():
            raise FileNotFoundError(target_path)
        assert_anchor_exists(target_path, evidence["anchor"])
        assert_evidence_fresh(evidence)


if __name__ == "__main__":
    main()
