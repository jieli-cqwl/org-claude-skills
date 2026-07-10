#!/usr/bin/env python3
"""Strict schema-2 context snapshot validation and budget helpers."""

from __future__ import annotations

import hashlib
import hmac
import json
import re
from enum import Enum
from typing import Any


SCHEMA_VERSION = "2.0"
MAX_SNAPSHOT_BYTES = 64 * 1024
TASK_STATUSES = {"active", "blocked", "complete"}
TASK_FIELDS = {
    "task_status",
    "active_goal",
    "scope_boundary",
    "non_goals",
    "latest_user_correction",
    "current_phase",
    "current_plan",
    "completed_items",
    "pending_items",
    "blockers",
    "next_action",
}
RUNTIME_FIELDS = {
    "schema_version",
    "session_id",
    "turn_id",
    "revision",
    "base_revision",
    "cwd",
    "git_head",
    "last_user_prompt_hash",
    "created_at",
    "updated_at",
    "snapshot_sha256",
}

_TASK_STRING_FIELDS = {
    "active_goal",
    "scope_boundary",
    "current_phase",
    "next_action",
}
_TASK_LIST_FIELDS = {
    "non_goals",
    "current_plan",
    "completed_items",
    "pending_items",
    "blockers",
}
_BUILD_RUNTIME_FIELDS = {
    "session_id",
    "turn_id",
    "base_revision",
    "cwd",
    "git_head",
    "last_user_prompt_hash",
}
_SNAPSHOT_STRING_FIELDS = {
    "session_id",
    "turn_id",
    "cwd",
    "git_head",
    "created_at",
    "updated_at",
}
_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


class RecoveryStatus(str, Enum):
    READY = "READY"
    STALE = "STALE"
    INCOMPLETE = "INCOMPLETE"
    CORRUPT = "CORRUPT"
    UNRECOVERABLE = "UNRECOVERABLE"


class SnapshotValidationError(ValueError):
    """Raised when a task payload or full snapshot violates schema-2."""

    def __init__(self, field_errors: dict[str, str]):
        self.field_errors = dict(field_errors)
        message = "; ".join(
            f"{field}: {reason}" for field, reason in sorted(self.field_errors.items())
        )
        super().__init__(message or "invalid snapshot")


def canonical_json_bytes(value: object) -> bytes:
    """Return deterministic compact UTF-8 JSON for a JSON-compatible value."""
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")


def _add_missing_and_unknown_errors(
    payload: dict[str, Any], expected_fields: set[str], errors: dict[str, str]
) -> None:
    for field in sorted(expected_fields - set(payload)):
        errors[field] = "is required"
    for field in sorted(set(payload) - expected_fields):
        errors[field] = "is not allowed"


def _validate_string(
    field: str, value: object, errors: dict[str, str], *, allow_empty: bool = False
) -> None:
    if not isinstance(value, str):
        errors[field] = "must be a string"
    elif not allow_empty and not value.strip():
        errors[field] = "must not be empty"


def _validate_string_list(field: str, value: object, errors: dict[str, str]) -> None:
    if not isinstance(value, list):
        errors[field] = "must be a list"
        return
    for index, item in enumerate(value):
        if not isinstance(item, str):
            errors[f"{field}[{index}]"] = "must be a string"


def _validate_completed_items(value: object, errors: dict[str, str]) -> None:
    field = "completed_items"
    if not isinstance(value, list):
        errors[field] = "must be a list"
        return
    for index, item in enumerate(value):
        item_field = f"{field}[{index}]"
        if not isinstance(item, dict):
            errors[item_field] = "must be an object"
            continue
        expected = {"item", "evidence_refs", "no_external_evidence"}
        if "item" not in item:
            errors[f"{item_field}.item"] = "is required"
        else:
            _validate_string(f"{item_field}.item", item["item"], errors)
        if "evidence_refs" not in item:
            errors[f"{item_field}.evidence_refs"] = "is required"
        else:
            _validate_string_list(
                f"{item_field}.evidence_refs", item["evidence_refs"], errors
            )
        has_no_external_evidence = item.get("no_external_evidence")
        if has_no_external_evidence is not None and not isinstance(
            has_no_external_evidence, bool
        ):
            errors[f"{item_field}.no_external_evidence"] = "must be a boolean"
        evidence_refs = item.get("evidence_refs")
        if evidence_refs == [] and has_no_external_evidence is not True:
            errors[f"{item_field}.evidence_refs"] = (
                "must not be empty without no_external_evidence=true"
            )
        for key in sorted(set(item) - expected):
            errors[f"{item_field}.{key}"] = "is not allowed"


def _validate_task_fields(payload: object, errors: dict[str, str]) -> dict[str, object] | None:
    if not isinstance(payload, dict):
        errors["payload"] = "must be an object"
        return None

    _add_missing_and_unknown_errors(payload, TASK_FIELDS, errors)
    for field in _TASK_STRING_FIELDS:
        if field in payload:
            _validate_string(field, payload[field], errors)
    if "latest_user_correction" in payload:
        _validate_string(
            "latest_user_correction",
            payload["latest_user_correction"],
            errors,
            allow_empty=True,
        )
    for field in _TASK_LIST_FIELDS - {"completed_items"}:
        if field in payload:
            _validate_string_list(field, payload[field], errors)
    if "completed_items" in payload:
        _validate_completed_items(payload["completed_items"], errors)
    if payload.get("task_status") not in TASK_STATUSES:
        errors["task_status"] = "must be one of active, blocked, complete"
    if payload.get("task_status") == "blocked" and not payload.get("blockers"):
        errors["blockers"] = "must contain at least one blocker when task_status is blocked"

    return dict(payload)


def _add_size_error(value: object, errors: dict[str, str]) -> None:
    try:
        size = len(canonical_json_bytes(value))
    except (TypeError, ValueError):
        errors["snapshot"] = "must be JSON-serializable"
        return
    if size > MAX_SNAPSHOT_BYTES:
        errors["snapshot"] = f"serialized snapshot exceeds {MAX_SNAPSHOT_BYTES} bytes"


def validate_task_payload(payload: object) -> dict[str, object]:
    """Validate one complete model-authored task payload without merge semantics."""
    errors: dict[str, str] = {}
    normalized = _validate_task_fields(payload, errors)
    if normalized is not None:
        _add_size_error(normalized, errors)
    if errors:
        raise SnapshotValidationError(errors)
    return normalized or {}


def _validate_nonnegative_int(field: str, value: object, errors: dict[str, str]) -> None:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        errors[field] = "must be a non-negative integer"


def _validate_runtime_for_build(runtime: object, errors: dict[str, str]) -> dict[str, object] | None:
    if not isinstance(runtime, dict):
        errors["runtime"] = "must be an object"
        return None
    _add_missing_and_unknown_errors(runtime, _BUILD_RUNTIME_FIELDS, errors)
    for field in _BUILD_RUNTIME_FIELDS - {"base_revision", "last_user_prompt_hash"}:
        if field in runtime:
            _validate_string(field, runtime[field], errors)
    if "base_revision" in runtime:
        _validate_nonnegative_int("base_revision", runtime["base_revision"], errors)
    if "last_user_prompt_hash" in runtime:
        value = runtime["last_user_prompt_hash"]
        if not isinstance(value, str) or not _SHA256_RE.fullmatch(value):
            errors["last_user_prompt_hash"] = "must be a lowercase SHA-256 hex digest"
    return dict(runtime)


def _snapshot_hash(snapshot: dict[str, object]) -> str:
    # The checksum cannot include itself or no value could verify deterministically.
    hashed = {key: value for key, value in snapshot.items() if key != "snapshot_sha256"}
    return hashlib.sha256(canonical_json_bytes(hashed)).hexdigest()


def build_snapshot(
    task: object,
    runtime: object,
    revision: object,
    created_at: object,
    updated_at: object,
) -> dict[str, object]:
    """Build a complete, checksum-protected schema-2 snapshot."""
    errors: dict[str, str] = {}
    normalized_task = _validate_task_fields(task, errors)
    normalized_runtime = _validate_runtime_for_build(runtime, errors)
    _validate_nonnegative_int("revision", revision, errors)
    _validate_string("created_at", created_at, errors)
    _validate_string("updated_at", updated_at, errors)
    if errors:
        raise SnapshotValidationError(errors)

    snapshot: dict[str, object] = {
        **(normalized_task or {}),
        "schema_version": SCHEMA_VERSION,
        **(normalized_runtime or {}),
        "revision": revision,
        "created_at": created_at,
        "updated_at": updated_at,
    }
    snapshot["snapshot_sha256"] = _snapshot_hash(snapshot)
    _add_size_error(snapshot, errors)
    if errors:
        raise SnapshotValidationError(errors)
    return snapshot


def _validate_full_snapshot(snapshot: object, errors: dict[str, str]) -> dict[str, object] | None:
    if not isinstance(snapshot, dict):
        errors["snapshot"] = "must be an object"
        return None
    expected_fields = TASK_FIELDS | RUNTIME_FIELDS
    _add_missing_and_unknown_errors(snapshot, expected_fields, errors)
    normalized = _validate_task_fields(
        {field: snapshot[field] for field in TASK_FIELDS if field in snapshot}, errors
    )
    for field in _SNAPSHOT_STRING_FIELDS:
        if field in snapshot:
            _validate_string(field, snapshot[field], errors)
    if "schema_version" in snapshot and snapshot["schema_version"] != SCHEMA_VERSION:
        errors["schema_version"] = f"must equal {SCHEMA_VERSION}"
    for field in ("revision", "base_revision"):
        if field in snapshot:
            _validate_nonnegative_int(field, snapshot[field], errors)
    for field in ("last_user_prompt_hash", "snapshot_sha256"):
        if field in snapshot:
            value = snapshot[field]
            if not isinstance(value, str) or not _SHA256_RE.fullmatch(value):
                errors[field] = "must be a lowercase SHA-256 hex digest"
    _add_size_error(snapshot, errors)
    return normalized


def verify_snapshot(snapshot: object) -> dict[str, object]:
    """Validate a complete snapshot and verify its canonical-content checksum."""
    errors: dict[str, str] = {}
    _validate_full_snapshot(snapshot, errors)
    if isinstance(snapshot, dict) and isinstance(snapshot.get("snapshot_sha256"), str):
        expected_hash = _snapshot_hash(snapshot)
        if not hmac.compare_digest(snapshot["snapshot_sha256"], expected_hash):
            errors["snapshot_sha256"] = "does not match canonical snapshot content"
    if errors:
        raise SnapshotValidationError(errors)
    return dict(snapshot) if isinstance(snapshot, dict) else {}


def evaluate_snapshot(
    snapshot: object, runtime_identity: object
) -> tuple[RecoveryStatus, str]:
    """Classify a snapshot against the current runtime identity."""
    if snapshot is None:
        return RecoveryStatus.INCOMPLETE, "no snapshot is available"
    try:
        verified = verify_snapshot(snapshot)
    except SnapshotValidationError as exc:
        return RecoveryStatus.CORRUPT, str(exc)
    if not isinstance(runtime_identity, dict):
        return RecoveryStatus.UNRECOVERABLE, "runtime identity must be an object"

    identity_fields = {
        "session_id",
        "turn_id",
        "revision",
        "base_revision",
        "cwd",
        "git_head",
        "last_user_prompt_hash",
    }
    supplied_fields = identity_fields & set(runtime_identity)
    if not supplied_fields:
        return RecoveryStatus.UNRECOVERABLE, "runtime identity has no comparable fields"
    for field in sorted(supplied_fields):
        if runtime_identity[field] != verified[field]:
            return RecoveryStatus.STALE, f"snapshot {field} does not match runtime identity"
    return RecoveryStatus.READY, "snapshot matches runtime identity"


def estimate_tokens(text: str) -> int:
    """Conservatively estimate tokens without splitting Unicode code points."""
    tokens = 0
    ascii_run = 0
    for character in text:
        if character.isspace():
            ascii_run = 0
        elif ord(character) < 128:
            ascii_run += 1
            if ascii_run % 3 == 1:
                tokens += 1
        else:
            ascii_run = 0
            tokens += 1
    return tokens


def bounded_text(text: str, byte_limit: int, token_limit: int) -> tuple[str, bool]:
    """Return the longest prefix that fits both serialized recovery budgets."""
    if byte_limit < 0 or token_limit < 0:
        raise ValueError("byte_limit and token_limit must be non-negative")

    bytes_used = 0
    tokens_used = 0
    ascii_run = 0
    end = 0
    for index, character in enumerate(text):
        character_bytes = len(character.encode("utf-8"))
        next_ascii_run = ascii_run
        next_tokens = tokens_used
        if character.isspace():
            next_ascii_run = 0
        elif ord(character) < 128:
            next_ascii_run += 1
            if next_ascii_run % 3 == 1:
                next_tokens += 1
        else:
            next_ascii_run = 0
            next_tokens += 1
        if bytes_used + character_bytes > byte_limit or next_tokens > token_limit:
            break
        bytes_used += character_bytes
        tokens_used = next_tokens
        ascii_run = next_ascii_run
        end = index + 1
    return text[:end], end != len(text)
