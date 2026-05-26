#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shlex
import sys
from pathlib import Path
from typing import Any, NoReturn


REQUIRED_SCRIPT_FIELDS = {
    "id": str,
    "path": str,
    "owner": str,
    "allowed_args": list,
    "denied_args": list,
    "external_commands": list,
    "timeout_seconds": int,
    "output_limit_bytes": int,
    "allowed_input_roots": list,
    "failure_state": str,
    "exit_code_meanings": dict,
    "shell_parameter_strategy": str,
    "verification_command": str,
}
OPTIONAL_SCRIPT_FIELDS = {
    "output_root": str,
    "allowed_output_roots": list,
    "failure_message": str,
}
REQUIRED_DENIED_ARGS = {"--exec", "--shell", "--network", ";", "&&", "|"}
VERIFICATION_PATH_PREFIXES = ("tests/", "shared/skills/", "tools/")


class ManifestError(ValueError):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    return parser.parse_args()


def fail(message: str) -> NoReturn:
    raise ManifestError(message)


def load_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"invalid json: {exc}")
    if not isinstance(data, dict):
        fail("manifest root must be an object")
    return data


def assert_field_types(script: dict[str, Any]) -> None:
    script_id = script.get("id", "<unknown>")
    for field, expected_type in REQUIRED_SCRIPT_FIELDS.items():
        if field not in script:
            fail(f"script {script_id}: missing required field {field}")
        if type(script[field]) is not expected_type:
            fail(f"script {script_id}: {field} must be {expected_type.__name__}")
    for field, expected_type in OPTIONAL_SCRIPT_FIELDS.items():
        if field in script and type(script[field]) is not expected_type:
            fail(f"script {script_id}: {field} must be {expected_type.__name__}")


def assert_string_list(
    script: dict[str, Any], field: str, *, allow_empty: bool = True
) -> None:
    value = script[field]
    script_id = script["id"]
    if not allow_empty and not value:
        fail(f"script {script_id}: {field} must not be empty")
    if any(not isinstance(item, str) or not item for item in value):
        fail(f"script {script_id}: {field} entries must be non-empty strings")


def assert_lists(script: dict[str, Any]) -> None:
    for field in ("allowed_args", "denied_args", "external_commands"):
        assert_string_list(script, field, allow_empty=False)
    assert_string_list(script, "allowed_input_roots")
    if "allowed_output_roots" in script:
        assert_string_list(script, "allowed_output_roots")


def assert_path_inside_skill(skill_dir: Path, script: dict[str, Any]) -> None:
    script_path = script["path"]
    if script_path.startswith("/") or ".." in Path(script_path).parts:
        fail(f"script {script['id']}: path must stay inside skill directory")
    if not (skill_dir / script_path).is_file():
        fail(f"script {script['id']}: missing script file {script_path}")


def assert_numbers(script: dict[str, Any]) -> None:
    for field in ("timeout_seconds", "output_limit_bytes"):
        if script[field] <= 0:
            fail(f"script {script['id']}: {field} must be positive")


def assert_exit_codes(script: dict[str, Any]) -> None:
    meanings = script["exit_code_meanings"]
    if "0" not in meanings:
        fail(f"script {script['id']}: exit_code_meanings must include 0")
    for key, value in meanings.items():
        if not isinstance(key, str) or not key.isdigit():
            fail(
                f"script {script['id']}: exit_code_meanings keys must be numeric strings"
            )
        if not isinstance(value, str) or not value:
            fail(
                f"script {script['id']}: exit_code_meanings values must be non-empty strings"
            )


def assert_denied_args(script: dict[str, Any]) -> None:
    missing = sorted(REQUIRED_DENIED_ARGS - set(script["denied_args"]))
    if missing:
        fail(f"script {script['id']}: denied_args missing {missing}")


def assert_verification_command(repo_root: Path, script: dict[str, Any]) -> None:
    command = script["verification_command"]
    if not command.strip():
        fail(f"script {script['id']}: verification_command must not be empty")
    try:
        words = shlex.split(command)
    except ValueError as exc:
        fail(f"script {script['id']}: invalid verification_command: {exc}")
    for word in words:
        if (
            word.startswith(VERIFICATION_PATH_PREFIXES)
            and not (repo_root / word).exists()
        ):
            fail(f"script {script['id']}: verification path does not exist: {word}")


def validate_script(repo_root: Path, skill_dir: Path, script: Any) -> None:
    if not isinstance(script, dict):
        fail("scripts entries must be objects")
    assert_field_types(script)
    assert_lists(script)
    assert_path_inside_skill(skill_dir, script)
    if script["owner"] != skill_dir.name:
        fail(f"script {script['id']}: owner must match skill directory")
    if not script["shell_parameter_strategy"].strip():
        fail(f"script {script['id']}: shell_parameter_strategy must not be empty")
    assert_numbers(script)
    assert_exit_codes(script)
    assert_denied_args(script)
    assert_verification_command(repo_root, script)


def validate_manifest(repo_root: Path, path: Path) -> list[str]:
    errors: list[str] = []
    try:
        data = load_json(path)
        if set(data) != {"schema_version", "scripts"}:
            fail("manifest root must contain only schema_version and scripts")
        if data["schema_version"] != "1.0.0":
            fail("schema_version must be 1.0.0")
        scripts = data["scripts"]
        if not isinstance(scripts, list) or not scripts:
            fail("scripts must be a non-empty list")
        validate_scripts(repo_root, path.parents[1], scripts)
    except ManifestError as exc:
        errors.append(f"{path}: {exc}")
    return errors


def validate_scripts(repo_root: Path, skill_dir: Path, scripts: list[Any]) -> None:
    seen_ids: set[str] = set()
    for script in scripts:
        validate_script(repo_root, skill_dir, script)
        script_id = script["id"]
        if script_id in seen_ids:
            fail(f"duplicate script id: {script_id}")
        seen_ids.add(script_id)


def main() -> int:
    args = parse_args()
    root = args.repo_root.resolve()
    manifests = sorted((root / "shared" / "skills").glob("*/scripts/manifest.json"))
    errors = [error for path in manifests for error in validate_manifest(root, path)]
    for error in errors:
        print(error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
