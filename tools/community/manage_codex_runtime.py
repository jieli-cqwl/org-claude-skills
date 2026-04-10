#!/usr/bin/env python3
"""Manage Codex runtime hook config and hooks.json merge/cleanup."""

from __future__ import annotations

import argparse
import json
import shlex
import sys
from dataclasses import asdict, dataclass
from pathlib import Path


@dataclass
class CodexHooksFeatureState:
    had_file: bool
    had_features_section: bool
    had_codex_hooks: bool
    previous_line: str | None


def load_json(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise ValueError(f"{path} 不是有效 JSON: {exc}") from exc

    if not isinstance(data, dict):
        raise ValueError(f"{path} 顶层必须是对象")
    return data


def load_hooks_data(path: Path) -> dict:
    if not path.exists():
        return {"hooks": {}}

    data = load_json(path)
    hooks = data.get("hooks")
    if hooks is None:
        data["hooks"] = {}
        return data
    if not isinstance(hooks, dict):
        raise ValueError(f"{path} 的 hooks 字段必须是对象")
    return data


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def load_event_policy(data: dict) -> tuple[set[str] | None, set[str]]:
    metadata = data.get("_org_skills")
    if metadata is None:
        return None, set()
    if not isinstance(metadata, dict):
        raise ValueError("_org_skills 元数据必须是对象")

    allowed_raw = metadata.get("allowed_events")
    managed_only_raw = metadata.get("managed_only_events", [])
    if not isinstance(allowed_raw, list) or not all(isinstance(item, str) for item in allowed_raw):
        raise ValueError("_org_skills.allowed_events 必须是字符串数组")
    if not isinstance(managed_only_raw, list) or not all(
        isinstance(item, str) for item in managed_only_raw
    ):
        raise ValueError("_org_skills.managed_only_events 必须是字符串数组")
    return set(allowed_raw), set(managed_only_raw)


def section_bounds(lines: list[str], name: str) -> tuple[int | None, int | None]:
    start = None
    for idx, line in enumerate(lines):
        if line.strip() == f"[{name}]":
            start = idx
            break

    if start is None:
        return None, None

    end = len(lines)
    for idx in range(start + 1, len(lines)):
        stripped = lines[idx].strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            end = idx
            break
    return start, end


def feature_line_index(lines: list[str], start: int, end: int) -> int | None:
    for idx in range(start + 1, end):
        stripped = lines[idx].strip()
        if stripped.startswith("codex_hooks") and "=" in stripped:
            return idx
    return None


def snapshot_feature_state(path: Path) -> CodexHooksFeatureState:
    if not path.exists():
        return CodexHooksFeatureState(
            had_file=False,
            had_features_section=False,
            had_codex_hooks=False,
            previous_line=None,
        )

    lines = path.read_text(encoding="utf-8").splitlines()
    start, end = section_bounds(lines, "features")
    if start is None or end is None:
        return CodexHooksFeatureState(
            had_file=True,
            had_features_section=False,
            had_codex_hooks=False,
            previous_line=None,
        )

    idx = feature_line_index(lines, start, end)
    return CodexHooksFeatureState(
        had_file=True,
        had_features_section=True,
        had_codex_hooks=idx is not None,
        previous_line=lines[idx] if idx is not None else None,
    )


def serialize_lines(lines: list[str]) -> str:
    if not lines:
        return ""
    return "\n".join(lines).rstrip("\n") + "\n"


def ensure_feature_enabled(config_path: Path, state_path: Path) -> None:
    if not state_path.exists():
        write_json(state_path, asdict(snapshot_feature_state(config_path)))

    lines = config_path.read_text(encoding="utf-8").splitlines() if config_path.exists() else []
    start, end = section_bounds(lines, "features")

    if start is None or end is None:
        if lines and lines[-1].strip():
            lines.append("")
        lines.extend(["[features]", "codex_hooks = true"])
    else:
        idx = feature_line_index(lines, start, end)
        if idx is None:
            lines.insert(end, "codex_hooks = true")
        else:
            indent = lines[idx][: len(lines[idx]) - len(lines[idx].lstrip())]
            lines[idx] = f"{indent}codex_hooks = true"

    config_path.parent.mkdir(parents=True, exist_ok=True)
    config_path.write_text(serialize_lines(lines), encoding="utf-8")


def restore_feature(config_path: Path, state_path: Path) -> None:
    if not state_path.exists():
        return

    state = CodexHooksFeatureState(**load_json(state_path))
    lines = config_path.read_text(encoding="utf-8").splitlines() if config_path.exists() else []
    start, end = section_bounds(lines, "features")

    if state.had_codex_hooks:
        previous_line = state.previous_line or "codex_hooks = true"
        if start is None or end is None:
            if lines and lines[-1].strip():
                lines.append("")
            lines.extend(["[features]", previous_line])
        else:
            idx = feature_line_index(lines, start, end)
            if idx is None:
                lines.insert(end, previous_line)
            else:
                lines[idx] = previous_line
    else:
        if start is not None and end is not None:
            idx = feature_line_index(lines, start, end)
            if idx is not None:
                del lines[idx]
                start, end = section_bounds(lines, "features")
                if (
                    not state.had_features_section
                    and start is not None
                    and end is not None
                    and not any(line.strip() for line in lines[start + 1 : end])
                ):
                    del lines[start:end]
                    while lines and not lines[-1].strip():
                        lines.pop()

    if lines:
        config_path.parent.mkdir(parents=True, exist_ok=True)
        config_path.write_text(serialize_lines(lines), encoding="utf-8")
    else:
        config_path.unlink(missing_ok=True)

    state_path.unlink(missing_ok=True)


def is_stale_probe(command: str) -> bool:
    if "codex-hooks-probe." not in command:
        return False
    try:
        parts = shlex.split(command)
    except ValueError:
        return True
    return any("codex-hooks-probe." in token for token in parts)


def is_managed_command(command: str, managed_root: Path) -> bool:
    try:
        parts = shlex.split(command)
    except ValueError:
        return str(managed_root) in command

    managed_prefix = str(managed_root)
    return any(token.startswith(managed_prefix) for token in parts)


def filter_runtime_hooks(
    data: dict,
    managed_root: Path,
    allowed_events: set[str] | None = None,
    managed_only_events: set[str] | None = None,
) -> tuple[dict, int, int]:
    hooks = data.get("hooks") or {}
    filtered_hooks: dict = {}
    removed_managed = 0
    removed_stale = 0
    managed_only_events = managed_only_events or set()

    for event, entries in hooks.items():
        if allowed_events is not None and event not in allowed_events:
            continue

        if event in managed_only_events:
            filtered_hooks[event] = []
            continue

        if not isinstance(entries, list):
            filtered_hooks[event] = entries
            continue

        next_entries = []
        for entry in entries:
            if not isinstance(entry, dict):
                next_entries.append(entry)
                continue

            entry_hooks = entry.get("hooks")
            if not isinstance(entry_hooks, list):
                next_entries.append(entry)
                continue

            next_hook_list = []
            for hook in entry_hooks:
                if not isinstance(hook, dict):
                    next_hook_list.append(hook)
                    continue

                command = hook.get("command", "")
                if command and is_stale_probe(command):
                    removed_stale += 1
                    continue
                if command and is_managed_command(command, managed_root):
                    removed_managed += 1
                    continue
                next_hook_list.append(hook)

            if next_hook_list:
                next_entry = dict(entry)
                next_entry["hooks"] = next_hook_list
                next_entries.append(next_entry)

        filtered_hooks[event] = next_entries

    data["hooks"] = filtered_hooks
    return data, removed_managed, removed_stale


def drop_empty_events(data: dict) -> dict:
    hooks = data.get("hooks")
    if not isinstance(hooks, dict):
        return data

    data["hooks"] = {
        event: entries
        for event, entries in hooks.items()
        if not (isinstance(entries, list) and not entries)
    }
    return data


def has_any_hooks(data: dict) -> bool:
    hooks = data.get("hooks")
    if not isinstance(hooks, dict):
        return False

    for entries in hooks.values():
        if isinstance(entries, list) and entries:
            return True
    return False


def merge_hooks(hooks_file: Path, managed_file: Path, managed_root: Path) -> None:
    current = load_hooks_data(hooks_file)
    managed = load_hooks_data(managed_file)
    allowed_events, managed_only_events = load_event_policy(load_json(managed_file))
    current, _, _ = filter_runtime_hooks(current, managed_root, allowed_events, managed_only_events)

    for event, entries in managed.get("hooks", {}).items():
        current["hooks"].setdefault(event, [])
        if not isinstance(current["hooks"][event], list):
            raise ValueError(f"{hooks_file} 的事件 {event} 不是列表，无法安全合并")
        if not isinstance(entries, list):
            raise ValueError(f"{managed_file} 的事件 {event} 不是列表")
        current["hooks"][event].extend(entries)

    write_json(hooks_file, current)


def cleanup_hooks(hooks_file: Path, managed_root: Path, managed_file: Path | None = None) -> None:
    if not hooks_file.exists():
        return

    current = load_hooks_data(hooks_file)
    allowed_events = None
    managed_only_events: set[str] = set()
    if managed_file is not None and managed_file.exists():
        allowed_events, managed_only_events = load_event_policy(load_json(managed_file))
    current, _, _ = filter_runtime_hooks(current, managed_root, allowed_events, managed_only_events)
    current = drop_empty_events(current)

    if has_any_hooks(current):
        write_json(hooks_file, current)
        return

    hooks_file.unlink(missing_ok=True)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Manage Codex runtime feature flag and hooks.json.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    enable = subparsers.add_parser("enable-feature")
    enable.add_argument("--config", required=True)
    enable.add_argument("--state", required=True)

    restore = subparsers.add_parser("restore-feature")
    restore.add_argument("--config", required=True)
    restore.add_argument("--state", required=True)

    merge = subparsers.add_parser("merge-hooks")
    merge.add_argument("--hooks-file", required=True)
    merge.add_argument("--managed-file", required=True)
    merge.add_argument("--managed-root", required=True)

    cleanup = subparsers.add_parser("cleanup-hooks")
    cleanup.add_argument("--hooks-file", required=True)
    cleanup.add_argument("--managed-root", required=True)
    cleanup.add_argument("--managed-file")
    return parser


def main() -> int:
    args = build_parser().parse_args()

    if args.command == "enable-feature":
        ensure_feature_enabled(Path(args.config), Path(args.state))
        return 0

    if args.command == "restore-feature":
        restore_feature(Path(args.config), Path(args.state))
        return 0

    if args.command == "merge-hooks":
        merge_hooks(
            Path(args.hooks_file),
            Path(args.managed_file),
            Path(args.managed_root),
        )
        return 0

    if args.command == "cleanup-hooks":
        cleanup_hooks(
            Path(args.hooks_file),
            Path(args.managed_root),
            Path(args.managed_file) if args.managed_file else None,
        )
        return 0

    raise ValueError(f"unknown command: {args.command}")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pragma: no cover
        print(f"FATAL: {exc}", file=sys.stderr)
        raise SystemExit(1)
