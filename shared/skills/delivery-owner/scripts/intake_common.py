from __future__ import annotations

import json
from json import JSONDecodeError
from pathlib import Path
from typing import Any


class IntakeFailure(Exception):
    def __init__(
        self,
        code: str,
        decision: str,
        owner: str,
        reason: str,
        missing_inputs: list[str] | None = None,
    ) -> None:
        super().__init__(reason)
        self.code = code
        self.decision = decision
        self.owner = owner
        self.reason = reason
        self.missing_inputs = missing_inputs or []


def load_json(path: Path, missing_name: str) -> dict[str, Any]:
    if not path.is_file():
        raise IntakeFailure(
            "MISSING_INPUT",
            "NEEDS_INPUT",
            "delivery-owner",
            f"missing required file: {path}",
            [missing_name],
        )
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except JSONDecodeError as exc:
        raise IntakeFailure(
            "INVALID_JSON",
            "NEEDS_INPUT",
            "delivery-owner",
            f"malformed JSON: {path}: {exc}",
            [missing_name],
        ) from exc
    if not isinstance(payload, dict):
        raise IntakeFailure(
            "INVALID_JSON",
            "NEEDS_INPUT",
            "delivery-owner",
            f"top-level JSON must be an object: {path}",
            [missing_name],
        )
    return payload


def nonempty_strings(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, str) and item.strip()]
