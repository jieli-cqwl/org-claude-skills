"""Shared JSON and text helpers for Codex runtime management."""

from __future__ import annotations

import json
from pathlib import Path


def load_json(path: Path) -> dict:
    """Read a JSON object and fail with a user-facing path-specific error."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise ValueError(f"{path} 不是有效 JSON: {exc}") from exc

    if not isinstance(data, dict):
        raise ValueError(f"{path} 顶层必须是对象")
    return data


def load_hooks_data(path: Path) -> dict:
    """Load hooks.json while normalizing a missing hooks object to an empty mapping."""
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
    """Write stable UTF-8 JSON so runtime diffs remain reviewable."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def load_event_policy(data: dict) -> tuple[set[str] | None, set[str]]:
    """Read managed hook event policy from metadata and validate its shape."""
    metadata = data.get("_org_skills")
    if metadata is None:
        return None, set()
    if not isinstance(metadata, dict):
        raise ValueError("_org_skills 元数据必须是对象")

    allowed_raw = metadata.get("allowed_events")
    managed_only_raw = metadata.get("managed_only_events", [])
    if not isinstance(allowed_raw, list) or not all(
        isinstance(item, str) for item in allowed_raw
    ):
        raise ValueError("_org_skills.allowed_events 必须是字符串数组")
    if not isinstance(managed_only_raw, list) or not all(
        isinstance(item, str) for item in managed_only_raw
    ):
        raise ValueError("_org_skills.managed_only_events 必须是字符串数组")
    return set(allowed_raw), set(managed_only_raw)


def serialize_lines(lines: list[str]) -> str:
    """Serialize TOML lines with exactly one trailing newline when non-empty."""
    if not lines:
        return ""
    return "\n".join(lines).rstrip("\n") + "\n"


def toml_string(value: str) -> str:
    """Encode a Python string as a TOML-compatible quoted string literal."""
    return json.dumps(value, ensure_ascii=False)
