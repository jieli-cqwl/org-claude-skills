#!/usr/bin/env python3
"""Validate the skill-optimizer script execution manifest."""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


REQUIRED_FIELDS = {
    "id",
    "path",
    "allowed_args",
    "denied_args",
    "external_commands",
    "timeout_seconds",
    "output_limit_bytes",
    "exit_code_meanings",
    "shell_parameter_strategy",
    "allowed_output_roots",
    "failure_message",
    "verification_command",
}
VERIFY_COMMAND_PREFIX = "bash tests/test-skill-optimizer-"
VERIFY_COMMAND_SUFFIX = ".sh"
FORBIDDEN_COMMAND_TOKENS = {";", "&&", "|", "`", "$(", "\n", "\r"}


def fail(message: str) -> None:
    """Print a stable validation failure and exit nonzero."""
    print(f"[FAIL] {message}", file=sys.stderr)
    raise SystemExit(1)


def load_json(path: Path) -> dict[str, Any]:
    """Load a manifest JSON object from disk."""
    try:
        with path.open(encoding="utf-8") as handle:
            data = json.load(handle)
    except FileNotFoundError:
        fail(f"file not found: {path}")
    except json.JSONDecodeError as exc:
        fail(f"invalid JSON in {path}: {exc}")
    if not isinstance(data, dict):
        fail(f"top-level JSON must be object: {path}")
    return data


def require_string(entry: dict[str, Any], field: str, label: str) -> str:
    """Return a nonempty string field or fail with the script label."""
    value = entry.get(field)
    if not isinstance(value, str) or not value.strip():
        fail(f"{label} invalid {field}")
    return value


def require_string_list(entry: dict[str, Any], field: str, label: str, *, nonempty: bool) -> list[str]:
    """Return a string list field or fail with the script label."""
    value = entry.get(field)
    if not isinstance(value, list) or (nonempty and not value):
        fail(f"{label} invalid {field}")
    if any(not isinstance(item, str) or not item.strip() for item in value):
        fail(f"{label} invalid {field} item")
    return value


def require_positive_int(entry: dict[str, Any], field: str, label: str) -> int:
    """Return a positive integer field or fail with the script label."""
    value = entry.get(field)
    if not isinstance(value, int) or value <= 0:
        fail(f"{label} invalid {field}")
    return value


def validate_exit_codes(entry: dict[str, Any], label: str) -> None:
    """Validate exit-code meanings include success and failure paths."""
    meanings = entry.get("exit_code_meanings")
    if not isinstance(meanings, dict) or not meanings:
        fail(f"{label} invalid exit_code_meanings")
    if "0" not in meanings:
        fail(f"{label} exit_code_meanings missing 0")
    nonzero = [code for code in meanings if code != "0"]
    if not nonzero:
        fail(f"{label} exit_code_meanings missing nonzero code")
    for code, meaning in meanings.items():
        if not code.isdigit() or not isinstance(meaning, str) or not meaning.strip():
            fail(f"{label} invalid exit_code_meanings item")


def validate_verification_command(command: str, label: str) -> None:
    """Constrain proof commands to the skill-optimizer test harness."""
    if any(token in command for token in FORBIDDEN_COMMAND_TOKENS):
        fail(f"{label} verification_command contains forbidden token")
    if not command.startswith(VERIFY_COMMAND_PREFIX) or not command.endswith(VERIFY_COMMAND_SUFFIX):
        fail(f"{label} verification_command must use skill-optimizer bash tests")


def validate_output_roots(roots: list[str], label: str) -> None:
    """Validate declared output roots cannot escape through absolute or parent paths."""
    for root in roots:
        if root.startswith("/"):
            fail(f"{label} allowed_output_roots must not use absolute paths")
        parts = Path(root).parts
        if ".." in parts:
            fail(f"{label} allowed_output_roots must not contain parent traversal")


def validate_script_path(raw_path: str, label: str, skill_dir: Path) -> None:
    """Require manifest paths to stay inside the Skill scripts directory."""
    path = Path(raw_path)
    if path.is_absolute():
        fail(f"{label} path must be relative")
    scripts_dir = (skill_dir / "scripts").resolve()
    script_path = (skill_dir / path).resolve()
    try:
        script_path.relative_to(scripts_dir)
    except ValueError:
        fail(f"{label} path escapes scripts directory")
    if not script_path.is_file():
        fail(f"{label} path does not exist: {raw_path}")


def validate_script(entry: Any, index: int, seen_ids: set[str], skill_dir: Path) -> None:
    """Validate one manifest script entry."""
    if not isinstance(entry, dict):
        fail(f"script[{index}] must be object")
    label = f"script[{index}]"
    missing = sorted(REQUIRED_FIELDS - set(entry))
    if missing:
        fail(f"{label} missing fields: {', '.join(missing)}")
    script_id = require_string(entry, "id", label)
    if script_id in seen_ids:
        fail(f"{label} duplicate id: {script_id}")
    seen_ids.add(script_id)
    raw_path = require_string(entry, "path", label)
    require_string_list(entry, "allowed_args", label, nonempty=True)
    require_string_list(entry, "denied_args", label, nonempty=True)
    require_string_list(entry, "external_commands", label, nonempty=True)
    require_positive_int(entry, "timeout_seconds", label)
    require_positive_int(entry, "output_limit_bytes", label)
    output_roots = require_string_list(entry, "allowed_output_roots", label, nonempty=False)
    require_string(entry, "failure_message", label)
    validate_output_roots(output_roots, label)
    validate_exit_codes(entry, label)
    strategy = require_string(entry, "shell_parameter_strategy", label)
    if "argv" not in strategy:
        fail(f"{label} shell_parameter_strategy must use argv")
    validate_verification_command(require_string(entry, "verification_command", label), label)
    validate_script_path(raw_path, label, skill_dir)


def validate_manifest(manifest: dict[str, Any], manifest_path: Path) -> None:
    """Validate manifest shape and every script execution contract."""
    if manifest.get("schema_version") != "1.0.0":
        fail("schema_version must be 1.0.0")
    scripts = manifest.get("scripts")
    if not isinstance(scripts, list) or not scripts:
        fail("scripts must be a nonempty list")
    seen_ids: set[str] = set()
    skill_dir = manifest_path.parent.parent.resolve()
    for index, entry in enumerate(scripts):
        validate_script(entry, index, seen_ids, skill_dir)


def main(argv: list[str]) -> None:
    """Run manifest validation from the command line."""
    if len(argv) != 2:
        fail("usage: validate_manifest.py <manifest.json>")
    manifest_path = Path(argv[1]).resolve()
    validate_manifest(load_json(manifest_path), manifest_path)


if __name__ == "__main__":
    main(sys.argv)
