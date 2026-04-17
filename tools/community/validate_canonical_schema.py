#!/usr/bin/env python3
"""Validate canonical artifacts against frozen standard-chain schemas."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from normalize_canonical_artifact import ROOT, collect_artifacts, load_json, load_scenario, normalize_artifact
from simple_json_schema import SimpleSchemaValidator

try:
    from jsonschema import Draft202012Validator, FormatChecker
    from referencing import Registry, Resource
except ModuleNotFoundError:
    Draft202012Validator = None
    FormatChecker = None
    Registry = None
    Resource = None


def load_catalog() -> dict:
    return load_json(ROOT / "shared/runtime/standard-chain-catalog.json")


def build_schema_registry() -> tuple[object, dict[str, dict]]:
    registry: object = Registry() if Registry is not None else {}
    schemas_by_type: dict[str, dict] = {}
    shared_core = load_json(ROOT / "contracts/canonical/schemas/shared-core.schema.json")
    if Registry is None or Resource is None:
        registry[shared_core["$id"]] = shared_core
    else:
        registry = registry.with_resource(shared_core["$id"], Resource.from_contents(shared_core))
    catalog = load_catalog()
    for entry in catalog.get("artifacts", {}).values():
        schema_path = ROOT / entry["schema_path"]
        schema = load_json(schema_path)
        if Registry is None or Resource is None:
            registry[schema["$id"]] = schema
        else:
            registry = registry.with_resource(schema["$id"], Resource.from_contents(schema))
        schemas_by_type[entry["artifact_type"]] = schema
    return registry, schemas_by_type


def validate_artifact_schema(artifact: dict, registry: object, schemas_by_type: dict[str, dict]) -> None:
    normalized = normalize_artifact(artifact)
    artifact_type = normalized.get("artifact_type")
    if artifact_type not in schemas_by_type:
        raise ValueError(f"unknown artifact type: {artifact_type}")
    if Draft202012Validator is None:
        if not isinstance(registry, dict):
            raise ValueError("schema registry fallback must be a dict")
        SimpleSchemaValidator(registry).validate(normalized, schemas_by_type[artifact_type])
        return
    validator = Draft202012Validator(
        schemas_by_type[artifact_type],
        registry=registry,
        format_checker=FormatChecker(),
    )
    validator.validate(normalized)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", type=Path)
    parser.add_argument("--phase-dir", type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    scenario, _phase_root = load_scenario(args.fixture, args.phase_dir)
    registry, schemas_by_type = build_schema_registry()
    for artifact in collect_artifacts(scenario):
        validate_artifact_schema(artifact, registry, schemas_by_type)


if __name__ == "__main__":
    main()
