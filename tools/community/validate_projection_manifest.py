#!/usr/bin/env python3
"""Validate projection-manifest provenance and rendered content integrity."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from normalize_canonical_artifact import ROOT, collect_artifacts, load_json, load_scenario


def infer_feature_phase(phase_dir: Path) -> tuple[str, str]:
    phase_name = phase_dir.name
    feature_name = phase_dir.parent.name
    if not phase_name.startswith("phase-"):
        raise ValueError(f"无法从目录推断 phase: {phase_dir}")
    return feature_name, phase_name.removeprefix("phase-")


def resolve_config_value(value: str, feature: str, phase_number: str) -> str:
    return value.replace("{feature}", feature).replace("{N}", phase_number)


def expected_manifest_sources(phase_root: Path, manifest: dict, views_path: Path) -> tuple[set[str], dict[str, dict]] | None:
    try:
        feature, phase_number = infer_feature_phase(phase_root)
    except ValueError:
        return None
    views = load_json(views_path.resolve())["views"]
    view = next(item for item in views if item["view_id"] == manifest["view_id"])
    section_source_map: dict[str, dict] = {}
    for section_id in view["required_sections"]:
        section = view["section_sources"][section_id]
        section_source_map[section_id] = {
            "source_artifact_refs": [
                resolve_config_value(ref, feature, phase_number)
                for ref in section["source_artifact_refs"]
            ],
            "json_pointers": section["json_pointers"],
        }
    source_refs = {
        ref
        for section in section_source_map.values()
        for ref in section["source_artifact_refs"]
    }
    return source_refs, section_source_map


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", type=Path)
    parser.add_argument("--phase-dir", type=Path)
    parser.add_argument(
        "--views",
        type=Path,
        default=ROOT / "shared/runtime/projection-views.json",
    )
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
    expected_sources = expected_manifest_sources(phase_root, manifest, args.views)
    if expected_sources is not None:
        expected_top_level_refs, expected_section_source_map = expected_sources
        if top_level_refs != expected_top_level_refs:
            raise ValueError("projection source refs drift from configured view")
        if section_source_map != expected_section_source_map:
            raise ValueError("projection section_source_map drift from configured view")
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
