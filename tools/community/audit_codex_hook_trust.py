#!/usr/bin/env python3
"""Audit Codex hook trust/readiness through the app-server hooks/list API."""

from __future__ import annotations

import argparse
import json
import os
import select
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


READY_STATUSES = {"trusted", "managed"}


class AuditError(RuntimeError):
    pass


def load_json_payload(path: str) -> dict[str, Any]:
    if path == "-":
        text = sys.stdin.read()
    else:
        text = Path(path).read_text(encoding="utf-8")

    try:
        payload = json.loads(text)
    except json.JSONDecodeError as exc:
        raise AuditError(f"hook audit JSON 无法解析: {exc}") from exc

    if not isinstance(payload, dict):
        raise AuditError("hook audit JSON 顶层必须是对象")
    return payload


def unwrap_hooks_result(payload: dict[str, Any]) -> dict[str, Any]:
    if isinstance(payload.get("result"), dict):
        result = payload["result"]
    else:
        result = payload

    if not isinstance(result.get("data"), list):
        raise AuditError("hooks/list 结果缺少 data 数组")
    return result


def send_json(proc: subprocess.Popen[str], message: dict[str, Any]) -> None:
    if proc.stdin is None:
        raise AuditError("app-server stdin 不可用")
    proc.stdin.write(json.dumps(message, separators=(",", ":")) + "\n")
    proc.stdin.flush()


def read_json_response(
    proc: subprocess.Popen[str],
    request_id: int,
    timeout_sec: float,
) -> dict[str, Any]:
    if proc.stdout is None:
        raise AuditError("app-server stdout 不可用")

    deadline = time.monotonic() + timeout_sec
    stderr_tail: list[str] = []

    while time.monotonic() < deadline:
        streams = [proc.stdout]
        if proc.stderr is not None:
            streams.append(proc.stderr)
        ready, _, _ = select.select(streams, [], [], 0.2)
        for stream in ready:
            line = stream.readline()
            if not line:
                continue
            if stream is proc.stderr:
                stderr_tail.append(line.rstrip("\n"))
                stderr_tail = stderr_tail[-5:]
                continue
            try:
                message = json.loads(line)
            except json.JSONDecodeError:
                continue
            if message.get("id") != request_id:
                continue
            if "error" in message:
                raise AuditError(f"app-server request {request_id} 失败: {message['error']}")
            if not isinstance(message.get("result"), dict):
                raise AuditError(f"app-server request {request_id} 返回格式异常")
            return message

    detail = ""
    if stderr_tail:
        detail = "；stderr tail: " + " | ".join(stderr_tail)
    raise AuditError(f"等待 app-server request {request_id} 超时{detail}")


def query_hooks_via_app_server(
    *,
    codex_bin: str,
    codex_home: Path,
    cwds: list[str],
    timeout_sec: float,
) -> dict[str, Any]:
    env = os.environ.copy()
    env["CODEX_HOME"] = str(codex_home)
    env.setdefault("TERM", "dumb")
    env.setdefault("NO_COLOR", "1")

    proc = subprocess.Popen(
        [codex_bin, "app-server", "--enable", "hooks"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=0,
        env=env,
    )

    try:
        send_json(
            proc,
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                    "clientInfo": {
                        "name": "org-codex-hook-trust-audit",
                        "version": "1.0.0",
                    }
                },
            },
        )
        read_json_response(proc, 1, timeout_sec)
        send_json(
            proc,
            {"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}},
        )
        send_json(
            proc,
            {
                "jsonrpc": "2.0",
                "id": 2,
                "method": "hooks/list",
                "params": {"cwds": cwds},
            },
        )
        response = read_json_response(proc, 2, timeout_sec)
        return unwrap_hooks_result(response)
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill()


def iter_hooks(result: dict[str, Any]) -> list[dict[str, Any]]:
    hooks: list[dict[str, Any]] = []
    for cwd_result in result["data"]:
        if not isinstance(cwd_result, dict):
            continue
        cwd = cwd_result.get("cwd", "")
        for hook in cwd_result.get("hooks", []) or []:
            if not isinstance(hook, dict):
                continue
            enriched = dict(hook)
            enriched["_cwd"] = cwd
            hooks.append(enriched)
    return hooks


def hook_label(hook: dict[str, Any]) -> str:
    event = hook.get("eventName", "?")
    matcher = hook.get("matcher")
    command = hook.get("command", "")
    status = hook.get("trustStatus", "?")
    if matcher:
        return f"{event} [{matcher}] {status} :: {command}"
    return f"{event} {status} :: {command}"


def audit_result(
    result: dict[str, Any],
    *,
    expected_commands: list[str],
    require_ready: bool,
    require_all_enabled: bool,
) -> int:
    hooks = iter_hooks(result)
    command_set = {str(hook.get("command", "")) for hook in hooks}
    missing = [command for command in expected_commands if command not in command_set]

    enabled_hooks = [hook for hook in hooks if hook.get("enabled") is not False]
    if require_all_enabled:
        audited_hooks = enabled_hooks
    elif expected_commands:
        expected = set(expected_commands)
        audited_hooks = [hook for hook in enabled_hooks if hook.get("command") in expected]
    else:
        audited_hooks = enabled_hooks

    not_ready = [
        hook
        for hook in audited_hooks
        if str(hook.get("trustStatus", "")).lower() not in READY_STATUSES
    ]

    print(f"Codex hook audit: total={len(hooks)} enabled={len(enabled_hooks)} audited={len(audited_hooks)}")
    if missing:
        print("缺少预期 Codex hook command:")
        for command in missing:
            print(f"  - {command}")

    if not_ready:
        print("需要在 Codex 中 review/trust 的 enabled hook:")
        for hook in not_ready:
            print(f"  - {hook_label(hook)}")

    ready_count = len(audited_hooks) - len(not_ready)
    print(f"ready={ready_count} not_ready={len(not_ready)}")

    if missing:
        return 1
    if require_ready and not_ready:
        print("处理方式: 打开 Codex，在当前仓库运行 /hooks，逐条核对命令和路径后信任；然后重新运行 quick check。")
        print("安全原因: Codex hooks 可在 sandbox 外以当前系统用户权限运行，安装脚本不会自动写入 trust。")
        return 2
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Audit Codex hook trust/readiness via hooks/list."
    )
    parser.add_argument("--codex-bin", default=shutil.which("codex") or "codex")
    parser.add_argument("--codex-home", default=os.environ.get("CODEX_HOME", "~/.codex"))
    parser.add_argument("--cwd", action="append", default=[])
    parser.add_argument("--timeout", type=float, default=10.0)
    parser.add_argument("--from-json", help="Read an existing hooks/list JSON result instead of launching Codex.")
    parser.add_argument("--expected-command", action="append", default=[])
    parser.add_argument("--require-ready", action="store_true")
    parser.add_argument(
        "--require-all-enabled",
        action="store_true",
        help="Require every enabled hook returned by hooks/list to be trusted or managed.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if args.from_json:
            result = unwrap_hooks_result(load_json_payload(args.from_json))
        else:
            codex_bin = shutil.which(args.codex_bin) if os.path.sep not in args.codex_bin else args.codex_bin
            if not codex_bin:
                raise AuditError("未找到 codex CLI，无法验证 hook trust 状态")
            cwds = args.cwd or [os.getcwd()]
            result = query_hooks_via_app_server(
                codex_bin=codex_bin,
                codex_home=Path(args.codex_home).expanduser(),
                cwds=cwds,
                timeout_sec=args.timeout,
            )
        return audit_result(
            result,
            expected_commands=args.expected_command,
            require_ready=args.require_ready,
            require_all_enabled=args.require_all_enabled,
        )
    except AuditError as exc:
        print(f"Codex hook audit failed: {exc}", file=sys.stderr)
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
