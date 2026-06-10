#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


RUNTIME_HOME = Path(__file__).resolve().parents[2]
REGISTRY_FILE = RUNTIME_HOME / "hooks" / "registry.json"
STATE_DIR = Path(
    os.environ.get(
        "ORG_CODEX_ACTIVE_SKILLS_STATE_DIR",
        str(RUNTIME_HOME / "hooks" / "state" / "active-skills"),
    )
)


def state_file_for(session_id: str) -> Path:
    return STATE_DIR / f"{session_id}.json"


def load_registry() -> dict:
    return json.loads(REGISTRY_FILE.read_text(encoding="utf-8"))


def load_active_skill(session_id: str) -> str | None:
    state_file = state_file_for(session_id)
    if not state_file.exists():
        return None
    try:
        payload = json.loads(state_file.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError("active skill state is unreadable") from exc
    skill = payload.get("skill")
    if not isinstance(skill, str) or not skill:
        raise ValueError("active skill state missing skill")
    return skill


def registry_entry_for_skill(registry: dict, skill: str) -> dict | None:
    for entry in registry.get("skill_completion_gates", []):
        if entry.get("skill") == skill:
            return entry
    return None


def entry_dispatches_on_stop(entry: dict | None) -> bool:
    if entry is None:
        return False
    codex = entry.get("codex")
    if not isinstance(codex, dict) or not codex.get("supported"):
        return False
    event = codex.get("event")
    if not isinstance(event, str):
        claude = entry.get("claude")
        event = claude.get("event") if isinstance(claude, dict) else None
    return event == "Stop"


def timeout_for_entry(entry: dict | None) -> float | None:
    if not entry:
        return None

    value = entry.get("timeout_sec")
    if isinstance(value, (int, float)):
        return float(value) if value > 0 else None

    if isinstance(value, str):
        try:
            parsed = float(value)
        except ValueError:
            return None
        return parsed if parsed > 0 else None

    return None


def gate_for_skill(entry: dict | None, skill: str) -> Path | None:
    if entry is None:
        return None
    if not entry.get("codex", {}).get("supported"):
        return None
    handler_rel = entry.get("handler_rel")
    if not isinstance(handler_rel, str) or not handler_rel:
        raise ValueError(f"{skill} completion gate handler is invalid")
    if Path(handler_rel).is_absolute():
        raise ValueError(f"{skill} completion gate handler must be runtime-relative")

    runtime_root = RUNTIME_HOME.resolve()
    handler_path = (RUNTIME_HOME / handler_rel).resolve()
    try:
        handler_path.relative_to(runtime_root)
    except ValueError as exc:
        raise ValueError(f"{skill} completion gate handler escapes runtime home") from exc
    return handler_path


def bash_executable() -> str:
    bash = shutil.which("bash")
    if not bash:
        raise RuntimeError("bash executable is unavailable")
    return str(Path(bash).resolve())


def sanitize_failure_reason(reason: str, skill: str) -> str:
    text = reason.strip()
    if not text:
        return f"{skill} completion gate failed."

    replacements = (
        ("stdin 为空，无法解析 hook 上下文", "运行时上下文缺失，completion gate 无法初始化"),
        ("stdin 不是有效 JSON，无法解析 hook 上下文", "运行时上下文无效，completion gate 无法初始化"),
        ("hook payload 缺少 tool_name", "运行时上下文缺少当前工具信息"),
        ("hook payload 缺少 tool_input.file_path", "运行时上下文缺少写入目标路径信息"),
        ("hook payload 缺少 cwd", "运行时上下文缺少工作目录信息"),
        ("hook payload 中的 cwd 不存在", "运行时工作目录不存在"),
        ("无法进入 hook payload 指定的 cwd", "无法进入运行时工作目录"),
        ("hook payload", "运行时上下文"),
        ("tool_input.file_path", "写入目标路径"),
        ("tool_name", "当前工具"),
    )
    for old, new in replacements:
        text = text.replace(old, new)

    text = re.sub(r"transcript_path=[^，,\n]+(?:[，,]\s*)?", "", text)
    text = re.sub(r"session_id=[^，,\n]+(?:[，,]\s*)?", "", text)
    text = re.sub(r"cwd=[^，,\n]+(?:[，,]\s*)?", "", text)
    text = re.sub(r"(/Users/[^\s，,]+|/tmp/[^\s，,]+|\$HOME/\.codex/[^\s，,]+)", "<internal-path>", text)

    lines: list[str] = []
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if set(line) <= {"━", "-"}:
            continue

        line = re.sub(r"\s+", " ", line)
        line = re.sub(r"：\s*且", "，且", line)
        line = re.sub(r"：\s*[，,]", "：", line)
        line = re.sub(r"[，,]\s*[，,]", "，", line)
        line = line.rstrip("，, ")
        if not line:
            continue
        if not lines or lines[-1] != line:
            lines.append(line)
        if len(lines) == 2:
            break

    if not lines:
        return f"{skill} completion gate failed."

    return "\n".join(lines)


def extract_failure_reason(stdout: str, stderr: str, skill: str) -> str:
    for raw_line in reversed(stdout.splitlines()):
        line = raw_line.strip()
        if not line:
            continue
        try:
            payload = json.loads(line)
        except json.JSONDecodeError:
            continue

        if isinstance(payload, dict):
            for key in ("reason", "stopReason", "message"):
                value = payload.get(key)
                if isinstance(value, str) and value.strip():
                    return sanitize_failure_reason(value, skill)

    for stream in (stderr, stdout):
        text = stream.strip()
        if text:
            return sanitize_failure_reason(text, skill)

    return f"{skill} completion gate failed."


def stdout_requests_block(stdout: str) -> bool:
    for raw_line in reversed(stdout.splitlines()):
        line = raw_line.strip()
        if not line:
            continue
        try:
            payload = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not isinstance(payload, dict):
            continue
        if payload.get("decision") == "block":
            return True
        if payload.get("continue") is False:
            return True
        return False
    return False


def emit_stop_failure(reason: str) -> None:
    payload = {
        "decision": "block",
        "reason": reason,
        "systemMessage": reason,
    }
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")


def main() -> int:
    payload = json.loads(sys.stdin.read() or "{}")
    session_id = payload.get("session_id") or payload.get("sessionId")
    if not session_id:
        emit_stop_failure("运行时上下文缺少 session_id，completion gate 无法解析当前技能。")
        return 0

    try:
        skill = load_active_skill(session_id)
    except Exception:
        emit_stop_failure("active skill 状态损坏，completion gate 无法确认当前技能。")
        return 0
    if not skill:
        print("{}")
        return 0

    try:
        registry = load_registry()
        entry = registry_entry_for_skill(registry, skill)
        gate_path = gate_for_skill(entry, skill)
        timeout_sec = timeout_for_entry(entry)
    except Exception:
        emit_stop_failure(f"{skill} completion gate 配置无效。")
        return 0
    if entry and not entry.get("codex", {}).get("supported"):
        state_file_for(session_id).unlink(missing_ok=True)
        print("{}")
        return 0
    if entry is None:
        state_file_for(session_id).unlink(missing_ok=True)
        print("{}")
        return 0
    if not entry_dispatches_on_stop(entry):
        state_file_for(session_id).unlink(missing_ok=True)
        print("{}")
        return 0
    if timeout_sec is None:
        emit_stop_failure(f"{skill} completion gate timeout 配置无效。")
        return 0
    if gate_path is None or not gate_path.is_file():
        emit_stop_failure(f"{skill} completion gate 缺失，无法完成当前收口检查。")
        return 0

    try:
        bash_bin = bash_executable()
        proc = subprocess.run(
            [bash_bin, str(gate_path)],
            input=json.dumps(payload, ensure_ascii=False),
            text=True,
            capture_output=True,
            timeout=timeout_sec,
        )
    except subprocess.TimeoutExpired:
        emit_stop_failure(f"{skill} completion gate 超时，当前收口检查未完成。")
        return 0
    except (OSError, RuntimeError):
        emit_stop_failure(f"{skill} completion gate 运行环境无法启动 bash。")
        return 0

    if proc.returncode == 0 and proc.stdout:
        if not stdout_requests_block(proc.stdout):
            state_file_for(session_id).unlink(missing_ok=True)
        sys.stdout.write(proc.stdout)
        if not proc.stdout.endswith("\n"):
            sys.stdout.write("\n")
        return 0
    elif proc.returncode == 0:
        state_file_for(session_id).unlink(missing_ok=True)
        sys.stdout.write("{}\n")
        return 0

    emit_stop_failure(extract_failure_reason(proc.stdout, proc.stderr, skill))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
