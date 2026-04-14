#!/usr/bin/env python3
"""Normalize standard-chain validation scenarios without changing business semantics."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


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
    return (phase_dir.resolve() / "scenario.json")


def resolve_phase_root(fixture: Path | None, phase_dir: Path | None) -> Path:
    if phase_dir is not None:
        return phase_dir.resolve()
    if fixture is None:
        raise ValueError("缺少 phase root")
    return fixture.resolve().parent


def load_scenario(fixture: Path | None, phase_dir: Path | None) -> tuple[dict, Path]:
    path = resolve_input_path(fixture, phase_dir)
    return load_json(path), resolve_phase_root(fixture, phase_dir)


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
