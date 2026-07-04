#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


SCHEMA_VERSION = "1.0"
SESSION_SAFE = re.compile(r"[^A-Za-z0-9_.-]+")
DEFAULT_PROMPT_PREVIEW_CHARS = 240
SECRET_REDACTION_LOOKAHEAD_CHARS = 4096
MAX_STATE_STRING_CHARS = 4000
MAX_STATE_LIST_ITEMS = 50
MAX_STATE_LIST_ITEM_CHARS = 1000
MAX_STATE_UPDATES = 20
INLINE_CONTEXT_STRING_CHARS = 320
INLINE_CONTEXT_LIST_ITEMS = 3
INLINE_CONTEXT_LIST_ITEM_CHARS = 180
SECRET_PATTERNS = [
    re.compile(r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----[\s\S]*?(?:-----END [A-Z0-9 ]*PRIVATE KEY-----|$)"),
    re.compile(r"(?i)(secret|token|password|api[_-]?key)[A-Za-z0-9_:=\\\-\"' .]{0,120}"),
    re.compile(r"\bsk-(?:proj-)?[A-Za-z0-9_-]{16,}\b"),
    re.compile(r"\bgh[pousr]_[A-Za-z0-9_]{16,}\b"),
    re.compile(r"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{4,}\b"),
    re.compile(r"(?i)\bbearer\s+[A-Za-z0-9._~+/=-]{20,}"),
]
REQUIRED_QUESTIONS = [
    "当前目标是什么？",
    "最新用户纠偏是什么？",
    "当前做到哪一步？",
    "哪些已经完成且证据在哪？",
    "哪些未完成或被阻塞？",
    "下一步是什么？",
]
RECOVERY_DEFAULTS = {
    "last_user_prompt_hash": "",
    "last_user_prompt_preview": "",
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
}
RECOVERY_REQUIRED_FIELDS = [
    "active_goal",
    "scope_boundary",
    "current_phase",
    "completed_items",
    "evidence_refs",
    "pending_items",
    "next_action",
]
RECOVERY_STATUS_READY = "READY"
RECOVERY_STATUS_INCOMPLETE = "INCOMPLETE"
RECOVERY_STATUS_STALE = "STALE"
RECOVERY_STATUS_UNRECOVERABLE = "UNRECOVERABLE"
RECOVERY_ALLOWED_CONTINUE = "CONTINUE_FROM_STATE"
RECOVERY_ALLOWED_READ_ONLY = "READ_ONLY_RECOVERY"
RECOVERY_ALLOWED_REFRESH = "REFRESH_STATE_UPDATE"
RECOVERY_ALLOWED_USER_INPUT = "ASK_USER_FOR_SCOPE"
RECOVERY_STATE_FIELDS = [
    "active_goal",
    "scope_boundary",
    "non_goals",
    "latest_user_correction",
    "current_phase",
    "current_plan",
    "completed_items",
    "evidence_refs",
    "pending_items",
    "blockers",
    "next_action",
    "git_head",
    "truth_policy",
]
RECOVERY_LIST_FIELDS = {"non_goals", "current_plan", "completed_items", "evidence_refs", "pending_items", "blockers"}
RECOVERY_STRING_FIELDS = set(RECOVERY_STATE_FIELDS) - RECOVERY_LIST_FIELDS
INLINE_EMPTY_LIST_TEXT = {
    "blockers": "none",
    "non_goals": "none",
}


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def state_root() -> Path:
    override = os.environ.get("ORG_CODEX_CONTEXT_CONTINUITY_STATE_DIR")
    if override:
        return Path(override).expanduser()
    return Path.home() / ".codex" / "hooks" / "state" / "context-continuity"


def payload_probe_dir() -> Path | None:
    raw = os.environ.get("ORG_CODEX_CONTEXT_CONTINUITY_PAYLOAD_PROBE_DIR", "")
    return Path(raw).expanduser() if raw else None


def redacted_payload_preview(payload: dict[str, Any]) -> dict[str, Any]:
    preview: dict[str, Any] = {}
    for key, value in sorted(payload.items()):
        if isinstance(value, str):
            preview[key] = {
                "type": "string",
                "length": len(value),
                "sha256": sha256_text(value),
            }
        else:
            preview[key] = {"type": type(value).__name__}
    return preview


def write_payload_probe(payload: dict[str, Any], event_name: str, session_id: str) -> None:
    root = payload_probe_dir()
    if root is None:
        return

    root.mkdir(parents=True, exist_ok=True)
    timestamp = utc_now().replace(":", "").replace("-", "")
    path = root / f"{timestamp}-{os.getpid()}.json"
    record = {
        "schema_version": SCHEMA_VERSION,
        "event": event_name,
        "session_id_present": bool(payload.get("session_id") or payload.get("sessionId")),
        "session_id_hash": sha256_text(session_id) if session_id else "",
        "cwd_present": bool(payload.get("cwd")),
        "payload_keys": sorted(str(key) for key in payload.keys()),
        "payload_preview": redacted_payload_preview(payload),
        "recorded_at": utc_now(),
    }
    write_json(path, record)


def sanitize_session_id(raw: Any) -> str:
    text = str(raw or "unknown-session").strip() or "unknown-session"
    return SESSION_SAFE.sub("_", text)[:160]


def required_session_id(payload: dict[str, Any]) -> str:
    raw = payload.get("session_id") or payload.get("sessionId")
    text = str(raw or "").strip()
    if not text:
        raise ValueError("missing session_id")
    return SESSION_SAFE.sub("_", text)[:160]


def prompt_preview_limit() -> int:
    raw = os.environ.get("ORG_CODEX_CONTEXT_PROMPT_PREVIEW_CHARS", "")
    if not raw:
        return DEFAULT_PROMPT_PREVIEW_CHARS
    try:
        value = int(raw)
    except ValueError:
        return DEFAULT_PROMPT_PREVIEW_CHARS
    return value if value > 0 else DEFAULT_PROMPT_PREVIEW_CHARS


def redact_secrets(text: str) -> str:
    redacted = text
    for pattern in SECRET_PATTERNS:
        redacted = pattern.sub("[REDACTED]", redacted)
    return redacted


def redacted_prompt_preview(text: str) -> str:
    limit = prompt_preview_limit()
    preview_window = text[: limit + SECRET_REDACTION_LOOKAHEAD_CHARS]
    return truncate_text(redact_secrets(preview_window), limit)


def load_payload() -> dict[str, Any]:
    text = sys.stdin.read() or "{}"
    try:
        payload = json.loads(text)
    except json.JSONDecodeError as exc:
        raise ValueError(f"stdin is not valid JSON: {exc}") from exc
    if not isinstance(payload, dict):
        raise ValueError("hook payload must be a JSON object")
    return payload


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    tmp.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    try:
        tmp.chmod(0o600)
    except OSError:
        pass
    tmp.replace(path)


def load_state(path: Path, session_id: str) -> dict[str, Any]:
    if path.exists():
        try:
            state = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            raise ValueError(f"context continuity state is unreadable: {path}") from exc
        if not isinstance(state, dict):
            raise ValueError(f"context continuity state must be an object: {path}")
    else:
        state = {}

    now = utc_now()
    state.setdefault("schema_version", SCHEMA_VERSION)
    state["schema_version"] = SCHEMA_VERSION
    state.setdefault("session_id", session_id)
    state["session_id"] = session_id
    state.setdefault("created_at", now)
    state.setdefault("updated_at", now)
    state.setdefault("last_stop", {})
    state.setdefault("precompact", {})
    state.setdefault("postcompact", {})
    for key, value in RECOVERY_DEFAULTS.items():
        if key not in state:
            state[key] = list(value) if isinstance(value, list) else value
    refresh_recovery_contracts(state)
    return state


def refresh_recovery_contracts(state: dict[str, Any]) -> None:
    state["recovery_contract"] = {
        "mode": "codex_context_window_continuity",
        "truth_policy": state["truth_policy"],
        "required_questions": REQUIRED_QUESTIONS,
        "required_state_fields": RECOVERY_REQUIRED_FIELDS,
    }
    state["recovery_evaluation"] = recovery_evaluation(state)


def write_state(path: Path, state: dict[str, Any]) -> None:
    refresh_recovery_contracts(state)
    write_json(path, state)


def state_path_for(root: Path, session_id: str) -> Path:
    return root / f"{session_id}.json"


def common_event_fields(payload: dict[str, Any], event_name: str) -> dict[str, Any]:
    return {
        "hook_event_name": event_name,
        "trigger": payload.get("trigger") or payload.get("matcher") or "",
        "cwd": payload.get("cwd") or "",
    }


def record_user_prompt(state: dict[str, Any], payload: dict[str, Any]) -> None:
    prompt = str(payload.get("prompt") or payload.get("user_prompt") or "")
    state.pop("latest_user_prompt", None)
    state["last_user_prompt_hash"] = sha256_text(prompt)
    state["last_user_prompt_preview"] = redacted_prompt_preview(prompt)
    state["last_user_prompt_length"] = len(prompt)
    state["last_user_prompt_truncated"] = len(prompt) > prompt_preview_limit()
    state["last_user_prompt_recorded_at"] = utc_now()
    state["cwd"] = payload.get("cwd") or state.get("cwd") or ""


def record_stop(state: dict[str, Any], payload: dict[str, Any]) -> None:
    state["last_stop"] = {
        "cwd": payload.get("cwd") or "",
        "transcript_path": payload.get("transcript_path") or payload.get("transcriptPath") or "",
        "recorded_at": utc_now(),
    }


def truncate_text(text: str, limit: int) -> str:
    if len(text) <= limit:
        return text
    return text[: max(0, limit - 12)] + "...[truncated]"


def normalize_state_string(field: str, value: Any, limit: int) -> str:
    if not isinstance(value, str):
        raise ValueError(f"state field {field} must be a string")
    return truncate_text(redact_secrets(value), limit)


def normalize_state_list(field: str, value: Any) -> list[str]:
    if not isinstance(value, list):
        raise ValueError(f"state field {field} must be a list")
    if len(value) > MAX_STATE_LIST_ITEMS:
        raise ValueError(f"state field {field} must contain at most {MAX_STATE_LIST_ITEMS} items")

    normalized: list[str] = []
    for index, item in enumerate(value):
        if not isinstance(item, str):
            raise ValueError(f"state field {field}[{index}] must be a string")
        normalized.append(truncate_text(redact_secrets(item), MAX_STATE_LIST_ITEM_CHARS))
    return normalized


def normalize_state_update(payload: dict[str, Any]) -> dict[str, str | list[str]]:
    update = payload.get("state")
    if not isinstance(update, dict):
        raise ValueError("state update payload must include a state object")

    unsupported = sorted(str(field) for field in update if field not in RECOVERY_STATE_FIELDS)
    if unsupported:
        raise ValueError(f"unsupported state field: {', '.join(unsupported)}")

    normalized: dict[str, str | list[str]] = {}
    for field, value in update.items():
        if field in RECOVERY_LIST_FIELDS:
            normalized[field] = normalize_state_list(field, value)
        elif field in RECOVERY_STRING_FIELDS:
            normalized[field] = normalize_state_string(field, value, MAX_STATE_STRING_CHARS)
    return normalized


def record_state_update(state: dict[str, Any], payload: dict[str, Any], source: str) -> None:
    normalized = normalize_state_update(payload)
    for field, value in normalized.items():
        state[field] = value

    updates = state.get("state_updates")
    if not isinstance(updates, list):
        updates = []
    updates.append(
        {
            "recorded_at": utc_now(),
            "source": source or "unknown",
            "updated_fields": sorted(normalized.keys()),
            "last_user_prompt_hash": state.get("last_user_prompt_hash") or "",
        }
    )
    state["state_updates"] = updates[-MAX_STATE_UPDATES:]
    state["last_state_update"] = state["state_updates"][-1]
    refresh_recovery_contracts(state)


def record_precompact(root: Path, state_path: Path, state: dict[str, Any], payload: dict[str, Any]) -> None:
    session_id = state["session_id"]
    checkpoint_path = root / f"latest-precompact-{session_id}.json"
    state["precompact"] = {
        **common_event_fields(payload, "PreCompact"),
        "checkpoint_ref": str(checkpoint_path),
        "sealed_at": utc_now(),
        "recovery_missing_fields": recovery_missing_fields(state),
        "recovery_status": recovery_evaluation(state)["status"],
    }
    state["updated_at"] = utc_now()
    write_state(state_path, state)

    checkpoint = dict(state)
    checkpoint["checkpoint_event"] = "PreCompact"
    write_json(checkpoint_path, checkpoint)


def compact_summary_from(payload: dict[str, Any]) -> str:
    for key in ("compact_summary", "compactSummary", "summary"):
        value = payload.get(key)
        if isinstance(value, str):
            return value
    return ""


def record_postcompact(root: Path, state_path: Path, state: dict[str, Any], payload: dict[str, Any]) -> dict[str, Any]:
    session_id = state["session_id"]
    summary = compact_summary_from(payload)
    metadata_path = root / f"latest-postcompact-{session_id}.json"
    recorded_at = utc_now()
    metadata = {
        "schema_version": SCHEMA_VERSION,
        "session_id": session_id,
        **common_event_fields(payload, "PostCompact"),
        "recorded_at": recorded_at,
        "summary_length": len(summary),
        "summary_sha256": sha256_text(summary),
        "compact_summary_saved": False,
    }
    state["postcompact"] = {
        **metadata,
        "compact_summary_ref": str(metadata_path),
    }
    state["updated_at"] = recorded_at
    write_state(state_path, state)
    write_json(metadata_path, metadata)
    return metadata


def recovery_missing_fields(state: dict[str, Any]) -> list[str]:
    missing: list[str] = []
    for field in RECOVERY_REQUIRED_FIELDS:
        value = state.get(field)
        if value in ("", None, []):
            missing.append(field)
    return missing


def latest_state_update(state: dict[str, Any]) -> dict[str, Any]:
    update = state.get("last_state_update")
    if isinstance(update, dict):
        return update
    updates = state.get("state_updates")
    if isinstance(updates, list) and updates and isinstance(updates[-1], dict):
        return updates[-1]
    return {}


def state_is_stale(state: dict[str, Any]) -> str:
    prompt_hash = state.get("last_user_prompt_hash")
    update_prompt_hash = latest_state_update(state).get("last_user_prompt_hash")
    if isinstance(prompt_hash, str) and prompt_hash:
        if not isinstance(update_prompt_hash, str) or not update_prompt_hash:
            return "state update is not bound to the latest prompt"
        if update_prompt_hash != prompt_hash:
            return "latest prompt hash differs from the last StateUpdate prompt hash"

    prompt_recorded_at = state.get("last_user_prompt_recorded_at")
    if not isinstance(prompt_recorded_at, str) or not prompt_recorded_at:
        return ""

    update_recorded_at = latest_state_update(state).get("recorded_at")
    if not isinstance(update_recorded_at, str) or not update_recorded_at:
        return "state has no StateUpdate after the latest prompt"
    if update_recorded_at < prompt_recorded_at:
        return "latest prompt is newer than the last StateUpdate"
    return ""


def recovery_evidence_actions(state: dict[str, Any]) -> list[str]:
    actions = ["READ_TASK_STATE"]
    precompact_ref = state.get("precompact", {}).get("checkpoint_ref")
    if isinstance(precompact_ref, str) and precompact_ref:
        actions.append("READ_PRECOMPACT_CHECKPOINT")

    transcript_path = state.get("last_stop", {}).get("transcript_path")
    if isinstance(transcript_path, str) and transcript_path:
        actions.append("READ_TRANSCRIPT")

    evidence_refs = state.get("evidence_refs")
    if isinstance(evidence_refs, list) and evidence_refs:
        actions.append("READ_EVIDENCE_REFS")

    prompt_preview = state.get("last_user_prompt_preview")
    if isinstance(prompt_preview, str) and prompt_preview:
        actions.append("READ_LAST_USER_PROMPT")

    return actions


def recovery_evaluation(state: dict[str, Any]) -> dict[str, Any]:
    missing_fields = recovery_missing_fields(state)
    stale_reason = "" if missing_fields else state_is_stale(state)

    if not missing_fields and not stale_reason:
        return {
            "status": RECOVERY_STATUS_READY,
            "action_required": False,
            "allowed_next_step": RECOVERY_ALLOWED_CONTINUE,
            "missing_fields": [],
            "stale_reason": "",
            "required_recovery_actions": [],
        }

    if stale_reason:
        return {
            "status": RECOVERY_STATUS_STALE,
            "action_required": True,
            "allowed_next_step": RECOVERY_ALLOWED_REFRESH,
            "missing_fields": [],
            "stale_reason": stale_reason,
            "required_recovery_actions": [
                "READ_TASK_STATE",
                "READ_LAST_USER_PROMPT",
                "REFRESH_STATE_UPDATE",
            ],
        }

    required_actions = recovery_evidence_actions(state)
    has_external_recovery_evidence = any(
        action in required_actions
        for action in ("READ_PRECOMPACT_CHECKPOINT", "READ_TRANSCRIPT", "READ_EVIDENCE_REFS", "READ_LAST_USER_PROMPT")
    )
    if has_external_recovery_evidence:
        return {
            "status": RECOVERY_STATUS_INCOMPLETE,
            "action_required": True,
            "allowed_next_step": RECOVERY_ALLOWED_READ_ONLY,
            "missing_fields": missing_fields,
            "stale_reason": "",
            "required_recovery_actions": required_actions,
        }

    return {
        "status": RECOVERY_STATUS_UNRECOVERABLE,
        "action_required": True,
        "allowed_next_step": RECOVERY_ALLOWED_USER_INPUT,
        "missing_fields": missing_fields,
        "stale_reason": "",
        "required_recovery_actions": ["ASK_USER_FOR_SCOPE"],
    }


def inline_scalar(state: dict[str, Any], field: str) -> str:
    value = state.get(field)
    if not isinstance(value, str) or not value:
        return "<missing>"
    return truncate_text(redact_secrets(value), INLINE_CONTEXT_STRING_CHARS)


def inline_list(state: dict[str, Any], field: str) -> str:
    value = state.get(field)
    if not isinstance(value, list) or not value:
        return INLINE_EMPTY_LIST_TEXT.get(field, "<missing>")

    items = [
        truncate_text(redact_secrets(str(item)), INLINE_CONTEXT_LIST_ITEM_CHARS)
        for item in value[:INLINE_CONTEXT_LIST_ITEMS]
    ]
    suffix = "" if len(value) <= INLINE_CONTEXT_LIST_ITEMS else f" (+{len(value) - INLINE_CONTEXT_LIST_ITEMS} more)"
    return " | ".join(items) + suffix


def additional_context(state_path: Path, state: dict[str, Any]) -> str:
    refresh_recovery_contracts(state)
    evaluation = state["recovery_evaluation"]
    precompact_ref = state.get("precompact", {}).get("checkpoint_ref") or "missing"
    compact_ref = state.get("postcompact", {}).get("compact_summary_ref") or "missing"
    missing_fields = recovery_missing_fields(state)
    missing_text = ", ".join(missing_fields) if missing_fields else "none"
    actions = evaluation.get("required_recovery_actions") or []
    actions_text = ", ".join(str(action) for action in actions) if actions else "none"
    stale_reason = str(evaluation.get("stale_reason") or "none")
    transcript_path = state.get("last_stop", {}).get("transcript_path") or "missing"
    action_required = "true" if evaluation.get("action_required") else "false"
    return "\n".join(
        [
            "[Codex context continuity recovery]",
            f"task_state_ref: {state_path}",
            f"precompact_checkpoint_ref: {precompact_ref}",
            f"compact_summary_ref: {compact_ref}",
            f"transcript_path: {transcript_path}",
            f"recovery_status: {evaluation['status']}",
            f"recovery_action_required: {action_required}",
            f"allowed_next_step: {evaluation['allowed_next_step']}",
            f"recovery_missing_fields: {missing_text}",
            f"required_recovery_actions: {actions_text}",
            f"stale_reason: {stale_reason}",
            "恢复状态摘要:",
            f"active_goal: {inline_scalar(state, 'active_goal')}",
            f"scope_boundary: {inline_scalar(state, 'scope_boundary')}",
            f"latest_user_correction: {inline_scalar(state, 'latest_user_correction')}",
            f"current_phase: {inline_scalar(state, 'current_phase')}",
            f"current_plan: {inline_list(state, 'current_plan')}",
            f"completed_items: {inline_list(state, 'completed_items')}",
            f"evidence_refs: {inline_list(state, 'evidence_refs')}",
            f"pending_items: {inline_list(state, 'pending_items')}",
            f"blockers: {inline_list(state, 'blockers')}",
            f"next_action: {inline_scalar(state, 'next_action')}",
            f"last_user_prompt_preview: {inline_scalar(state, 'last_user_prompt_preview')}",
            "恢复步骤:",
            "1. 先读取 task_state_ref 的 active_goal、scope_boundary、latest_user_correction、current_phase、completed_items、evidence_refs、pending_items、blockers、next_action。",
            "2. recovery_status 不是 READY 时，只能按 allowed_next_step 做恢复动作，不得继续执行原任务。",
            "3. 若任何关键字段为空且 transcript/evidence 不足以恢复，报告 blocked，不继续执行。",
            "4. compact_summary_ref 只保存压缩事件元数据；不要猜测，不要把 compact summary 当真源。证据不足就回查源码、测试或 transcript 引用。",
        ]
    )


def emit_sessionstart_compact(state_path: Path, state: dict[str, Any]) -> None:
    context = additional_context(state_path, state)
    evaluation = state["recovery_evaluation"]
    injected_at = utc_now()
    state["last_recovery_injection"] = {
        "hook_event_name": "SessionStart",
        "source": "compact",
        "injected_at": injected_at,
        "task_state_ref": str(state_path),
        "precompact_checkpoint_ref": state.get("precompact", {}).get("checkpoint_ref") or "missing",
        "compact_summary_ref": state.get("postcompact", {}).get("compact_summary_ref") or "missing",
        "recovery_status": evaluation["status"],
        "recovery_action_required": evaluation["action_required"],
        "allowed_next_step": evaluation["allowed_next_step"],
        "missing_fields": evaluation["missing_fields"],
        "stale_reason": evaluation["stale_reason"],
        "required_recovery_actions": evaluation["required_recovery_actions"],
        "additional_context_length": len(context),
        "additional_context_sha256": sha256_text(context),
    }
    state["updated_at"] = injected_at
    write_state(state_path, state)
    payload = {
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": context,
        }
    }
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")


def resolve_event(payload: dict[str, Any], override: str | None) -> str:
    return override or str(payload.get("hook_event_name") or payload.get("hookEventName") or "")


def resolve_source(payload: dict[str, Any], override: str | None) -> str:
    return override or str(payload.get("source") or payload.get("matcher") or payload.get("trigger") or "")


def main() -> int:
    parser = argparse.ArgumentParser(description="Persist Codex context continuity state across compaction.")
    parser.add_argument("--event", help="Override hook event name when the runtime does not include it.")
    parser.add_argument("--source", help="Override hook source or matcher value.")
    args = parser.parse_args()

    payload = load_payload()
    event_name = resolve_event(payload, args.event)
    source = resolve_source(payload, args.source)
    root = state_root()
    session_id = required_session_id(payload)
    write_payload_probe(payload, event_name, session_id)
    state_path = state_path_for(root, session_id)
    state = load_state(state_path, session_id)

    if event_name == "SessionStart":
        if source == "compact":
            emit_sessionstart_compact(state_path, state)
        return 0

    if event_name == "UserPromptSubmit":
        record_user_prompt(state, payload)
        state["updated_at"] = utc_now()
        write_state(state_path, state)
        return 0

    if event_name == "Stop":
        record_stop(state, payload)
        state["updated_at"] = utc_now()
        write_state(state_path, state)
        return 0

    if event_name == "StateUpdate":
        record_state_update(state, payload, source)
        state["updated_at"] = utc_now()
        write_state(state_path, state)
        return 0

    if event_name == "PreCompact":
        record_precompact(root, state_path, state, payload)
        return 0

    if event_name == "PostCompact":
        record_postcompact(root, state_path, state, payload)
        return 0

    state["updated_at"] = utc_now()
    state["last_unhandled_event"] = {
        "hook_event_name": event_name,
        "recorded_at": utc_now(),
    }
    write_state(state_path, state)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"codex context continuity hook failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
