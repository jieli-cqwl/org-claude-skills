#!/usr/bin/env python3
"""Update active context scope registry through controlled lifecycle operations."""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

from runtime_yaml import load_yaml


def scalar(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "null"
    text = str(value)
    if any(char in text for char in ":#{}[]&,") or text == "":
        return '"' + text.replace('"', '\\"') + '"'
    return text


def dump_yaml(value: Any, indent: int = 0) -> list[str]:
    pad = " " * indent
    if isinstance(value, dict):
        lines: list[str] = []
        for key, item in value.items():
            if item == []:
                lines.append(f"{pad}{key}: []")
                continue
            if item == {}:
                lines.append(f"{pad}{key}: {{}}")
                continue
            if isinstance(item, (dict, list)):
                lines.append(f"{pad}{key}:")
                lines.extend(dump_yaml(item, indent + 2))
            else:
                lines.append(f"{pad}{key}: {scalar(item)}")
        return lines
    if isinstance(value, list):
        lines = []
        for item in value:
            if isinstance(item, dict):
                first = True
                for key, child in item.items():
                    if first:
                        if isinstance(child, (dict, list)):
                            lines.append(f"{pad}- {key}:")
                            lines.extend(dump_yaml(child, indent + 4))
                        else:
                            lines.append(f"{pad}- {key}: {scalar(child)}")
                        first = False
                    else:
                        if isinstance(child, (dict, list)):
                            lines.append(f"{pad}  {key}:")
                            lines.extend(dump_yaml(child, indent + 4))
                        else:
                            lines.append(f"{pad}  {key}: {scalar(child)}")
            else:
                lines.append(f"{pad}- {scalar(item)}")
        return lines
    return [f"{pad}{scalar(value)}"]


def registry_path(root: Path) -> Path:
    return root / "contracts" / "active-doc-scope.yaml"


def load_registry(root: Path) -> dict[str, Any]:
    path = registry_path(root)
    if path.is_file():
        return load_yaml(path)
    return {"version": 2, "context_contract_phase": "bootstrap", "scope_entries": []}


def write_registry(root: Path, data: dict[str, Any]) -> None:
    path = registry_path(root)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(dump_yaml(data)) + "\n", encoding="utf-8")


def ensure_contract(data: dict[str, Any], phase: str) -> None:
    data["version"] = 2
    data["context_contract_phase"] = phase
    if not isinstance(data.get("scope_entries"), list):
        data["scope_entries"] = []


def find_entry(data: dict[str, Any], feature_path: str) -> dict[str, Any] | None:
    entries = data.setdefault("scope_entries", [])
    if not isinstance(entries, list):
        raise ValueError("scope_entries must be a list")
    for entry in entries:
        if isinstance(entry, dict) and entry.get("feature_path") == feature_path:
            return entry
    return None


def cmd_bootstrap(args: argparse.Namespace) -> None:
    root = Path(args.root)
    data = load_registry(root)
    ensure_contract(data, args.phase)
    write_registry(root, data)


def cmd_phase(args: argparse.Namespace) -> None:
    root = Path(args.root)
    data = load_registry(root)
    ensure_contract(data, args.phase)
    write_registry(root, data)


def cmd_adopt(args: argparse.Namespace) -> None:
    root = Path(args.root)
    data = load_registry(root)
    ensure_contract(data, str(data.get("context_contract_phase") or "bootstrap"))
    entries = data.setdefault("scope_entries", [])
    entry = find_entry(data, args.feature_path)
    if entry is None:
        entry = {}
        entries.append(entry)
    entry.update(
        {
            "feature_path": args.feature_path,
            "mode": args.mode,
            "management_status": "managed",
            "status": "managed",
            "rollout_phase": args.rollout_phase,
            "layout": args.layout,
            "entry_ref": "worklog.md",
            "context_owner": args.context_owner,
            "owner": args.context_owner,
        }
    )
    if args.workset:
        entry["primary_workset_relpath"] = args.workset
    write_registry(root, data)


def cmd_archive(args: argparse.Namespace) -> None:
    root = Path(args.root)
    data = load_registry(root)
    entry = find_entry(data, args.feature_path)
    if entry is None:
        raise SystemExit(f"feature not found: {args.feature_path}")
    entry["management_status"] = "legacy"
    entry["status"] = "legacy"
    entry["archive_ref"] = args.archive_ref
    entry["archived_at"] = args.archived_at
    write_registry(root, data)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    bootstrap = sub.add_parser("bootstrap")
    bootstrap.add_argument("--root", default=".")
    bootstrap.add_argument("--phase", choices=["bootstrap", "enforce", "cleanup"], default="bootstrap")
    bootstrap.set_defaults(func=cmd_bootstrap)

    phase = sub.add_parser("phase")
    phase.add_argument("--root", default=".")
    phase.add_argument("--phase", choices=["bootstrap", "enforce", "cleanup"], required=True)
    phase.set_defaults(func=cmd_phase)

    adopt = sub.add_parser("adopt")
    adopt.add_argument("--root", default=".")
    adopt.add_argument("--feature-path", required=True)
    adopt.add_argument("--mode", choices=["small-chain", "standard-chain"], required=True)
    adopt.add_argument("--layout", choices=["dated-workset", "phase-tree"], required=True)
    adopt.add_argument("--workset", default="")
    adopt.add_argument("--context-owner", required=True)
    adopt.add_argument("--rollout-phase", default="phase-1-pilot")
    adopt.set_defaults(func=cmd_adopt)

    archive = sub.add_parser("archive")
    archive.add_argument("--root", default=".")
    archive.add_argument("--feature-path", required=True)
    archive.add_argument("--archive-ref", required=True)
    archive.add_argument("--archived-at", required=True)
    archive.set_defaults(func=cmd_archive)

    args = parser.parse_args()
    args.func(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
