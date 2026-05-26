#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


REQUIRED_SCRIPT_FIELDS = {
    "id": str,
    "path": str,
    "owner": str,
    "allowed_args": list,
    "denied_args": list,
    "external_commands": list,
    "timeout_seconds": int,
    "output_limit_bytes": int,
    "failure_state": str,
}
OPTIONAL_SCRIPT_FIELDS = {
    "output_root": str,
    "allowed_output_roots": list,
    "allowed_input_roots": list,
    "failure_message": str,
    "exit_code_meanings": dict,
    "shell_parameter_strategy": str,
    "verification_command": str,
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    return parser.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"invalid json: {exc}") from exc
    if not isinstance(data, dict):
        raise ValueError("manifest root must be an object")
    return data


def require_string_list(script: dict[str, Any], field: str) -> None:
    value = script.get(field)
    if not isinstance(value, list):
        raise ValueError(
            f"script {script.get('id', '<unknown>')}: {field} must be a list"
        )
    if any(not isinstance(item, str) or not item for item in value):
        raise ValueError(
            f"script {script.get('id', '<unknown>')}: {field} entries must be non-empty strings"
        )


def validate_script(skill_dir: Path, script: Any) -> None:
    if not isinstance(script, dict):
        raise ValueError("scripts entries must be objects")

    for field, expected_type in REQUIRED_SCRIPT_FIELDS.items():
        value = script.get(field)
        if not isinstance(value, expected_type):
            raise ValueError(
                f"script {script.get('id', '<unknown>')}: {field} must be {expected_type.__name__}"
            )
    for field, expected_type in OPTIONAL_SCRIPT_FIELDS.items():
        if field in script and not isinstance(script[field], expected_type):
            raise ValueError(
                f"script {script.get('id', '<unknown>')}: {field} must be {expected_type.__name__}"
            )

    for field in (
        "allowed_args",
        "denied_args",
        "external_commands",
    ):
        require_string_list(script, field)
    for field in ("allowed_output_roots", "allowed_input_roots"):
        if field in script:
            require_string_list(script, field)

    script_path = script["path"]
    if script_path.startswith("/") or ".." in Path(script_path).parts:
        raise ValueError(
            f"script {script['id']}: path must stay inside skill directory"
        )
    if not (skill_dir / script_path).is_file():
        raise ValueError(f"script {script['id']}: missing script file {script_path}")
    if script["owner"] != skill_dir.name:
        raise ValueError(f"script {script['id']}: owner must match skill directory")
    if script["timeout_seconds"] <= 0:
        raise ValueError(f"script {script['id']}: timeout_seconds must be positive")
    if script["output_limit_bytes"] <= 0:
        raise ValueError(f"script {script['id']}: output_limit_bytes must be positive")

    meanings = script.get("exit_code_meanings")
    if meanings is not None and (
        not meanings
        or any(
            not str(key).isdigit() or not isinstance(value, str) or not value
            for key, value in meanings.items()
        )
    ):
        raise ValueError(
            f"script {script['id']}: exit_code_meanings must map exit codes to descriptions"
        )


def validate_manifest(path: Path) -> list[str]:
    errors: list[str] = []
    try:
        data = load_json(path)
        schema_version = data.get("schema_version")
        if schema_version not in (None, "1.0.0"):
            raise ValueError("schema_version must be 1.0.0 when present")
        scripts = data.get("scripts")
        if isinstance(scripts, dict):
            return []
        if scripts is None and "entrypoint" in data:
            entrypoint = data["entrypoint"]
            if not isinstance(entrypoint, str):
                raise ValueError("entrypoint must be string")
            if entrypoint.startswith("/") or ".." in Path(entrypoint).parts:
                raise ValueError("entrypoint must stay inside skill directory")
            if not (path.parents[1] / entrypoint).is_file():
                raise ValueError(f"missing entrypoint file {entrypoint}")
            return []
        if not isinstance(scripts, list) or not scripts:
            raise ValueError("scripts must be a non-empty list")
        seen_ids: set[str] = set()
        for script in scripts:
            validate_script(path.parents[1], script)
            script_id = script["id"]
            if script_id in seen_ids:
                raise ValueError(f"duplicate script id: {script_id}")
            seen_ids.add(script_id)
    except ValueError as exc:
        errors.append(f"{path}: {exc}")
    return errors


def main() -> int:
    args = parse_args()
    root = args.repo_root.resolve()
    manifests = sorted((root / "shared" / "skills").glob("*/scripts/manifest.json"))
    errors: list[str] = []
    for path in manifests:
        errors.extend(validate_manifest(path))
    for error in errors:
        print(error, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
