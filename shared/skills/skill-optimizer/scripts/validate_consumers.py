#!/usr/bin/env python3
"""Validate that runtime artifact fields have declared consumers."""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


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


def validate(consumers: dict[str, Any], artifact: dict[str, Any]) -> None:
    fields = consumers.get("fields")
    if not isinstance(fields, dict) or not fields:
        fail("consumer matrix must define fields")
    missing = sorted(field for field in artifact if field not in fields)
    if missing:
        fail(f"runtime fields lack consumers: {', '.join(missing)}")
    empty = sorted(
        field
        for field, details in fields.items()
        if not isinstance(details, dict) or not details.get("consumers")
    )
    if empty:
        fail(f"consumer matrix has empty consumers: {', '.join(empty)}")


def main(argv: list[str]) -> None:
    if len(argv) != 3:
        fail("usage: validate_consumers.py <field-consumers.json> <artifact.json>")
    validate(load_json(Path(argv[1])), load_json(Path(argv[2])))


if __name__ == "__main__":
    main(sys.argv)
