#!/usr/bin/env python3
"""Emit deterministic Codex JSONL for evaluator tests without a model call."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import sys
import time


def _verdicts(schema: dict, field: str, value: bool) -> list[dict]:
    return [
        {"id": identifier, field: value, "evidence": "fixture evidence"}
        for identifier in schema["items"]["properties"]["id"]["enum"]
    ]


def main() -> int:
    args = sys.argv[1:]
    mode = os.environ.get("FAKE_CODEX_MODE", "pass")
    if args == ["--version"]:
        if mode == "version_failure":
            print("fake Codex version failure", file=sys.stderr)
            return 1
        print("fake-codex 1.0.0")
        return 0
    output_path = Path(args[args.index("--output-last-message") + 1])
    prompt = args[-1]
    if "--output-schema" in args:
        schema_path = Path(args[args.index("--output-schema") + 1])
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        properties = schema["properties"]
        grading = {
            "expectations": _verdicts(properties["expectations"], "met", True),
            "anti_patterns": _verdicts(properties["anti_patterns"], "present", False),
            "blocking_failures": _verdicts(properties["blocking_failures"], "present", False),
            "anchors": [
                {"id": identifier, "score": 2, "evidence": "fixture evidence"}
                for identifier in properties["anchors"]["items"]["properties"]["id"]["enum"]
            ],
            "behavior_verdict": "PASS",
            "added_ceremony_without_decision_value": False,
            "rationale": "fixture grading result",
        }
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(grading, ensure_ascii=False), encoding="utf-8")
        grader_log = os.environ.get("FAKE_GRADER_LOG")
        if grader_log:
            payload = {
                "home": os.environ.get("HOME", ""),
                "codex_home": os.environ.get("CODEX_HOME", ""),
                "prompt": prompt.lower(),
            }
            with Path(grader_log).open("a", encoding="utf-8") as handle:
                handle.write(json.dumps(payload, sort_keys=True) + "\n")
        return 0
    log_path = os.environ.get("FAKE_CODEX_LOG")
    if log_path:
        payload = {
            "codex_home": os.environ.get("CODEX_HOME", ""),
            "home": os.environ.get("HOME", ""),
            "model": args[args.index("--model") + 1],
            "reasoning": args[args.index("model_reasoning_effort=") + 1]
            if "model_reasoning_effort=" in args
            else next(arg for arg in args if arg.startswith("model_reasoning_effort=")),
            "prompt_sha256": hashlib.sha256(prompt.encode("utf-8")).hexdigest(),
            "workspace": args[args.index("-C") + 1],
        }
        with Path(log_path).open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(payload, sort_keys=True) + "\n")
    if mode == "timeout":
        print('{"type":"item.started","item":{"id":"partial","type":"command_execution"}}')
        sys.stdout.flush()
        time.sleep(60)
        return 0
    if mode == "timeout_malformed":
        print('{"type":"item.started"')
        sys.stdout.flush()
        time.sleep(60)
        return 0
    if mode == "process":
        print('{"type":"item.completed","item":{"id":"failed","type":"command_execution","command":"cat /missing","exit_code":1,"status":"failed","aggregated_output":"missing"}}')
        return 7
    if mode == "process_malformed":
        print('{"type":"item.completed"')
        return 7
    if mode == "missing_output_malformed":
        print('{"type":"item.completed"')
        return 0

    codex_home = Path(os.environ["CODEX_HOME"])
    installed_paths = (
        "rules/code-changes.md",
        "rules/completion-claims.md",
        "reference/协作判断.md",
        "reference/测试规范.md",
        "reference/code-structure-reuse.md",
        "reference/code-comments.md",
        "reference/error-handling.md",
        "reference/constants-and-configuration.md",
        "reference/performance-and-efficiency.md",
        "reference/技术方案设计.md",
        "reference/impact-analysis.md",
        "reference/系统调试.md",
        "reference/全栈开发.md",
    )
    events = []
    for relative_path in installed_paths:
        path = codex_home / relative_path
        events.append(
            {
                "type": "item.completed",
                "item": {
                    "id": f"read-{len(events)}",
                    "type": "command_execution",
                    "command": f"cat {path}",
                    "exit_code": 0,
                    "status": "completed",
                    "aggregated_output": "read",
                },
            }
        )
    if mode != "missing_message":
        events.append(
            {"type": "item.completed", "item": {"id": "final", "type": "agent_message", "text": "fake response"}}
        )
    for event in events:
        print(json.dumps(event, ensure_ascii=False))
    if mode == "unknown_shape":
        print('{"type":"unexpected.event","payload":{"value":"unknown"}}')
    if mode != "missing_output":
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text("fake response\n", encoding="utf-8")
    if os.environ.get("FAKE_CODEX_STDERR"):
        print(os.environ["FAKE_CODEX_STDERR"], file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
