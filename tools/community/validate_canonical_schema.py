#!/usr/bin/env python3
"""Validate canonical artifacts against frozen standard-chain schemas."""

from __future__ import annotations

import argparse
import json
from collections.abc import Iterable
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


def format_json_path(parts: Iterable[object]) -> str:
    """Render a jsonschema path in a compact form operators can act on."""

    path = "$"
    for part in parts:
        if isinstance(part, int):
            path += f"[{part}]"
        else:
            path += f".{part}"
    return path


def format_exception(exc: Exception) -> str:
    """Convert validation failures to one-line diagnostics for hook output."""

    message = getattr(exc, "message", None)
    absolute_path = getattr(exc, "absolute_path", None)
    if message is not None and absolute_path is not None:
        return f"canonical schema validation error at {format_json_path(absolute_path)}: {message}"
    return f"canonical schema validation error: {exc}"


def resolve_artifact_type(normalized: dict, schemas_by_type: dict[str, dict]) -> str:
    """Return the registered artifact type, failing before schema dispatch."""

    artifact_type = normalized.get("artifact_type")
    if not isinstance(artifact_type, str) or not artifact_type.strip():
        raise ValueError("missing required canonical field: artifact_type")
    artifact_type = artifact_type.strip()
    if artifact_type not in schemas_by_type:
        expected = ", ".join(sorted(schemas_by_type))
        raise ValueError(f"unknown artifact type: {artifact_type}; expected one of: {expected}")
    return artifact_type


def validate_artifact_schema(artifact: dict, registry: object, schemas_by_type: dict[str, dict]) -> None:
    normalized = normalize_artifact(artifact)
    artifact_type = resolve_artifact_type(normalized, schemas_by_type)
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
    try:
        main()
    except Exception as exc:
        raise SystemExit(format_exception(exc)) from exc
