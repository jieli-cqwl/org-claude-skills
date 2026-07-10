#!/usr/bin/env python3
"""Turn-bound schema-2 context continuity hook and state-update CLI."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

from codex_context_model import (
    MAX_SNAPSHOT_BYTES,
    RecoveryStatus,
    SCHEMA_VERSION,
    SnapshotValidationError,
    evaluate_snapshot,
    validate_task_payload,
)
from codex_context_store import (
    IntegrityError,
    RetentionPolicy,
    RevisionConflict,
    SessionStore,
    StoreError,
    _validate_session_id,
    prune_state_root,
)


DEFAULT_PROMPT_PREVIEW_CHARS = 240
MAX_PROMPT_PREVIEW_CHARS = 1024
SECRET_REDACTION_LOOKAHEAD_CHARS = 4096
MAX_HOOK_PAYLOAD_BYTES = 1024 * 1024
MAX_RECOVERY_OUTPUT_BYTES = 4 * 1024
GIT_TIMEOUT_SECONDS = 5.0
NOT_A_GIT_REPOSITORY = "not-a-git-repository"
RECOVERY_CARD_SCHEMA_VERSION = "1.0"
RECOVERY_REQUIRED_FIELDS = (
    "active_goal",
    "scope_boundary",
    "current_phase",
    "completed_items",
    "evidence_refs",
    "pending_items",
    "next_action",
)
STOP_REASON = (
    "Context snapshot is not READY for this turn. Run the exact state-update "
    "command from the latest continuity context before finishing."
)
_UPDATE_FIELDS = {"session_id", "turn_id", "base_revision", "task"}
_HEX_GIT_HEAD_RE = re.compile(r"^[0-9a-fA-F]{40,64}$")
_SECRET_PATTERNS = (
    re.compile(
        r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----[\s\S]*?"
        r"(?:-----END [A-Z0-9 ]*PRIVATE KEY-----|$)"
    ),
    re.compile(r"\bsk-(?:proj-)?[A-Za-z0-9_-]{16,}\b"),
    re.compile(r"\bgh[pousr]_[A-Za-z0-9_]{16,}\b"),
    re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}\b"),
    re.compile(r"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{4,}\b"),
    re.compile(r"(?i)\bbearer\s+[A-Za-z0-9._~+/=-]{12,}"),
    re.compile(
        r"(?i)\b(?:secret|token|password|passwd|api[_-]?key|access[_-]?key)"
        r"\s*[:=]\s*[^\s,;]{4,}"
    ),
)


class LifecycleInputError(ValueError):
    """Raised when hook or CLI input violates the lifecycle contract."""


class GitStateError(RuntimeError):
    """Raised when current Git identity cannot be determined safely."""


def state_root() -> Path:
    override = os.environ.get("ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR")
    if override:
        return Path(override).expanduser()
    return Path.home() / ".codex" / "hooks" / "state" / "context-continuity"


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace(
        "+00:00", "Z"
    )


def _write_json(path: Path, payload: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temporary.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    try:
        temporary.chmod(0o600)
    except OSError:
        pass
    temporary.replace(path)


def _recovery_state_path(session_id: str) -> Path:
    return state_root() / f"{session_id}.json"


def _new_recovery_state(session_id: str) -> dict[str, object]:
    now = utc_now()
    return {
        "schema_version": RECOVERY_CARD_SCHEMA_VERSION,
        "session_id": session_id,
        "created_at": now,
        "updated_at": now,
        "last_user_prompt_hash": "",
        "last_user_prompt_preview": "",
        "current_turn_id": "",
        "active_goal": "",
        "scope_boundary": "",
        "non_goals": [],
        "latest_user_correction": "",
        "current_phase": "",
        "current_plan": [],
        "completed_items": [],
        "evidence_refs": [],
        "pending_items": [],
        "blockers": [],
        "next_action": "",
        "git_head": "",
        "truth_policy": "恢复时优先读取 task_state_ref 和证据引用；证据不足必须报告 blocked，禁止猜测。",
        "recovery_status": "INCOMPLETE",
        "recovery_action_required": True,
        "allowed_next_step": "READ_ONLY_RECOVERY",
        "last_stop": {},
        "precompact": {},
        "postcompact": {},
        "state_updates": [],
    }


def _load_recovery_state(session_id: str) -> dict[str, object]:
    path = _recovery_state_path(session_id)
    if not path.exists():
        return _new_recovery_state(session_id)
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise StoreError("recovery state card is unreadable") from exc
    if not isinstance(value, dict) or value.get("session_id") != session_id:
        raise IntegrityError("recovery state card identity is invalid")
    state = _new_recovery_state(session_id)
    state.update(value)
    return state


def _save_recovery_state(session_id: str, state: dict[str, object]) -> None:
    state["schema_version"] = RECOVERY_CARD_SCHEMA_VERSION
    state["session_id"] = session_id
    state["updated_at"] = utc_now()
    candidate_turn_at = state.get("pending_turn_updated_at")
    path = _recovery_state_path(session_id)
    if path.exists() and isinstance(candidate_turn_at, str):
        try:
            existing = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            existing = None
        existing_turn_at = (
            existing.get("pending_turn_updated_at")
            if isinstance(existing, dict)
            else None
        )
        if isinstance(existing_turn_at, str) and existing_turn_at > candidate_turn_at:
            return
    _write_json(path, state)


def _validated_session_id(payload: dict[str, object]) -> str:
    session_id = _required_text(payload, "session_id", maximum=128)
    try:
        return _validate_session_id(session_id)
    except StoreError as exc:
        raise LifecycleInputError(str(exc)) from None


def _prompt_from_payload(payload: dict[str, object]) -> str:
    value = payload.get("user_prompt")
    if not isinstance(value, str) or not value:
        value = payload.get("prompt")
    if not isinstance(value, str) or not value:
        raise LifecycleInputError("user_prompt must be a non-empty bounded string")
    if len(value.encode("utf-8")) > MAX_HOOK_PAYLOAD_BYTES:
        raise LifecycleInputError("user_prompt exceeds its bounded size")
    return value


def _record_prompt_in_state(
    state: dict[str, object],
    prompt: str,
    turn_id: str,
    cwd: str,
    transcript_path: str,
    pending_turn_updated_at: str,
) -> None:
    state["last_user_prompt_hash"] = sha256_text(prompt)
    state["last_user_prompt_preview"] = redacted_prompt_preview(prompt)
    state["last_user_prompt_length"] = len(prompt)
    state["last_user_prompt_truncated"] = len(prompt) > prompt_preview_limit()
    state["current_turn_id"] = turn_id
    state["cwd"] = cwd
    state["transcript_path"] = transcript_path
    state["pending_turn_updated_at"] = pending_turn_updated_at
    state["recovery_status"] = "INCOMPLETE"
    state["recovery_action_required"] = True
    state["allowed_next_step"] = "READ_ONLY_RECOVERY"


def _record_stop_in_state(state: dict[str, object], payload: dict[str, object]) -> None:
    state["last_stop"] = {
        "cwd": payload.get("cwd") or "",
        "transcript_path": payload.get("transcript_path") or payload.get("transcriptPath") or "",
        "turn_id": payload.get("turn_id") or "",
        "recorded_at": utc_now(),
    }


def _record_snapshot_in_state(
    state: dict[str, object],
    task: dict[str, object],
    pending: dict[str, object],
    snapshot: dict[str, object],
) -> None:
    completed: list[str] = []
    evidence: list[str] = []
    for item in task["completed_items"]:
        if isinstance(item, dict):
            if item.get("item"):
                completed.append(redact_secrets(str(item["item"])))
            refs = item.get("evidence_refs")
            if isinstance(refs, list):
                evidence.extend(redact_secrets(str(ref)) for ref in refs)
    state.update(
        {
            "active_goal": task["active_goal"],
            "scope_boundary": task["scope_boundary"],
            "non_goals": task["non_goals"],
            "latest_user_correction": task["latest_user_correction"],
            "current_phase": task["current_phase"],
            "current_plan": task["current_plan"],
            "completed_items": completed,
            "evidence_refs": evidence or [f"snapshot:{snapshot['snapshot_sha256']}"],
            "pending_items": task["pending_items"],
            "blockers": task["blockers"],
            "next_action": task["next_action"],
            "git_head": snapshot["git_head"],
            "current_turn_id": pending["turn_id"],
            "pending_turn_updated_at": pending["updated_at"],
            "recovery_status": "READY",
            "recovery_action_required": False,
            "allowed_next_step": "CONTINUE_FROM_STATE",
        }
    )
    update = {
        "recorded_at": utc_now(),
        "source": "state-update",
        "turn_id": pending["turn_id"],
        "base_revision": pending["base_revision"],
        "last_user_prompt_hash": pending["prompt_sha256"],
    }
    state["last_state_update"] = update
    updates = state.get("state_updates")
    if not isinstance(updates, list):
        updates = []
    state["state_updates"] = [*updates, update][-20:]


def _compact_value(value: object) -> str:
    if isinstance(value, str):
        return redact_secrets(value)[:320]
    if isinstance(value, list):
        values = [redact_secrets(str(item))[:180] for item in value[:3]]
        return " | ".join(values) if values else "none"
    return "<missing>"


def recovery_context(session_id: str, state: dict[str, object]) -> str:
    status = str(state.get("recovery_status") or "INCOMPLETE")
    missing = "none" if status == "READY" else ", ".join(
        field for field in RECOVERY_REQUIRED_FIELDS if not state.get(field)
    ) or "none"
    precompact = state.get("precompact") if isinstance(state.get("precompact"), dict) else {}
    postcompact = state.get("postcompact") if isinstance(state.get("postcompact"), dict) else {}
    last_stop = state.get("last_stop") if isinstance(state.get("last_stop"), dict) else {}
    transcript = last_stop.get("transcript_path") or state.get("transcript_path") or "missing"
    lines = [
        "[Codex context continuity recovery]",
        f"task_state_ref: {_recovery_state_path(session_id)}",
        f"precompact_checkpoint_ref: {precompact.get('checkpoint_ref') or 'missing'}",
        f"compact_summary_ref: {postcompact.get('compact_summary_ref') or 'missing'}",
        f"transcript_path: {transcript}",
        f"recovery_status: {status}",
        f"recovery_action_required: {'true' if state.get('recovery_action_required', True) else 'false'}",
        f"allowed_next_step: {state.get('allowed_next_step') or 'READ_ONLY_RECOVERY'}",
        f"recovery_missing_fields: {missing}",
        "恢复状态摘要:",
        f"active_goal: {_compact_value(state.get('active_goal'))}",
        f"scope_boundary: {_compact_value(state.get('scope_boundary'))}",
        f"latest_user_correction: {_compact_value(state.get('latest_user_correction'))}",
        f"current_phase: {_compact_value(state.get('current_phase'))}",
        f"current_plan: {_compact_value(state.get('current_plan'))}",
        f"completed_items: {_compact_value(state.get('completed_items'))}",
        f"evidence_refs: {_compact_value(state.get('evidence_refs'))}",
        f"pending_items: {_compact_value(state.get('pending_items'))}",
        f"blockers: {_compact_value(state.get('blockers'))}",
        f"next_action: {_compact_value(state.get('next_action'))}",
        "恢复步骤:",
        "1. 先读取 task_state_ref 和 precompact_checkpoint_ref。",
        "2. recovery_status 不是 READY 时，只能按 allowed_next_step 做恢复动作。",
        "3. compact_summary_ref 只保存压缩事件元数据，不把摘要当真源。",
    ]
    context = "\n".join(lines)
    if len(context.encode("utf-8")) > MAX_RECOVERY_OUTPUT_BYTES:
        context = context[: MAX_RECOVERY_OUTPUT_BYTES - 64] + "\n[context truncated]"
    return context


def _reject_duplicate_keys(pairs: list[tuple[str, object]]) -> dict[str, object]:
    value: dict[str, object] = {}
    for key, item in pairs:
        if key in value:
            raise LifecycleInputError("JSON objects must not contain duplicate keys")
        value[key] = item
    return value


def parse_json_object(text: str, *, label: str, maximum_bytes: int) -> dict[str, object]:
    try:
        encoded = text.encode("utf-8")
    except UnicodeError:
        raise LifecycleInputError(f"{label} must be valid UTF-8 JSON") from None
    if not encoded or len(encoded) > maximum_bytes:
        raise LifecycleInputError(f"{label} must contain one bounded JSON object")
    try:
        value = json.loads(text, object_pairs_hook=_reject_duplicate_keys)
    except (json.JSONDecodeError, UnicodeError, RecursionError):
        raise LifecycleInputError(f"{label} must contain exactly one JSON object") from None
    if not isinstance(value, dict):
        raise LifecycleInputError(f"{label} must be a JSON object")
    return value


def load_hook_payload() -> dict[str, object]:
    content = sys.stdin.buffer.read(MAX_HOOK_PAYLOAD_BYTES + 1)
    if not content or len(content) > MAX_HOOK_PAYLOAD_BYTES:
        raise LifecycleInputError("hook stdin must contain one bounded JSON object")
    try:
        text = content.decode("utf-8")
    except UnicodeDecodeError:
        raise LifecycleInputError("hook stdin must be valid UTF-8 JSON") from None
    return parse_json_object(
        text,
        label="hook stdin",
        maximum_bytes=MAX_HOOK_PAYLOAD_BYTES,
    )


def _required_text(
    payload: dict[str, object],
    field: str,
    *,
    maximum: int,
    exact_whitespace: bool = True,
) -> str:
    value = payload.get(field)
    if not isinstance(value, str) or not value.strip() or len(value) > maximum:
        raise LifecycleInputError(f"{field} must be a non-empty bounded string")
    if exact_whitespace and value != value.strip():
        raise LifecycleInputError(f"{field} must not contain surrounding whitespace")
    if any(
        ord(character) < 0x20 or 0xD800 <= ord(character) <= 0xDFFF
        for character in value
    ):
        raise LifecycleInputError(f"{field} contains invalid characters")
    return value


def canonical_cwd(value: object) -> Path:
    if not isinstance(value, str) or not value.strip() or len(value) > 4096:
        raise LifecycleInputError("cwd must be a non-empty bounded string")
    try:
        resolved = Path(value).expanduser().resolve(strict=True)
    except (OSError, RuntimeError):
        raise LifecycleInputError("cwd must identify an accessible directory") from None
    if not resolved.is_dir():
        raise LifecycleInputError("cwd must identify an accessible directory")
    return resolved


def prompt_preview_limit() -> int:
    raw = os.environ.get("ORG_CODEX_CONTEXT_PROMPT_PREVIEW_CHARS")
    if raw is None:
        return DEFAULT_PROMPT_PREVIEW_CHARS
    try:
        value = int(raw, 10)
    except ValueError:
        raise LifecycleInputError(
            "ORG_CODEX_CONTEXT_PROMPT_PREVIEW_CHARS must be an integer"
        ) from None
    if not 1 <= value <= MAX_PROMPT_PREVIEW_CHARS:
        raise LifecycleInputError(
            "ORG_CODEX_CONTEXT_PROMPT_PREVIEW_CHARS is outside its safe range"
        )
    return value


def redact_secrets(text: str) -> str:
    redacted = text
    for pattern in _SECRET_PATTERNS:
        redacted = pattern.sub("[REDACTED]", redacted)
    return redacted


def redacted_prompt_preview(prompt: str) -> str:
    limit = prompt_preview_limit()
    window = prompt[: limit + SECRET_REDACTION_LOOKAHEAD_CHARS]
    redacted = redact_secrets(window)
    if len(redacted) <= limit:
        return redacted
    suffix = "...[truncated]"
    return redacted[: max(0, limit - len(suffix))] + suffix


def git_head_for_cwd(cwd: Path) -> str:
    try:
        probe = subprocess.run(
            ["git", "-C", str(cwd), "rev-parse", "--is-inside-work-tree"],
            check=False,
            capture_output=True,
            text=True,
            timeout=GIT_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        raise GitStateError("Git identity lookup timed out after 5 seconds") from None
    except OSError:
        raise GitStateError("Git identity lookup failed") from None
    if probe.returncode == 128:
        return NOT_A_GIT_REPOSITORY
    if probe.returncode != 0:
        raise GitStateError("Git repository probe failed")
    if probe.stdout.strip() != "true":
        return NOT_A_GIT_REPOSITORY

    try:
        head = subprocess.run(
            ["git", "-C", str(cwd), "rev-parse", "--verify", "HEAD^{commit}"],
            check=False,
            capture_output=True,
            text=True,
            timeout=GIT_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        raise GitStateError("Git identity lookup timed out after 5 seconds") from None
    except OSError:
        raise GitStateError("Git identity lookup failed") from None
    value = head.stdout.strip()
    if head.returncode != 0 or _HEX_GIT_HEAD_RE.fullmatch(value) is None:
        raise GitStateError("Git HEAD lookup failed")
    return value.lower()


def lifecycle_status(
    store: SessionStore,
    pending: dict[str, object],
    git_head: str,
) -> tuple[RecoveryStatus, str, dict[str, object] | None]:
    snapshot = store.load_primary()
    identity = {
        "session_id": pending["session_id"],
        "turn_id": pending["turn_id"],
        "revision": pending["base_revision"] + 1,
        "base_revision": pending["base_revision"],
        "cwd": pending["cwd"],
        "git_head": git_head,
        "last_user_prompt_hash": pending["prompt_sha256"],
    }
    status, reason = evaluate_snapshot(snapshot, identity)
    return status, reason, snapshot


def _update_task_template() -> dict[str, object]:
    return {
        "task_status": "active",
        "active_goal": "<non-empty goal>",
        "scope_boundary": "<non-empty scope>",
        "non_goals": [],
        "latest_user_correction": "",
        "current_phase": "<non-empty phase>",
        "current_plan": [],
        "completed_items": [],
        "pending_items": [],
        "blockers": [],
        "next_action": "<non-empty next action>",
    }


def state_update_command(pending: dict[str, object]) -> str:
    payload = {
        "session_id": pending["session_id"],
        "turn_id": pending["turn_id"],
        "base_revision": pending["base_revision"],
        "task": _update_task_template(),
    }
    payload_text = json.dumps(
        payload,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    return " ".join(
        (
            shlex.quote(sys.executable),
            shlex.quote(str(Path(__file__).resolve())),
            "state-update",
            "--payload",
            shlex.quote(payload_text),
        )
    )


def prompt_additional_context(
    pending: dict[str, object], status: RecoveryStatus
) -> str:
    context = "\n".join(
        (
            "[Codex context continuity]",
            f"status: {status.value}",
            f"base_revision: {pending['base_revision']}",
            f"session_id: {pending['session_id']}",
            f"turn_id: {pending['turn_id']}",
            "state_update_contract: submit one complete task object; partial and runtime envelope fields are rejected.",
            f"state_update_command: {state_update_command(pending)}",
        )
    )
    if len(context.encode("utf-8")) > MAX_RECOVERY_OUTPUT_BYTES:
        raise LifecycleInputError("continuity context exceeds its bounded size")
    return context


def handle_precompact(payload: dict[str, object]) -> None:
    session_id = _validated_session_id(payload)
    SessionStore(state_root(), session_id)
    state = _load_recovery_state(session_id)
    checkpoint_path = state_root() / f"latest-precompact-{session_id}.json"
    state["precompact"] = {
        "hook_event_name": "PreCompact",
        "trigger": payload.get("trigger") or payload.get("matcher") or "",
        "cwd": payload.get("cwd") or "",
        "checkpoint_ref": str(checkpoint_path),
        "sealed_at": utc_now(),
        "recovery_status": state.get("recovery_status") or "INCOMPLETE",
    }
    _save_recovery_state(session_id, state)
    checkpoint = dict(state)
    checkpoint["checkpoint_event"] = "PreCompact"
    _write_json(checkpoint_path, checkpoint)


def handle_postcompact(payload: dict[str, object]) -> None:
    session_id = _validated_session_id(payload)
    SessionStore(state_root(), session_id)
    state = _load_recovery_state(session_id)
    summary = payload.get("compact_summary") or payload.get("compactSummary") or payload.get("summary")
    summary_text = summary if isinstance(summary, str) else ""
    metadata_path = state_root() / f"latest-postcompact-{session_id}.json"
    metadata = {
        "schema_version": RECOVERY_CARD_SCHEMA_VERSION,
        "session_id": session_id,
        "hook_event_name": "PostCompact",
        "trigger": payload.get("trigger") or payload.get("matcher") or "",
        "cwd": payload.get("cwd") or "",
        "recorded_at": utc_now(),
        "summary_length": len(summary_text),
        "summary_sha256": sha256_text(summary_text),
        "compact_summary_saved": False,
    }
    state["postcompact"] = {**metadata, "compact_summary_ref": str(metadata_path)}
    _save_recovery_state(session_id, state)
    _write_json(metadata_path, metadata)


def handle_session_start(payload: dict[str, object], source: str) -> None:
    if source != "compact":
        emit_json({})
        return
    session_id = _validated_session_id(payload)
    SessionStore(state_root(), session_id)
    state = _load_recovery_state(session_id)
    context = recovery_context(session_id, state)
    state["last_recovery_injection"] = {
        "hook_event_name": "SessionStart",
        "source": "compact",
        "injected_at": utc_now(),
        "task_state_ref": str(_recovery_state_path(session_id)),
        "precompact_checkpoint_ref": state.get("precompact", {}).get("checkpoint_ref", "missing"),
        "compact_summary_ref": state.get("postcompact", {}).get("compact_summary_ref", "missing"),
        "recovery_status": state.get("recovery_status", "INCOMPLETE"),
        "recovery_action_required": state.get("recovery_action_required", True),
        "allowed_next_step": state.get("allowed_next_step", "READ_ONLY_RECOVERY"),
        "additional_context_length": len(context),
        "additional_context_sha256": sha256_text(context),
    }
    _save_recovery_state(session_id, state)
    emit_json({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": context}})


def emit_json(payload: object) -> None:
    sys.stdout.write(json.dumps(payload, ensure_ascii=False, sort_keys=True) + "\n")


def handle_user_prompt(payload: dict[str, object]) -> None:
    session_id = _validated_session_id(payload)
    turn_id = _required_text(payload, "turn_id", maximum=512)
    prompt = _prompt_from_payload(payload)
    transcript_path = _required_text(
        payload,
        "transcript_path",
        maximum=4096,
        exact_whitespace=False,
    )
    cwd = canonical_cwd(payload.get("cwd"))
    policy = RetentionPolicy.from_environment()
    root = state_root()
    store = SessionStore(root, session_id, lock_timeout_seconds=policy.lock_timeout_seconds)
    pending = store.record_pending_turn(
        turn_id=turn_id,
        prompt_sha256=sha256_text(prompt),
        prompt_preview=redacted_prompt_preview(prompt),
        transcript_path=transcript_path,
        cwd=str(cwd),
    )
    git_head = git_head_for_cwd(cwd)
    status, _, _ = lifecycle_status(store, pending, git_head)
    state = _load_recovery_state(session_id)
    _record_prompt_in_state(
        state,
        prompt,
        turn_id,
        str(cwd),
        transcript_path,
        str(pending["updated_at"]),
    )
    _save_recovery_state(session_id, state)
    prune_state_root(root, session_id, policy, datetime.now(timezone.utc))
    emit_json(
        {
            "hookSpecificOutput": {
                "hookEventName": "UserPromptSubmit",
                "additionalContext": prompt_additional_context(pending, status),
            }
        }
    )


def _stop_block() -> None:
    emit_json({"decision": "block", "reason": STOP_REASON})


def handle_stop(payload: dict[str, object]) -> None:
    try:
        session_id = _validated_session_id(payload)
        turn_id = _required_text(payload, "turn_id", maximum=512)
        cwd = canonical_cwd(payload.get("cwd"))
        store = SessionStore(state_root(), session_id)
        state = _load_recovery_state(session_id)
        _record_stop_in_state(state, payload)
        _save_recovery_state(session_id, state)
        pending = store.load_pending_turn()
        if (
            pending is None
            or pending["session_id"] != session_id
            or pending["turn_id"] != turn_id
            or pending["cwd"] != str(cwd)
        ):
            _stop_block()
            return
        git_head = git_head_for_cwd(cwd)
        status, _, _ = lifecycle_status(store, pending, git_head)
        if status is not RecoveryStatus.READY:
            _stop_block()
            return
    except (LifecycleInputError, GitStateError, StoreError, SnapshotValidationError):
        _stop_block()
        return
    emit_json({})


def handle_state_update(payload_text: str) -> None:
    payload = parse_json_object(
        payload_text,
        label="state-update payload",
        maximum_bytes=MAX_SNAPSHOT_BYTES,
    )
    if set(payload) != _UPDATE_FIELDS:
        raise LifecycleInputError(
            "state-update payload must contain exactly session_id, turn_id, "
            "base_revision, and task"
        )
    session_id = _validated_session_id(payload)
    turn_id = _required_text(payload, "turn_id", maximum=512)
    base_revision = payload.get("base_revision")
    if (
        isinstance(base_revision, bool)
        or not isinstance(base_revision, int)
        or base_revision < 0
    ):
        raise LifecycleInputError("base_revision must be a non-negative integer")
    task = validate_task_payload(payload.get("task"))

    store = SessionStore(state_root(), session_id)
    pending = store.load_pending_turn()
    if pending is None:
        raise LifecycleInputError("no pending turn exists for state-update")
    if pending["session_id"] != session_id or pending["turn_id"] != turn_id:
        raise LifecycleInputError("state-update identity does not match the pending turn")
    if pending["base_revision"] != base_revision:
        raise RevisionConflict(
            "revision conflict: state-update base revision does not match pending turn"
        )
    cwd = canonical_cwd(pending["cwd"])
    git_head = git_head_for_cwd(cwd)
    runtime = {
        "session_id": session_id,
        "turn_id": turn_id,
        "base_revision": base_revision,
        "cwd": str(cwd),
        "git_head": git_head,
        "last_user_prompt_hash": pending["prompt_sha256"],
    }
    snapshot = store.commit_snapshot(
        task,
        runtime,
        base_revision,
        expected_pending=pending,
    )
    status, reason, _ = lifecycle_status(store, pending, git_head)
    if status is not RecoveryStatus.READY:
        raise IntegrityError("committed snapshot did not reach READY")
    state = _load_recovery_state(session_id)
    _record_snapshot_in_state(state, task, pending, snapshot)
    _save_recovery_state(session_id, state)
    emit_json({"status": status.value, "reason": reason, "snapshot": snapshot})


def handle_recover(session_id: str, turn_id: str) -> None:
    identity = {"session_id": session_id, "turn_id": turn_id}
    session_id = _validated_session_id(identity)
    turn_id = _required_text(identity, "turn_id", maximum=512)
    store = SessionStore(state_root(), session_id)
    pending = store.load_pending_turn()
    if pending is None:
        raise LifecycleInputError("no pending turn exists for recovery")
    if pending["session_id"] != session_id or pending["turn_id"] != turn_id:
        raise LifecycleInputError("recovery identity does not match the pending turn")
    cwd = canonical_cwd(pending["cwd"])
    git_head = git_head_for_cwd(cwd)
    status, reason, snapshot = lifecycle_status(store, pending, git_head)
    packet = {
        "schema_version": SCHEMA_VERSION,
        "status": status.value,
        "reason": reason,
        "session_id": session_id,
        "turn_id": turn_id,
        "base_revision": pending["base_revision"],
        "can_promote": False,
        "evidence": {
            "prompt_sha256": pending["prompt_sha256"],
            "prompt_preview": pending["prompt_preview"],
            "transcript_ref_present": bool(pending["transcript_path"]),
            "snapshot_revision": None if snapshot is None else snapshot["revision"],
            "snapshot_sha256": (
                None if snapshot is None else snapshot["snapshot_sha256"]
            ),
        },
    }
    serialized = json.dumps(packet, ensure_ascii=False, sort_keys=True) + "\n"
    if len(serialized.encode("utf-8")) > MAX_RECOVERY_OUTPUT_BYTES:
        raise LifecycleInputError("recovery evidence exceeds its bounded size")
    sys.stdout.write(serialized)


def resolve_event(payload: dict[str, object], override: str | None) -> str:
    if override:
        return override
    value = payload.get("hook_event_name")
    if value is None:
        value = payload.get("hookEventName")
    return value if isinstance(value, str) else ""


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Enforce turn-bound Codex context snapshots."
    )
    parser.add_argument("--event")
    parser.add_argument("--source")
    subparsers = parser.add_subparsers(dest="command")
    update = subparsers.add_parser("state-update")
    update.add_argument("--payload", required=True)
    recover = subparsers.add_parser("recover")
    recover.add_argument("--session-id", required=True)
    recover.add_argument("--turn-id", required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    if args.command == "state-update":
        handle_state_update(args.payload)
        return 0
    if args.command == "recover":
        handle_recover(args.session_id, args.turn_id)
        return 0

    payload = load_hook_payload()
    event = resolve_event(payload, args.event)
    source = args.source or payload.get("source") or payload.get("matcher") or payload.get("trigger") or ""
    if event == "UserPromptSubmit":
        handle_user_prompt(payload)
    elif event == "Stop":
        handle_stop(payload)
    elif event == "PreCompact":
        handle_precompact(payload)
    elif event == "PostCompact":
        handle_postcompact(payload)
    elif event == "SessionStart":
        handle_session_start(payload, str(source))
    else:
        # StateUpdate is retained only as legacy evidence and never writes READY.
        emit_json({})
    return 0


def _safe_error_message(exc: BaseException) -> str:
    if isinstance(exc, (LifecycleInputError, GitStateError, RevisionConflict)):
        return str(exc)
    if isinstance(exc, SnapshotValidationError):
        fields = ", ".join(sorted(exc.field_errors))
        return f"state-update task is invalid: {fields}"
    if isinstance(exc, IntegrityError):
        return "managed context state failed integrity validation"
    if isinstance(exc, StoreError):
        return "managed context state operation failed"
    return "unexpected context continuity failure"


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (LifecycleInputError, GitStateError, StoreError, SnapshotValidationError) as exc:
        print(f"codex context continuity failed: {_safe_error_message(exc)}", file=sys.stderr)
        raise SystemExit(1)
    except Exception as exc:
        print(f"codex context continuity failed: {_safe_error_message(exc)}", file=sys.stderr)
        raise SystemExit(1)
