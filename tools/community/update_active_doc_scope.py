#!/usr/bin/env python3
"""Controlled updates for active context scope registry lifecycle fields."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from runtime_yaml import load_yaml


PHASES = {"bootstrap", "enforce", "cleanup"}


def fail(message: str) -> None:
    print(f"FATAL: {message}", file=sys.stderr)
    raise SystemExit(1)


def scalar(value: object) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "null"
    text = str(value)
    if not text:
        return '""'
    if any(ch in text for ch in [":", "#", "[", "]", "{", "}", ","]) or text.strip() != text:
        return '"' + text.replace('"', '\\"') + '"'
    return text


def dump_yaml_value(value: object, indent: int = 0) -> list[str]:
    pad = " " * indent
    if isinstance(value, dict):
        lines: list[str] = []
        for key, item in value.items():
            if isinstance(item, list) and all(not isinstance(row, (dict, list)) for row in item):
                lines.append(f"{pad}{key}: [{', '.join(scalar(row) for row in item)}]")
            elif isinstance(item, (dict, list)):
                lines.append(f"{pad}{key}:")
                lines.extend(dump_yaml_value(item, indent + 2))
            else:
                lines.append(f"{pad}{key}: {scalar(item)}")
        return lines
    if isinstance(value, list):
        lines = []
        for item in value:
            if isinstance(item, dict):
                first = True
                for key, nested in item.items():
                    prefix = f"{pad}- " if first else f"{pad}  "
                    first = False
                    if isinstance(nested, list) and all(not isinstance(row, (dict, list)) for row in nested):
                        lines.append(f"{prefix}{key}: [{', '.join(scalar(row) for row in nested)}]")
                    elif isinstance(nested, (dict, list)):
                        lines.append(f"{prefix}{key}:")
                        lines.extend(dump_yaml_value(nested, indent + 4))
                    else:
                        lines.append(f"{prefix}{key}: {scalar(nested)}")
            else:
                lines.append(f"{pad}- {scalar(item)}")
        return lines
    return [f"{pad}{scalar(value)}"]


def write_yaml(path: Path, data: dict) -> None:
    path.write_text("\n".join(dump_yaml_value(data)) + "\n", encoding="utf-8")


def registry_path(root: Path) -> Path:
    return root / "contracts" / "active-doc-scope.yaml"


def load_registry(root: Path) -> tuple[Path, dict]:
    path = registry_path(root)
    if not path.is_file():
        fail(f"missing registry: {path}")
    data = load_yaml(path)
    if data.get("version") != 2:
        fail("active-doc-scope registry must be version 2")
    if not isinstance(data.get("scope_entries"), list):
        fail("scope_entries must be a list")
    return path, data


def set_phase(root: Path, phase: str) -> None:
    if phase not in PHASES:
        fail(f"invalid context_contract_phase: {phase}")
    path, data = load_registry(root)
    data["context_contract_phase"] = phase
    record_contract = data.setdefault("record_contract", {})
    enums = record_contract.setdefault("enums", {})
    enums["context_contract_phase"] = ["bootstrap", "enforce", "cleanup"]
    write_yaml(path, data)
    print(f"[PASS] context_contract_phase={phase}")


def archive_feature(root: Path, feature: str, archive_ref: str, archived_at: str) -> None:
    if not (root / archive_ref).exists():
        fail(f"archive_ref does not exist: {archive_ref}")
    path, data = load_registry(root)
    matches = [
        entry
        for entry in data["scope_entries"]
        if entry.get("feature_path") == feature and entry.get("management_status", entry.get("status")) in {"managed", "migrated"}
    ]
    if len(matches) != 1:
        fail(f"expected exactly one active entry for {feature}, found {len(matches)}")
    entry = matches[0]
    entry["management_status"] = "legacy"
    if "status" in entry:
        entry["status"] = "legacy"
    entry["archive_ref"] = archive_ref
    entry["archived_at"] = archived_at
    write_yaml(path, data)
    print(f"[PASS] archived {feature}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    subparsers = parser.add_subparsers(dest="command", required=True)

    phase_parser = subparsers.add_parser("set-phase")
    phase_parser.add_argument("phase", choices=sorted(PHASES))

    archive_parser = subparsers.add_parser("archive")
    archive_parser.add_argument("--feature", required=True)
    archive_parser.add_argument("--archive-ref", required=True)
    archive_parser.add_argument("--archived-at", required=True)

    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = args.repo_root.resolve()
    if args.command == "set-phase":
        set_phase(root, args.phase)
        return 0
    if args.command == "archive":
        archive_feature(root, args.feature, args.archive_ref, args.archived_at)
        return 0
    raise ValueError(f"unknown command: {args.command}")


if __name__ == "__main__":
    raise SystemExit(main())
