#!/usr/bin/env python3
"""Validate projection-manifest provenance and rendered content integrity."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from normalize_canonical_artifact import collect_artifacts, load_scenario


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", type=Path)
    parser.add_argument("--phase-dir", type=Path)
    return parser.parse_args()


def sha256_digest(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    args = parse_args()
    scenario, phase_root = load_scenario(args.fixture, args.phase_dir)
    projection = scenario.get("projection")
    if not isinstance(projection, dict):
        return
    manifest_artifact_id = projection.get("manifest_artifact_id")
    manifest = next(
        (
            artifact
            for artifact in collect_artifacts(scenario)
            if artifact.get("artifact_type") == "projection-manifest"
            and artifact.get("artifact_id") == manifest_artifact_id
        ),
        None,
    )
    if manifest is None:
        raise ValueError("missing projection-manifest artifact")

    available_source_refs = set(projection.get("available_source_refs", []))
    top_level_refs = set(manifest.get("source_artifact_refs", []))
    if top_level_refs - available_source_refs:
        raise ValueError("projection manifest declared unavailable sources")

    section_source_map = manifest.get("section_source_map", {})
    if not section_source_map:
        raise ValueError("missing section_source_map")
    for section_name, row in section_source_map.items():
        row_refs = set(row.get("source_artifact_refs", []))
        if not row_refs:
            raise ValueError(f"section missing source refs: {section_name}")
        if row_refs - top_level_refs:
            raise ValueError(f"section references undeclared sources: {section_name}")
        if not row.get("json_pointers"):
            raise ValueError(f"section missing json_pointers: {section_name}")

    rendered_path = phase_root / projection["rendered_artifact_path"]
    if not rendered_path.is_file():
        raise FileNotFoundError(rendered_path)
    if manifest.get("rendered_content_digest") != sha256_digest(rendered_path):
        raise ValueError("projection digest mismatch")


if __name__ == "__main__":
    main()
