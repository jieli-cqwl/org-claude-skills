"""hooks.json merge and cleanup helpers for Codex runtime management."""

from __future__ import annotations

import os
import shlex
from dataclasses import dataclass
from pathlib import Path

from codex_runtime_common import (
    load_event_policy,
    load_hooks_data,
    load_json,
    write_json,
)


def is_stale_probe(command: str) -> bool:
    """Detect leftover install probe commands that should never survive runtime install."""
    if "codex-hooks-probe." not in command:
        return False
    try:
        parts = shlex.split(command)
    except ValueError:
        return True
    return any("codex-hooks-probe." in token for token in parts)


def command_is_under_root(command_part: str, managed_prefix: str) -> bool:
    """Return whether one shell-token path is inside the managed runtime root."""
    normalized = os.path.normpath(command_part)
    return normalized == managed_prefix or normalized.startswith(
        managed_prefix + os.sep
    )


def is_managed_command(command: str, managed_root: Path) -> bool:
    """Return whether a hook command belongs to the org-managed runtime root."""
    managed_prefix = os.path.normpath(str(managed_root))
    try:
        parts = shlex.split(command)
    except ValueError:
        return str(managed_root) in command or command_is_under_root(
            command, managed_prefix
        )

    return any(command_is_under_root(token, managed_prefix) for token in parts)


def collect_managed_commands(data: dict) -> set[str]:
    """Collect exact managed hook commands so cleanup can remove old copies."""
    commands: set[str] = set()
    hooks = data.get("hooks")
    if not isinstance(hooks, dict):
        return commands

    for entries in hooks.values():
        collect_commands_from_entries(entries, commands)
    return commands


def collect_commands_from_entries(entries: object, commands: set[str]) -> None:
    """Add command strings from one event entry list into the accumulator."""
    if not isinstance(entries, list):
        return
    for entry in entries:
        if isinstance(entry, dict):
            collect_commands_from_hooks(entry.get("hooks"), commands)


def collect_commands_from_hooks(entry_hooks: object, commands: set[str]) -> None:
    """Add command strings from a hook list into the accumulator."""
    if not isinstance(entry_hooks, list):
        return
    for hook in entry_hooks:
        if not isinstance(hook, dict):
            continue
        command = hook.get("command")
        if isinstance(command, str) and command:
            commands.add(command)


# Filtering state is explicit so nested helpers can update removal counters.
@dataclass
class FilterContext:
    """Mutable counters and matching inputs shared across one hooks filtering pass."""

    # Root path whose commands are org-managed and must be replaced on install.
    managed_root: Path
    # Event names fully owned by managed runtime hooks.
    managed_only_events: set[str]
    # Exact commands rendered by the current managed hooks registry.
    managed_commands: set[str]
    # Number of managed hook commands removed in this filtering pass.
    removed_managed: int = 0
    # Number of stale probe commands removed in this filtering pass.
    removed_stale: int = 0


def filter_runtime_hooks(
    data: dict,
    managed_root: Path,
    allowed_events: set[str] | None = None,
    managed_only_events: set[str] | None = None,
    managed_commands: set[str] | None = None,
) -> tuple[dict, int, int]:
    """Remove stale or previous managed hooks while preserving supported user hooks."""
    hooks = data.get("hooks") or {}
    context = FilterContext(
        managed_root, managed_only_events or set(), managed_commands or set()
    )
    filtered_hooks = filter_events(hooks, allowed_events, context)
    data["hooks"] = filtered_hooks
    return data, context.removed_managed, context.removed_stale


def filter_events(
    hooks: object, allowed_events: set[str] | None, context: FilterContext
) -> dict:
    """Filter every hooks event and skip events outside the managed allow-list."""
    if not isinstance(hooks, dict):
        return {}

    filtered_hooks: dict = {}
    for event, entries in hooks.items():
        if allowed_events is not None and event not in allowed_events:
            continue
        filtered_hooks[event] = filter_event_entries(event, entries, context)
    return filtered_hooks


def filter_event_entries(event: str, entries: object, context: FilterContext) -> object:
    """Filter one event while preserving non-list custom shapes unchanged."""
    if event in context.managed_only_events:
        return []
    if not isinstance(entries, list):
        return entries

    next_entries = []
    for entry in entries:
        next_entry = filter_entry(entry, context)
        if next_entry is not None:
            next_entries.append(next_entry)
    return next_entries


def filter_entry(entry: object, context: FilterContext) -> object | None:
    """Filter one hooks entry and drop it when all nested hooks were removed."""
    if not isinstance(entry, dict):
        return entry

    entry_hooks = entry.get("hooks")
    if not isinstance(entry_hooks, list):
        return entry

    next_hook_list = filter_hook_list(entry_hooks, context)
    if not next_hook_list:
        return None

    next_entry = dict(entry)
    next_entry["hooks"] = next_hook_list
    return next_entry


def filter_hook_list(entry_hooks: list, context: FilterContext) -> list:
    """Filter nested hook objects while retaining non-dict entries."""
    next_hook_list = []
    for hook in entry_hooks:
        if should_remove_hook(hook, context):
            continue
        next_hook_list.append(hook)
    return next_hook_list


def should_remove_hook(hook: object, context: FilterContext) -> bool:
    """Classify stale probe and managed hook commands for removal."""
    if not isinstance(hook, dict):
        return False

    command = hook.get("command", "")
    if not command:
        return False
    if is_stale_probe(command):
        context.removed_stale += 1
        return True
    if command in context.managed_commands or is_managed_command(
        command, context.managed_root
    ):
        context.removed_managed += 1
        return True
    return False


def drop_empty_events(data: dict) -> dict:
    """Remove events whose hook entry lists became empty during cleanup."""
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
    """Return whether hooks.json still contains any user or managed hook entries."""
    hooks = data.get("hooks")
    if not isinstance(hooks, dict):
        return False

    for entries in hooks.values():
        if isinstance(entries, list) and entries:
            return True
    return False


def merge_hooks(hooks_file: Path, managed_file: Path, managed_root: Path) -> None:
    """Replace previous managed hooks and merge the current managed hook registry."""
    current = load_hooks_data(hooks_file)
    managed = load_hooks_data(managed_file)
    allowed_events, managed_only_events = load_event_policy(load_json(managed_file))
    current, _, _ = filter_runtime_hooks(
        current,
        managed_root,
        allowed_events,
        managed_only_events,
        collect_managed_commands(managed),
    )
    append_managed_hooks(current, managed, hooks_file, managed_file)
    write_json(hooks_file, current)


def append_managed_hooks(
    current: dict, managed: dict, hooks_file: Path, managed_file: Path
) -> None:
    """Put managed registry hooks before preserved user hooks for stable trust keys."""
    for event, entries in managed.get("hooks", {}).items():
        current["hooks"].setdefault(event, [])
        if not isinstance(current["hooks"][event], list):
            raise ValueError(f"{hooks_file} 的事件 {event} 不是列表，无法安全合并")
        if not isinstance(entries, list):
            raise ValueError(f"{managed_file} 的事件 {event} 不是列表")
        current["hooks"][event] = entries + current["hooks"][event]


def cleanup_hooks(
    hooks_file: Path, managed_root: Path, managed_file: Path | None = None
) -> None:
    """Remove managed hooks and delete hooks.json when no user hooks remain."""
    if not hooks_file.exists():
        return

    current = load_hooks_data(hooks_file)
    allowed_events, managed_only_events, managed_commands = cleanup_policy(managed_file)
    current, _, _ = filter_runtime_hooks(
        current,
        managed_root,
        allowed_events,
        managed_only_events,
        managed_commands,
    )
    current = drop_empty_events(current)

    if has_any_hooks(current):
        write_json(hooks_file, current)
        return

    hooks_file.unlink(missing_ok=True)


def cleanup_policy(
    managed_file: Path | None,
) -> tuple[set[str] | None, set[str], set[str]]:
    """Load cleanup event policy only when the managed registry is available."""
    if managed_file is None or not managed_file.exists():
        return None, set(), set()

    managed_data = load_json(managed_file)
    allowed_events, managed_only_events = load_event_policy(managed_data)
    return allowed_events, managed_only_events, collect_managed_commands(managed_data)
