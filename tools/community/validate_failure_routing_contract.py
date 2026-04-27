#!/usr/bin/env python3
"""Validate standard-chain failure routing contracts and routing results."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from runtime_yaml import load_yaml
from simple_json_schema import SimpleSchemaValidator, SimpleValidationError


REQUIRED_RESULT_FIELDS = {
    "schema_version",
    "status",
    "stage",
    "failure_code",
    "owner",
    "next_action",
    "safe_to_continue",
    "human_decision_required",
    "continuation_condition",
    "evidence_refs",
    "user_message",
}
REQUIRED_ENTRY_FIELDS = {
    "failure_code",
    "status",
    "default_owner",
    "default_next_action",
    "safe_to_continue",
    "human_decision_required",
    "continuation_condition",
    "message_template",
    "introduced_in",
    "retired_in",
}
STATUS_VALUES = ["PASS", "WARN", "BLOCKED"]
DEFAULT_REGISTRY_REL = "contracts/standard-chain-failure-routing.yaml"
DEFAULT_SCHEMA_REL = "contracts/canonical/schemas/runtime/failure-routing-result.schema.json"
DEFAULT_BUNDLE_REL = "contracts/canonical/registry-bundle.yaml"
DEFAULT_CATALOG_REL = "shared/runtime/standard-chain-failure-routing.json"


class FailureRoutingError(ValueError):
    """Raised when failure routing contracts or results are invalid."""


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument("--registry", type=Path)
    parser.add_argument("--schema", type=Path)
    parser.add_argument("--bundle", type=Path)
    parser.add_argument("--catalog", type=Path)
    parser.add_argument("--result-json")
    parser.add_argument("--emit-unregistered-fallback", action="store_true")
    parser.add_argument("--stage", default="standard-chain.preflight")
    parser.add_argument("--print-registry-summary", action="store_true")
    return parser.parse_args(argv)


def resolve(root: Path, maybe_path: Path | None, default_rel: str) -> Path:
    if maybe_path is None:
        return root / default_rel
    return maybe_path if maybe_path.is_absolute() else root / maybe_path


def load_json(path: Path) -> object:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise FailureRoutingError(f"missing file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise FailureRoutingError(f"invalid JSON: {path}: {exc}") from exc


def schema_version_const(schema: dict) -> str:
    value = schema.get("properties", {}).get("schema_version", {}).get("const")
    if not isinstance(value, str) or not value:
        raise FailureRoutingError("schema must define properties.schema_version.const")
    return value


def entries_by_code(registry: dict) -> dict[str, dict]:
    entries = registry.get("failure_routing", {}).get("entries")
    if not isinstance(entries, list) or not entries:
        raise FailureRoutingError("registry must define non-empty failure_routing.entries")
    result: dict[str, dict] = {}
    for entry in entries:
        if not isinstance(entry, dict):
            raise FailureRoutingError("registry entry must be an object")
        code = entry.get("failure_code")
        if not isinstance(code, str) or not code:
            raise FailureRoutingError("registry entry missing failure_code")
        if code in result:
            raise FailureRoutingError(f"duplicate failure_code: {code}")
        missing = sorted(REQUIRED_ENTRY_FIELDS - set(entry))
        if missing:
            raise FailureRoutingError(f"{code}: missing registry fields {missing}")
        if entry.get("status") not in STATUS_VALUES:
            raise FailureRoutingError(f"{code}: invalid status {entry.get('status')}")
        if entry.get("status") == "WARN" and str(entry.get("continuation_condition")) in {"", "none"}:
            raise FailureRoutingError(f"{code}: WARN requires continuation_condition")
        result[code] = entry
    return result


def load_contracts(args: argparse.Namespace) -> tuple[dict, dict, dict, Path | None]:
    root = args.repo_root.resolve()
    registry_path = resolve(root, args.registry, DEFAULT_REGISTRY_REL)
    schema_path = resolve(root, args.schema, DEFAULT_SCHEMA_REL)
    bundle_path = resolve(root, args.bundle, DEFAULT_BUNDLE_REL)
    catalog_path = resolve(root, args.catalog, DEFAULT_CATALOG_REL)

    if not registry_path.is_file():
        raise FailureRoutingError(f"missing registry: {registry_path}")
    if not schema_path.is_file():
        raise FailureRoutingError(f"missing schema: {schema_path}")
    if not bundle_path.is_file():
        raise FailureRoutingError(f"missing registry bundle: {bundle_path}")

    registry = load_yaml(registry_path)
    schema = load_json(schema_path)
    bundle = load_yaml(bundle_path)
    if not isinstance(registry, dict) or not isinstance(schema, dict) or not isinstance(bundle, dict):
        raise FailureRoutingError("registry, schema, and bundle must be objects")

    return registry, schema, bundle, catalog_path if catalog_path.is_file() or args.catalog else None


def validate_contracts(registry: dict, schema: dict, bundle: dict, catalog_path: Path | None) -> dict[str, dict]:
    expected_registry = DEFAULT_REGISTRY_REL
    expected_schema = DEFAULT_SCHEMA_REL
    routing = registry.get("failure_routing")
    if not isinstance(routing, dict):
        raise FailureRoutingError("registry must define failure_routing object")
    if bundle.get("failure_routing_registry") != expected_registry:
        raise FailureRoutingError("registry-bundle failure_routing_registry points to a non-canonical path")
    if bundle.get("failure_routing_result_schema") != expected_schema:
        raise FailureRoutingError("registry-bundle failure_routing_result_schema points to a non-canonical path")
    if routing.get("result_schema") != expected_schema:
        raise FailureRoutingError("registry result_schema does not point to the canonical schema")
    if routing.get("schema_version") != schema_version_const(schema):
        raise FailureRoutingError("registry schema_version does not match schema schema_version const")

    missing_result_fields = sorted(REQUIRED_RESULT_FIELDS - set(schema.get("required", [])))
    if missing_result_fields:
        raise FailureRoutingError(f"schema missing required fields {missing_result_fields}")
    if schema.get("properties", {}).get("status", {}).get("enum") != STATUS_VALUES:
        raise FailureRoutingError("schema status enum must be exactly PASS/WARN/BLOCKED")

    entries = entries_by_code(registry)
    fallback = entries.get("UNREGISTERED_FAILURE_CODE")
    if not fallback:
        raise FailureRoutingError("UNREGISTERED_FAILURE_CODE is required")
    if fallback.get("status") != "BLOCKED":
        raise FailureRoutingError("UNREGISTERED_FAILURE_CODE must be BLOCKED")
    if fallback.get("default_owner") != "delivery-owner":
        raise FailureRoutingError("UNREGISTERED_FAILURE_CODE owner must be delivery-owner")
    if fallback.get("safe_to_continue") is not False:
        raise FailureRoutingError("UNREGISTERED_FAILURE_CODE must set safe_to_continue false")

    if catalog_path is not None:
        catalog = load_json(catalog_path)
        if not isinstance(catalog, dict):
            raise FailureRoutingError("runtime catalog must be an object")
        catalog_entries = catalog.get("failure_routing", {}).get("entries", [])
        catalog_codes = {item.get("failure_code") for item in catalog_entries if isinstance(item, dict)}
        extra_codes = sorted(catalog_codes - set(entries))
        if extra_codes:
            raise FailureRoutingError(f"runtime catalog contains unregistered codes {extra_codes}")
    return entries


def validate_result(payload: object, schema: dict, entries: dict[str, dict]) -> None:
    if not isinstance(payload, dict):
        raise FailureRoutingError("routing result must be an object")
    schema_id = schema.get("$id")
    if not isinstance(schema_id, str) or not schema_id:
        raise FailureRoutingError("schema must define $id")
    validator = SimpleSchemaValidator({schema_id: schema})
    try:
        validator.validate(payload, schema)
    except SimpleValidationError as exc:
        raise FailureRoutingError(str(exc)) from exc
    code = payload.get("failure_code")
    if code not in entries:
        raise FailureRoutingError(f"unregistered failure_code: {code}")


def unregistered_fallback(entries: dict[str, dict], stage: str, version: str) -> dict:
    entry = entries["UNREGISTERED_FAILURE_CODE"]
    return {
        "schema_version": version,
        "status": "BLOCKED",
        "stage": stage,
        "failure_code": "UNREGISTERED_FAILURE_CODE",
        "owner": entry["default_owner"],
        "next_action": entry["default_next_action"],
        "safe_to_continue": False,
        "human_decision_required": bool(entry["human_decision_required"]),
        "continuation_condition": entry["continuation_condition"] or "none",
        "evidence_refs": ["diagnostic://failure-routing/unregistered-condition"],
        "user_message": entry["message_template"],
    }


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        registry, schema, bundle, catalog_path = load_contracts(args)
        entries = validate_contracts(registry, schema, bundle, catalog_path)
        version = schema_version_const(schema)
        if args.print_registry_summary:
            print(json.dumps({"schema_version": version, "entries_by_code": entries}, ensure_ascii=False, sort_keys=True))
            return 0
        if args.emit_unregistered_fallback:
            print(json.dumps(unregistered_fallback(entries, args.stage, version), ensure_ascii=False, sort_keys=True))
            return 0
        if args.result_json is not None:
            validate_result(json.loads(args.result_json), schema, entries)
        return 0
    except (FailureRoutingError, json.JSONDecodeError) as exc:
        print(f"[FAIL] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
