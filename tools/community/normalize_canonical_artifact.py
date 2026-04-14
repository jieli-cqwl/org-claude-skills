#!/usr/bin/env python3
"""Normalize standard-chain validation scenarios without changing business semantics."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

PHASE_SCENARIO_REQUIRED_FEATURE_FILES = [
    "brief.json",
]
PHASE_SCENARIO_REQUIRED_PHASE_JSON_FILES = [
    "phase-prd.json",
]
PHASE_SCENARIO_OPTIONAL_PHASE_JSON_FILES = [
    "artifact-registry.json",
    "code-review-result.json",
    "delivery-state.json",
    "design.json",
    "plan.json",
    "tasks.json",
    "qa-result.json",
    "signoff-package.json",
    "user-decision.json",
    "views/phase-operational.projection-manifest.json",
]
PHASE_SCENARIO_REQUIRED_PHASE_GLOBS = {
    "unit-definition": "units/UNIT-*.json",
}
PHASE_SCENARIO_OPTIONAL_PHASE_GLOBS = {
    "test-cases": "unit-*/test-cases.json",
    "developer-report": "unit-*/tasks/*/developer-report.json",
    "verify-result": "unit-*/tasks/*/verify-result.json",
}
PHASE_SCENARIO_OPTIONAL_PHASE_SUPPORT_FILES = [
    "views/phase-operational.html",
]


def load_json(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path} 顶层必须是对象")
    return data


def dump_json(document: dict) -> None:
    json.dump(document, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")


def resolve_input_path(fixture: Path | None, phase_dir: Path | None) -> Path:
    if fixture is None and phase_dir is None:
        raise ValueError("必须提供 --fixture 或 --phase-dir")
    if fixture is not None and phase_dir is not None:
        raise ValueError("--fixture 与 --phase-dir 只能二选一")
    if fixture is not None:
        return fixture.resolve()
    phase_root = phase_dir.resolve()
    scenario_path = phase_root / "scenario.json"
    if scenario_path.is_file():
        return scenario_path
    return phase_root


def resolve_phase_root(fixture: Path | None, phase_dir: Path | None) -> Path:
    if phase_dir is not None:
        return phase_dir.resolve()
    if fixture is None:
        raise ValueError("缺少 phase root")
    return fixture.resolve().parent


def load_scenario(fixture: Path | None, phase_dir: Path | None) -> tuple[dict, Path]:
    path = resolve_input_path(fixture, phase_dir)
    if phase_dir is not None and path.is_dir():
        return build_phase_scenario_from_dir(path), path
    return load_json(path), resolve_phase_root(fixture, phase_dir)


def assert_file_exists(path: Path) -> None:
    if not path.is_file():
        raise FileNotFoundError(path)


def collect_phase_dir_artifact_paths(phase_dir: Path) -> list[Path]:
    feature_dir = phase_dir.parent
    artifact_paths: list[Path] = []

    for relative_path in PHASE_SCENARIO_REQUIRED_FEATURE_FILES:
        candidate = feature_dir / relative_path
        assert_file_exists(candidate)
        artifact_paths.append(candidate)

    for relative_path in PHASE_SCENARIO_REQUIRED_PHASE_JSON_FILES:
        candidate = phase_dir / relative_path
        assert_file_exists(candidate)
        artifact_paths.append(candidate)

    for relative_path in PHASE_SCENARIO_OPTIONAL_PHASE_JSON_FILES:
        candidate = phase_dir / relative_path
        if candidate.is_file():
            artifact_paths.append(candidate)

    for label, pattern in PHASE_SCENARIO_REQUIRED_PHASE_GLOBS.items():
        matches = sorted(phase_dir.glob(pattern))
        if not matches:
            raise FileNotFoundError(f"{phase_dir / pattern} ({label})")
        artifact_paths.extend(matches)

    for pattern in PHASE_SCENARIO_OPTIONAL_PHASE_GLOBS.values():
        artifact_paths.extend(sorted(phase_dir.glob(pattern)))

    manifest_path = phase_dir / "views/phase-operational.projection-manifest.json"
    if manifest_path.is_file():
        for relative_path in PHASE_SCENARIO_OPTIONAL_PHASE_SUPPORT_FILES:
            assert_file_exists(phase_dir / relative_path)

    return artifact_paths


def build_phase_scenario_from_dir(phase_dir: Path) -> dict:
    phase_root = phase_dir.resolve()
    artifact_paths = collect_phase_dir_artifact_paths(phase_root)
    scenario = {
        "artifacts": [load_json(path) for path in artifact_paths],
    }
    tasks_path = phase_root / "tasks.json"
    if tasks_path.is_file():
        scenario["tasks_registry"] = load_json(tasks_path)
    manifest_path = phase_root / "views/phase-operational.projection-manifest.json"
    if manifest_path.is_file():
        manifest = load_json(manifest_path)
        scenario["projection"] = {
            "manifest_artifact_id": manifest["artifact_id"],
            "rendered_artifact_path": "views/phase-operational.html",
            "available_source_refs": manifest["source_artifact_refs"],
        }
    return scenario


def normalize_artifact(payload: dict) -> dict:
    normalized = dict(payload)
    for key in ("artifact_type", "producer", "authority_scope"):
        if key in normalized:
            normalized[key] = str(normalized[key]).strip()
    return normalized


def normalize_evidence_record(payload: dict) -> dict:
    normalized = dict(payload)
    for key in ("type", "producer", "relation_type", "ref_target", "anchor", "target_path"):
        if key in normalized:
            normalized[key] = str(normalized[key]).strip()
    return normalized


def collect_artifacts(scenario: dict) -> list[dict]:
    artifacts = []
    for artifact in scenario.get("artifacts", []):
        if isinstance(artifact, dict):
            artifacts.append(artifact)
    tasks_registry = scenario.get("tasks_registry")
    if isinstance(tasks_registry, dict):
        artifacts.append(tasks_registry)
    return artifacts


def normalize_scenario(scenario: dict) -> dict:
    normalized = dict(scenario)
    normalized["artifacts"] = [
        normalize_artifact(artifact)
        for artifact in scenario.get("artifacts", [])
        if isinstance(artifact, dict)
    ]
    if isinstance(scenario.get("tasks_registry"), dict):
        normalized["tasks_registry"] = normalize_artifact(scenario["tasks_registry"])
    normalized["evidence_records"] = [
        normalize_evidence_record(record)
        for record in scenario.get("evidence_records", [])
        if isinstance(record, dict)
    ]
    return normalized


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", type=Path)
    parser.add_argument("--phase-dir", type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    scenario, _phase_root = load_scenario(args.fixture, args.phase_dir)
    dump_json(normalize_scenario(scenario))


if __name__ == "__main__":
    main()
