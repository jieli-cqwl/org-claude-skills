#!/usr/bin/env python3
"""Validate the shape of a skill-optimizer runtime artifact."""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


TYPE_MAP = {
    "array": list,
    "object": dict,
    "string": str,
    "number": (int, float),
    "boolean": bool,
}


def fail(message: str) -> None:
    print(f"[FAIL] {message}", file=sys.stderr)
    raise SystemExit(1)


def load_json(path: Path) -> dict[str, Any]:
    try:
        with path.open(encoding="utf-8") as handle:
            data = json.load(handle)
    except FileNotFoundError:
        fail(f"file not found: {path}")
    except json.JSONDecodeError as exc:
        fail(f"invalid JSON in {path}: {exc}")
    if not isinstance(data, dict):
        fail(f"top-level JSON must be object: {path}")
    return data


def type_matches(value: Any, expected_type: str) -> bool:
    """Check JSON type semantics without bool leaking into number."""
    if expected_type == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    python_type = TYPE_MAP.get(expected_type)
    if python_type is None:
        fail(f"unsupported schema type: {expected_type}")
    return isinstance(value, python_type)


def validate_value(path: str, rules: dict[str, Any], value: Any) -> None:
    """Validate one value with the supported local schema subset."""
    expected_type = rules.get("type")
    if expected_type and not type_matches(value, expected_type):
        fail(f"field {path} must be {expected_type}")
    if "const" in rules and value != rules["const"]:
        fail(f"field {path} must equal {rules['const']}")
    if "enum" in rules and value not in rules["enum"]:
        fail(f"field {path} has invalid value: {value}")

    if isinstance(value, dict):
        required = rules.get("required", [])
        if not isinstance(required, list):
            fail(f"field {path} required must be array")
        for field in required:
            if field not in value:
                fail(f"missing required field: {path}.{field}")
        properties = rules.get("properties", {})
        if properties and not isinstance(properties, dict):
            fail(f"field {path} properties must be object")
        for field, nested_rules in properties.items():
            if field in value:
                validate_value(f"{path}.{field}", nested_rules, value[field])

    if isinstance(value, list):
        min_items = rules.get("minItems")
        if min_items is not None and len(value) < int(min_items):
            fail(f"field {path} must contain at least {min_items} items")
        item_rules = rules.get("items")
        if item_rules is not None:
            if not isinstance(item_rules, dict):
                fail(f"field {path} items must be object")
            for index, item in enumerate(value):
                validate_value(f"{path}[{index}]", item_rules, item)


def validate(schema: dict[str, Any], artifact: dict[str, Any]) -> None:
    validate_value("$", {**schema, "type": "object"}, artifact)


def main(argv: list[str]) -> None:
    if len(argv) != 3:
        fail("usage: validate_schema.py <schema.json> <artifact.json>")
    schema = load_json(Path(argv[1]))
    artifact = load_json(Path(argv[2]))
    validate(schema, artifact)


if __name__ == "__main__":
    main(sys.argv)
