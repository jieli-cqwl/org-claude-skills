from __future__ import annotations

import json
from json import JSONDecodeError
from pathlib import Path
from typing import Any


class PreflightFailure(Exception):
    def __init__(
        self, code: str, reason: str, missing: list[str] | None = None
    ) -> None:
        super().__init__(reason)
        self.code = code
        self.reason = reason
        self.missing = missing or []


def load_json(path: Path, missing_name: str) -> dict[str, Any]:
    if not path.is_file():
        raise PreflightFailure(
            "MISSING_INPUT", f"missing required file: {path}", [missing_name]
        )
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except JSONDecodeError as exc:
        raise PreflightFailure(
            "INVALID_JSON", f"malformed JSON: {path}: {exc}", [missing_name]
        ) from exc
    if not isinstance(payload, dict):
        raise PreflightFailure(
            "SCHEMA_FAILURE",
            f"top-level JSON must be an object: {path}",
            [missing_name],
        )
    return payload
