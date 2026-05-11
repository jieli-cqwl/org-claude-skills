"""TOML line-editing primitives for Codex runtime configuration files."""

from __future__ import annotations

from pathlib import Path
from typing import Callable

from codex_runtime_common import serialize_lines

Pred = Callable[[str], bool]


def strip_toml_comment(line: str) -> str:
    """Remove TOML comments without treating hashes inside string literals as comments."""
    quote: str | None = None
    escaped = False

    for idx, char in enumerate(line):
        if quote == '"':
            if escaped:
                escaped = False
                continue
            if char == "\\":
                escaped = True
                continue
            if char == quote:
                quote = None
                continue
            continue

        if quote == "'":
            if char == quote:
                quote = None
            continue

        if char in ("'", '"'):
            quote = char
            continue
        if char == "#":
            return line[:idx]

    return line


def toml_table_header(line: str) -> tuple[str, bool] | None:
    """Return TOML table name and whether it is an array-table header."""
    stripped = strip_toml_comment(line).strip()
    if stripped.startswith("[[") and stripped.endswith("]]"):
        return stripped[2:-2].strip(), True
    if stripped.startswith("[") and stripped.endswith("]"):
        return stripped[1:-1].strip(), False
    return None


def section_bounds(lines: list[str], name: str) -> tuple[int | None, int | None]:
    """Locate a non-array TOML table and return its inclusive start, exclusive end."""
    start = None
    for idx, line in enumerate(lines):
        header = toml_table_header(line)
        if header == (name, False):
            start = idx
            break

    if start is None:
        return None, None

    _, end = section_end_from(lines, start)
    return start, end


def matching_section_bounds(lines: list[str], predicate: Pred) -> list[tuple[int, int]]:
    """Find non-array TOML table ranges whose names satisfy the predicate."""
    bounds: list[tuple[int, int]] = []
    idx = 0
    while idx < len(lines):
        header = toml_table_header(lines[idx])
        if header is None:
            idx += 1
            continue

        section_name, is_array = header
        start, end = section_end_from(lines, idx)
        if not is_array and predicate(section_name):
            bounds.append((start, end))
        idx = end

    return bounds


def section_end_from(lines: list[str], start: int) -> tuple[int, int]:
    """Return a TOML table range starting at an already-known header index."""
    end = len(lines)
    for next_idx in range(start + 1, len(lines)):
        if toml_table_header(lines[next_idx]) is not None:
            end = next_idx
            break
    return start, end


def key_line_index(lines: list[str], start: int, end: int, key: str) -> int | None:
    """Find a direct key assignment inside a TOML table range."""
    for idx in range(start + 1, end):
        stripped = lines[idx].strip()
        if stripped.startswith("#") or "=" not in stripped:
            continue
        current_key = stripped.split("=", 1)[0].strip()
        if current_key == key:
            return idx
    return None


def remove_key_from_bounds(lines: list[str], start: int, end: int, key: str) -> int:
    """Remove all direct occurrences of a TOML key inside a known table range."""
    removed = 0
    while True:
        idx = key_line_index(lines, start, end, key)
        if idx is None:
            return removed
        del lines[idx]
        end -= 1
        removed += 1


def remove_key_from_sections(lines: list[str], predicate: Pred, key: str) -> int:
    """Remove a key from all matching TOML table ranges in reverse order."""
    removed = 0
    for start, end in reversed(matching_section_bounds(lines, predicate)):
        removed += remove_key_from_bounds(lines, start, end, key)
    return removed


def read_toml_lines(config_path: Path) -> list[str]:
    """Read config.toml as raw lines because comments and ordering are user-owned."""
    if not config_path.exists():
        return []
    return config_path.read_text(encoding="utf-8").splitlines()


def write_toml_lines(config_path: Path, lines: list[str]) -> None:
    """Persist config.toml lines preserving human-readable TOML layout."""
    config_path.parent.mkdir(parents=True, exist_ok=True)
    config_path.write_text(serialize_lines(lines), encoding="utf-8")


def first_section_index_with_prefix(lines: list[str], prefix: str) -> int | None:
    """Return the first TOML table whose name starts with a prefix."""
    for idx, line in enumerate(lines):
        header = toml_table_header(line)
        if header is not None and header[0].startswith(prefix):
            return idx
    return None


def ensure_section(lines: list[str], section: str, before: str | None = None) -> None:
    """Create a TOML table while preserving nearby blank-line readability."""
    start, _ = section_bounds(lines, section)
    if start is not None:
        return

    insert_idx = len(lines)
    if before is not None:
        candidate = first_section_index_with_prefix(lines, before)
        if candidate is not None:
            insert_idx = candidate

    block = [f"[{section}]"]
    if insert_idx > 0 and lines[insert_idx - 1].strip():
        block.insert(0, "")
    if insert_idx < len(lines) and lines[insert_idx].strip():
        block.append("")
    lines[insert_idx:insert_idx] = block


def set_toml_key(lines, section, key, raw_value, before=None) -> None:
    """Set one TOML key inside a section without disturbing unrelated keys."""
    ensure_section(lines, section, before)
    start, end = section_bounds(lines, section)
    if start is None or end is None:
        raise ValueError(f"无法创建或定位配置段 [{section}]")

    next_line = f"{key} = {raw_value}"
    idx = key_line_index(lines, start, end, key)
    if idx is not None:
        indent = lines[idx][: len(lines[idx]) - len(lines[idx].lstrip())]
        lines[idx] = f"{indent}{next_line}"
        return

    insert_idx = end
    while insert_idx > start + 1 and not lines[insert_idx - 1].strip():
        insert_idx -= 1
    lines.insert(insert_idx, next_line)
