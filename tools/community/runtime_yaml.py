#!/usr/bin/env python3
"""Load the small YAML subset used by standard-chain runtime registries."""

from __future__ import annotations

from pathlib import Path


def _strip_comment(line: str) -> str:
    if line.lstrip().startswith("#"):
        return ""
    return line.split(" #", 1)[0].rstrip()


def _scalar(value: str) -> object:
    value = value.strip()
    if value == "true":
        return True
    if value == "false":
        return False
    if value in {"null", "~"}:
        return None
    return value.strip('"').strip("'")


def _split_key_value(text: str) -> tuple[str, str]:
    if ":" not in text:
        raise ValueError(f"invalid yaml mapping line: {text}")
    key, value = text.split(":", 1)
    return key.strip(), value.strip()


def _parse_block(lines: list[tuple[int, str]], index: int, indent: int) -> tuple[object, int]:
    if index >= len(lines):
        return {}, index
    if lines[index][0] < indent:
        return {}, index
    if lines[index][1].startswith("- "):
        return _parse_list(lines, index, indent)
    return _parse_mapping(lines, index, indent)


def _parse_list(lines: list[tuple[int, str]], index: int, indent: int) -> tuple[list[object], int]:
    result: list[object] = []
    while index < len(lines):
        current_indent, text = lines[index]
        if current_indent < indent or not text.startswith("- "):
            break
        if current_indent != indent:
            raise ValueError(f"unexpected list indentation: {text}")
        item_text = text[2:].strip()
        index += 1
        if not item_text:
            item, index = _parse_block(lines, index, indent + 2)
            result.append(item)
            continue
        if ":" in item_text:
            key, value = _split_key_value(item_text)
            item = {key: _scalar(value)} if value else {key: {}}
            if index < len(lines) and lines[index][0] > indent:
                nested, index = _parse_mapping(lines, index, lines[index][0])
                if not value and isinstance(nested, dict):
                    item[key] = nested
                elif isinstance(nested, dict):
                    item.update(nested)
            result.append(item)
            continue
        result.append(_scalar(item_text))
    return result, index


def _parse_mapping(lines: list[tuple[int, str]], index: int, indent: int) -> tuple[dict, int]:
    result: dict[str, object] = {}
    while index < len(lines):
        current_indent, text = lines[index]
        if current_indent < indent or text.startswith("- "):
            break
        if current_indent != indent:
            raise ValueError(f"unexpected mapping indentation: {text}")
        key, value = _split_key_value(text)
        index += 1
        if value:
            result[key] = _scalar(value)
            continue
        if index < len(lines) and lines[index][0] > indent:
            result[key], index = _parse_block(lines, index, lines[index][0])
        else:
            result[key] = {}
    return result, index


def load_yaml(path: Path) -> dict:
    """Load a registry YAML file without requiring PyYAML in installed runtimes."""

    try:
        import yaml  # type: ignore

        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except ModuleNotFoundError:
        lines = []
        for raw_line in path.read_text(encoding="utf-8").splitlines():
            stripped = _strip_comment(raw_line)
            if not stripped:
                continue
            lines.append((len(raw_line) - len(raw_line.lstrip(" ")), stripped.lstrip()))
        data, index = _parse_block(lines, 0, 0)
        if index != len(lines):
            raise ValueError(f"{path} contains unsupported yaml structure")
    if not isinstance(data, dict):
        raise ValueError(f"{path} 顶层必须是对象")
    return data
