#!/usr/bin/env python3
"""Validate a standard-chain harness episode package."""

from __future__ import annotations

import argparse
import json
import sys
from collections.abc import Iterable
from json import JSONDecodeError
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from simple_json_schema import SimpleSchemaValidator, SimpleValidationError  # noqa: E402

try:
    from jsonschema import Draft202012Validator
except ModuleNotFoundError:
    Draft202012Validator = None


ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = ROOT / "contracts/episode-package.schema.json"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, required=True)
    return parser.parse_args(argv)


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ValueError(f"missing JSON file: {path}") from exc
    except JSONDecodeError as exc:
        raise ValueError(f"malformed JSON: {path}: {exc}") from exc


def format_path(parts: Iterable[int | str]) -> str:
    path = "$"
    for part in parts:
        if isinstance(part, int):
            path += f"[{part}]"
        else:
            path += f".{part}"
    return path


def schema_errors(payload: Any, schema: dict[str, Any]) -> list[str]:
    if Draft202012Validator is None:
        try:
            SimpleSchemaValidator({schema["$id"]: schema}).validate(payload, schema)
        except SimpleValidationError as exc:
            return [str(exc).replace("$.", "")]
        return []
    validator = Draft202012Validator(schema)
    errors: list[str] = []
    for error in sorted(
        validator.iter_errors(payload), key=lambda item: list(item.path)
    ):
        path = format_path(error.path).replace("$.", "")
        if error.validator == "required":
            missing = str(error.message).split("'")[1]
            path = f"{path}.{missing}" if path != "$" else missing
        errors.append(f"{path}: {error.message}")
    return errors


def string_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, str) and item]


def semantic_errors(payload: Any) -> list[str]:
    if not isinstance(payload, dict):
        return ["$: episode package must be a JSON object"]
    errors: list[str] = []
    errors.extend(episode_id_errors(payload))
    errors.extend(failure_attribution_errors(payload))
    errors.extend(verification_errors(payload))
    return errors


def episode_id_errors(payload: dict[str, Any]) -> list[str]:
    role = payload.get("role")
    episode_id = payload.get("episode_id")
    if not isinstance(role, str) or not isinstance(episode_id, str):
        return []
    expected_prefix = f"{role}:"
    if episode_id.startswith(expected_prefix):
        return []
    return [f"episode_id: must start with {expected_prefix}"]


def failure_attribution_errors(payload: dict[str, Any]) -> list[str]:
    failure = payload.get("failure_attribution")
    if not isinstance(failure, dict):
        return []
    status = failure.get("status")
    category = failure.get("category")
    evidence_refs = string_list(failure.get("evidence_refs"))
    if status == "none":
        return no_failure_errors(category, evidence_refs)
    if status in {"observed", "blocked"}:
        return active_failure_errors(category, evidence_refs)
    return []


def no_failure_errors(category: Any, evidence_refs: list[str]) -> list[str]:
    errors: list[str] = []
    if category != "none":
        errors.append(
            "failure_attribution.category: none status requires none category"
        )
    if evidence_refs:
        errors.append(
            "failure_attribution.evidence_refs: none status must not carry failure evidence"
        )
    return errors


def active_failure_errors(category: Any, evidence_refs: list[str]) -> list[str]:
    errors: list[str] = []
    if category == "none":
        errors.append(
            "failure_attribution.category: observed or blocked status requires a failure category"
        )
    if not evidence_refs:
        errors.append(
            "failure_attribution.evidence_refs: observed or blocked status requires evidence"
        )
    return errors


def verification_errors(payload: dict[str, Any]) -> list[str]:
    verification = payload.get("verification")
    if not isinstance(verification, dict):
        return []
    errors: list[str] = []
    if verification.get("default_fail") is not True:
        errors.append("verification.default_fail: must be true")
    if not string_list(verification.get("evidence_refs")):
        errors.append(
            "verification.evidence_refs: must contain current verification evidence"
        )
    errors.extend(proving_commands_errors(verification))
    return errors


def proving_commands_errors(verification: dict[str, Any]) -> list[str]:
    commands = verification.get("proving_commands")
    if not isinstance(commands, list) or not commands:
        return ["verification.proving_commands: must contain at least one command"]
    errors: list[str] = []
    for index, command in enumerate(commands):
        errors.extend(
            proving_command_errors(index, command, verification.get("result"))
        )
    return errors


def proving_command_errors(
    index: int, command: Any, verification_result: Any
) -> list[str]:
    if not isinstance(command, dict):
        return [f"verification.proving_commands[{index}]: must be an object"]
    errors: list[str] = []
    if not command.get("current_output_ref"):
        errors.append(
            f"verification.proving_commands[{index}].current_output_ref: must point to current output evidence"
        )
    if verification_result == "pass" and command.get("result") != "pass":
        errors.append(
            f"verification.proving_commands[{index}].result: pass package cannot cite non-pass command result"
        )
    return errors


def validate(package_path: Path) -> tuple[bool, dict[str, Any]]:
    schema = load_json(SCHEMA_PATH)
    payload = load_json(package_path)
    errors = schema_errors(payload, schema) + semantic_errors(payload)
    if errors:
        return False, {
            "status": "FAIL",
            "package": str(package_path),
            "errors": sorted(set(errors)),
        }
    return True, {
        "status": "PASS",
        "package": str(package_path),
        "episode_id": payload["episode_id"],
    }


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        ok, result = validate(args.package)
    except Exception as exc:
        ok = False
        result = {
            "status": "FAIL",
            "package": str(args.package),
            "errors": [str(exc)],
        }
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
