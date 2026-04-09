#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def render_text(text: str, runtime_home: str) -> str:
    return text.replace("{{RUNTIME_HOME}}", runtime_home)


def render_entry(entry: dict, runtime_home: str) -> str | None:
    mode = entry["mode"]
    if mode == "human_only":
        return None

    title = entry["title"]
    summary = render_text(entry["runtime_summary"].strip(), runtime_home)
    runtime_path = entry.get("runtime_path")

    if mode == "runtime_link":
        if not runtime_path:
            raise ValueError(f"runtime_link entry missing runtime_path: {entry['id']}")
        return f"- {title}：{summary} 补充细则：`{runtime_home}/{runtime_path}`。"

    return f"- {title}：{summary}"


def resolve_target_file(staging_root: Path, target_name: str) -> Path:
    if target_name == "assistant":
        for candidate in ("CLAUDE.md", "AGENTS.md"):
            target = staging_root / candidate
            if target.exists():
                return target
        raise FileNotFoundError("assistant target requires CLAUDE.md or AGENTS.md in staging root")

    target = staging_root / target_name
    if not target.exists():
        raise FileNotFoundError(f"missing target file for runtime contract: {target}")
    return target


def validate_catalog(catalog: dict, catalog_path: Path) -> None:
    targets = catalog.get("targets")
    if not isinstance(targets, list) or not targets:
        raise ValueError("catalog.targets must be a non-empty list")

    source_root = catalog_path.parent.parent
    seen_ids: set[str] = set()
    seen_targets: set[str] = set()
    allowed_modes = {"inline_summary", "runtime_link", "human_only"}

    for target in targets:
        if not isinstance(target, dict):
            raise ValueError("catalog target must be a mapping")

        target_name = target.get("target")
        placeholder = target.get("placeholder")
        entries = target.get("entries")

        if not isinstance(target_name, str) or not target_name:
            raise ValueError("catalog target missing target name")
        if target_name in seen_targets:
            raise ValueError(f"duplicate target definition: {target_name}")
        seen_targets.add(target_name)

        if not isinstance(placeholder, str) or not placeholder:
            raise ValueError(f"{target_name}: missing placeholder")
        if not isinstance(entries, list) or not entries:
            raise ValueError(f"{target_name}: entries must be a non-empty list")

        for entry in entries:
            if not isinstance(entry, dict):
                raise ValueError(f"{target_name}: entry must be a mapping")

            entry_id = entry.get("id")
            if not isinstance(entry_id, str) or not entry_id:
                raise ValueError(f"{target_name}: missing entry id")
            if entry_id in seen_ids:
                raise ValueError(f"duplicate entry id: {entry_id}")
            seen_ids.add(entry_id)

            mode = entry.get("mode")
            if mode not in allowed_modes:
                raise ValueError(f"{target_name}: invalid mode for {entry_id}: {mode}")

            owner = entry.get("owner")
            if owner not in {"assistant", "rules", "reference"}:
                raise ValueError(f"{target_name}: invalid owner for {entry_id}: {owner}")

            title = entry.get("title")
            if not isinstance(title, str) or not title.strip():
                raise ValueError(f"{target_name}: missing title for {entry_id}")

            source_path = entry.get("source_path")
            if not isinstance(source_path, str) or not source_path:
                raise ValueError(f"{target_name}: missing source_path for {entry_id}")
            if not (source_root / source_path).exists():
                raise ValueError(f"{target_name}: missing source_path target for {entry_id}: {source_path}")

            if mode != "human_only":
                runtime_summary = entry.get("runtime_summary")
                if not isinstance(runtime_summary, str) or not runtime_summary.strip():
                    raise ValueError(f"{target_name}: missing runtime_summary for {entry_id}")


def render_target_contract(target: dict, runtime_home: str) -> str:
    lines = []
    for entry in target["entries"]:
        rendered = render_entry(entry, runtime_home)
        if rendered:
            lines.append(rendered)

    if not lines:
        raise ValueError(f"{target['target']}: no runtime-visible entries rendered")

    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Render runtime contract blocks into staging docs.")
    parser.add_argument("--staging-root", required=True)
    parser.add_argument("--catalog", required=True)
    parser.add_argument("--runtime-home", required=True)
    args = parser.parse_args()

    staging_root = Path(args.staging_root)
    catalog_path = Path(args.catalog)

    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    validate_catalog(catalog, catalog_path)

    for target in catalog["targets"]:
        target_file = resolve_target_file(staging_root, target["target"])
        placeholder = "{{" + target["placeholder"] + "}}"
        text = target_file.read_text(encoding="utf-8")
        if placeholder not in text:
            raise ValueError(f"{target_file} missing placeholder {placeholder}")
        rendered = render_target_contract(target, args.runtime_home)
        target_file.write_text(text.replace(placeholder, rendered), encoding="utf-8")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pragma: no cover - fail-close CLI wrapper
        print(f"FATAL: {exc}", file=sys.stderr)
        raise SystemExit(1)
