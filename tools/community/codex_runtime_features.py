"""Codex hooks feature flag migration and restore operations."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from pathlib import Path

from codex_runtime_common import load_json, write_json
from codex_runtime_toml import (
    key_line_index,
    read_toml_lines,
    remove_key_from_sections,
    section_bounds,
    write_toml_lines,
)

HOOKS_FEATURE_KEY = "hooks"
LEGACY_HOOKS_FEATURE_KEY = "codex_hooks"

REMOVED_FEATURE_FLAGS = (
    LEGACY_HOOKS_FEATURE_KEY,
    "collaboration_modes",
    "sqlite",
    "steer",
    "tui_app_server",
)


# Runtime state captured before install so uninstall can restore user ownership.
@dataclass
class CodexHooksFeatureState:
    """Snapshot needed to restore the user-owned Codex hooks feature flag."""

    # Whether config.toml existed before org-managed hooks touched it.
    had_file: bool
    # Whether the user already had a top-level [features] table.
    had_features_section: bool
    # Whether hooks/codex_hooks was present before install-time migration.
    had_hooks: bool
    # Original feature line so uninstall can preserve indentation and value style.
    previous_line: str | None


def feature_line_index(lines: list[str], start: int, end: int) -> int | None:
    """Locate the active hooks feature key inside a [features] range."""
    return key_line_index(lines, start, end, HOOKS_FEATURE_KEY)


def is_features_section(section_name: str) -> bool:
    """Identify top-level and nested TOML tables that own feature flags."""
    return section_name == "features" or section_name.endswith(".features")


def remove_removed_feature_flags(lines: list[str]) -> None:
    """Drop Codex feature flags retired by the runtime contract."""
    for key in REMOVED_FEATURE_FLAGS:
        remove_key_from_sections(lines, is_features_section, key)


def snapshot_feature_state(path: Path) -> CodexHooksFeatureState:
    """Capture pre-install hooks feature state before mutating config.toml."""
    if not path.exists():
        return CodexHooksFeatureState(False, False, False, None)

    lines = path.read_text(encoding="utf-8").splitlines()
    start, end = section_bounds(lines, "features")
    if start is None or end is None:
        return CodexHooksFeatureState(True, False, False, None)

    idx = feature_line_index(lines, start, end)
    return CodexHooksFeatureState(
        True, True, idx is not None, lines[idx] if idx is not None else None
    )


def load_feature_state(path: Path) -> CodexHooksFeatureState:
    """Load feature state while accepting the previous codex_hooks state key."""
    data = load_json(path)
    if "had_hooks" not in data and "had_codex_hooks" in data:
        data["had_hooks"] = data.get("had_codex_hooks")
    return CodexHooksFeatureState(
        had_file=bool(data.get("had_file")),
        had_features_section=bool(data.get("had_features_section")),
        had_hooks=bool(data.get("had_hooks")),
        previous_line=data.get("previous_line")
        if isinstance(data.get("previous_line"), str)
        else None,
    )


def normalize_hooks_previous_line(line: str | None) -> str:
    """Restore legacy codex_hooks snapshots as the current hooks feature key."""
    if not line or "=" not in line:
        return f"{HOOKS_FEATURE_KEY} = true"

    indent = line[: len(line) - len(line.lstrip())]
    key, value = line.split("=", 1)
    if key.strip() == HOOKS_FEATURE_KEY:
        return line
    return f"{indent}{HOOKS_FEATURE_KEY} = {value.strip()}"


def ensure_feature_enabled(config_path: Path, state_path: Path) -> None:
    """Enable Codex hooks while saving enough state for uninstall restore."""
    if not state_path.exists():
        write_json(state_path, asdict(snapshot_feature_state(config_path)))

    lines = read_toml_lines(config_path)
    start, end = section_bounds(lines, "features")
    if start is None or end is None:
        append_features_section(lines, f"{HOOKS_FEATURE_KEY} = true")
    else:
        set_hooks_feature_line(lines, f"{HOOKS_FEATURE_KEY} = true")

    write_toml_lines(config_path, lines)


def append_features_section(lines: list[str], feature_line: str) -> None:
    """Append a [features] table with one feature assignment."""
    if lines and lines[-1].strip():
        lines.append("")
    lines.extend(["[features]", feature_line])


def set_hooks_feature_line(lines: list[str], feature_line: str) -> None:
    """Set the hooks feature in an existing [features] table after pruning retired keys."""
    remove_removed_feature_flags(lines)
    start, end = require_features_bounds(lines)
    idx = feature_line_index(lines, start, end)
    if idx is None:
        lines.insert(end, feature_line)
    else:
        indent = lines[idx][: len(lines[idx]) - len(lines[idx].lstrip())]
        lines[idx] = f"{indent}{feature_line}"


def require_features_bounds(lines: list[str]) -> tuple[int, int]:
    """Return the [features] range after mutations or fail with a clear invariant error."""
    start, end = section_bounds(lines, "features")
    if start is None or end is None:
        raise ValueError("无法定位 [features] 配置段")
    return start, end


def restore_feature(config_path: Path, state_path: Path) -> None:
    """Restore user-owned hooks feature state and remove install-only state."""
    if not state_path.exists():
        return

    state = load_feature_state(state_path)
    lines = cleaned_feature_lines(config_path)
    if state.had_hooks:
        restore_hooks_line(lines, normalize_hooks_previous_line(state.previous_line))
    else:
        remove_hooks_line_for_restore(lines, state)

    persist_restored_config(config_path, state_path, lines)


def cleaned_feature_lines(config_path: Path) -> list[str]:
    """Read config.toml and prune retired feature flags before restore decisions."""
    lines = read_toml_lines(config_path)
    start, end = section_bounds(lines, "features")
    if start is not None and end is not None:
        remove_removed_feature_flags(lines)
    return lines


def restore_hooks_line(lines: list[str], previous_line: str) -> None:
    """Restore or insert the hooks feature line captured before install."""
    start, end = section_bounds(lines, "features")
    if start is None or end is None:
        append_features_section(lines, previous_line)
        return

    idx = feature_line_index(lines, start, end)
    if idx is None:
        lines.insert(end, previous_line)
    else:
        lines[idx] = previous_line


def remove_hooks_line_for_restore(
    lines: list[str], state: CodexHooksFeatureState
) -> None:
    """Remove the hooks line and delete an install-created empty [features] table."""
    start, end = section_bounds(lines, "features")
    if start is None or end is None:
        return

    idx = feature_line_index(lines, start, end)
    if idx is None:
        return

    del lines[idx]
    remove_empty_created_features_table(lines, state)


def remove_empty_created_features_table(
    lines: list[str], state: CodexHooksFeatureState
) -> None:
    """Drop [features] only when install created it and no user-owned keys remain."""
    start, end = section_bounds(lines, "features")
    if state.had_features_section or start is None or end is None:
        return
    if any(line.strip() for line in lines[start + 1 : end]):
        return

    del lines[start:end]
    while lines and not lines[-1].strip():
        lines.pop()


def persist_restored_config(
    config_path: Path, state_path: Path, lines: list[str]
) -> None:
    """Write or delete config.toml after restore, then delete the state snapshot."""
    if lines:
        write_toml_lines(config_path, lines)
    else:
        config_path.unlink(missing_ok=True)
    state_path.unlink(missing_ok=True)
