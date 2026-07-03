#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shlex
import sys
from pathlib import Path

CODEX_HOOK_EVENTS = [
    "SessionStart",
    "PreToolUse",
    "PermissionRequest",
    "PostToolUse",
    "PreCompact",
    "PostCompact",
    "UserPromptSubmit",
    "SubagentStart",
    "SubagentStop",
    "Stop",
]


def load_registry(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    validate_registry(data)
    return data


def validate_registry(registry: dict) -> None:
    gates = registry.get("skill_completion_gates")
    hooks = registry.get("runtime_hooks")
    if not isinstance(gates, list) or not gates:
        raise ValueError("skill_completion_gates must be a non-empty list")
    if not isinstance(hooks, list) or not hooks:
        raise ValueError("runtime_hooks must be a non-empty list")

    seen_skills: set[str] = set()
    for gate in gates:
        skill = gate.get("skill")
        handler_rel = gate.get("handler_rel")
        timeout_sec = gate.get("timeout_sec")
        if not isinstance(skill, str) or not skill:
            raise ValueError("gate missing skill")
        if skill in seen_skills:
            raise ValueError(f"duplicate skill gate: {skill}")
        seen_skills.add(skill)
        if not isinstance(handler_rel, str) or not handler_rel:
            raise ValueError(f"{skill}: missing handler_rel")
        if not isinstance(timeout_sec, int) or timeout_sec <= 0:
            raise ValueError(f"{skill}: invalid timeout_sec")
        for runtime in ("claude", "codex"):
            payload = gate.get(runtime)
            if not isinstance(payload, dict) or "supported" not in payload:
                raise ValueError(f"{skill}: missing runtime payload for {runtime}")

    seen_ids: set[str] = set()
    for hook in hooks:
        hook_id = hook.get("id")
        if not isinstance(hook_id, str) or not hook_id:
            raise ValueError("runtime hook missing id")
        if hook_id in seen_ids:
            raise ValueError(f"duplicate runtime hook id: {hook_id}")
        seen_ids.add(hook_id)
        for runtime in ("claude", "codex"):
            payload = hook.get(runtime)
            if not isinstance(payload, dict) or "supported" not in payload:
                raise ValueError(f"{hook_id}: missing runtime payload for {runtime}")
            args = payload.get("args")
            if args is not None and (
                not isinstance(args, list) or any(not isinstance(arg, str) for arg in args)
            ):
                raise ValueError(f"{hook_id}: args must be a list of strings")


def render_command(
    runtime_home: str, launcher: str, command_rel: str, python_launcher: str
) -> str:
    if launcher == "python3":
        validate_python_launcher(python_launcher)
        launcher = python_launcher
    return f"{launcher} {runtime_home}/{command_rel}"


def render_command_args(args: list[str] | None) -> str:
    if not args:
        return ""
    return " " + " ".join(shlex.quote(str(arg)) for arg in args)


def validate_python_launcher(python_launcher: str) -> None:
    if not python_launcher.strip():
        raise ValueError("python launcher must be non-empty")
    if any(char.isspace() for char in python_launcher):
        raise ValueError(f"python launcher must not contain whitespace: {python_launcher}")


def ordered_unique(items: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for item in items:
        if item in seen:
            continue
        seen.add(item)
        result.append(item)
    return result


def sort_hook_events(events: list[str]) -> list[str]:
    preferred = [
        "PreToolUse",
        "PostToolUse",
        "PreCompact",
        "PostCompact",
        "TaskCompleted",
        "Stop",
    ]
    ordered = [event for event in preferred if event in events]
    ordered.extend(sorted(event for event in events if event not in preferred))
    return ordered


def collect_claude_standard_events(registry: dict) -> list[str]:
    events: list[str] = []
    for gate in registry["skill_completion_gates"]:
        claude = gate["claude"]
        if claude.get("supported"):
            events.append(claude["event"])

    for hook in registry["runtime_hooks"]:
        claude = hook["claude"]
        if claude.get("supported"):
            events.append(claude["event"])

    return sort_hook_events(ordered_unique(events))


def feature_enabled(payload: dict, enabled_features: set[str]) -> bool:
    feature = payload.get("feature")
    return not isinstance(feature, str) or feature in enabled_features


def collect_codex_internal_events(registry: dict, enabled_features: set[str]) -> list[str]:
    events: list[str] = []
    for hook in registry["runtime_hooks"]:
        codex = hook["codex"]
        if codex.get("supported") and feature_enabled(codex, enabled_features) and codex.get("internal_only"):
            events.append(codex["event"])
    return ordered_unique(events)


def group_claude_skill_hooks(registry: dict) -> dict[str, list[dict]]:
    grouped: dict[str, list[dict]] = {}
    for gate in registry["skill_completion_gates"]:
        claude = gate["claude"]
        if not claude.get("supported"):
            continue
        grouped.setdefault(gate["skill"], []).append(
            {
                "event": claude["event"],
                "matcher": claude.get("matcher"),
                "timeout_sec": gate["timeout_sec"],
                "handler_rel": gate["handler_rel"],
            }
        )
    return grouped


def strip_hooks_section(frontmatter_lines: list[str]) -> list[str]:
    new_lines: list[str] = []
    i = 0
    while i < len(frontmatter_lines):
        line = frontmatter_lines[i]
        if line.startswith("hooks:"):
            i += 1
            while i < len(frontmatter_lines):
                next_line = frontmatter_lines[i]
                if next_line.startswith(" ") or next_line.startswith("\t"):
                    i += 1
                    continue
                break
            continue
        new_lines.append(line)
        i += 1
    return new_lines


def render_skill_hook_lines(
    entries: list[dict], runtime_home: str, python_launcher: str
) -> list[str]:
    grouped: dict[str, list[dict]] = {}
    for entry in entries:
        grouped.setdefault(entry["event"], []).append(entry)

    lines = ["hooks:"]
    for event, hook_entries in grouped.items():
        lines.append(f"  {event}:")
        for entry in hook_entries:
            matcher = entry.get("matcher")
            if matcher:
                lines.append(f'    - matcher: "{matcher}"')
                lines.append("      hooks:")
                lines.append("        - type: command")
                lines.append(
                    "          command: "
                    + render_command(
                        runtime_home, "bash", entry["handler_rel"], python_launcher
                    )
                )
                lines.append(f"          timeout: {entry['timeout_sec']}")
                continue

            lines.append("    - hooks:")
            lines.append("        - type: command")
            lines.append(
                "          command: "
                + render_command(runtime_home, "bash", entry["handler_rel"], python_launcher)
            )
            lines.append(f"          timeout: {entry['timeout_sec']}")

    return lines


def inject_claude_skill_hooks(
    registry: dict, skills_dir: Path, runtime_home: str, python_launcher: str
) -> None:
    grouped = group_claude_skill_hooks(registry)
    for skill_dir in sorted(skills_dir.iterdir()):
        if not skill_dir.is_dir():
            continue
        skill_file = skill_dir / "SKILL.md"
        if not skill_file.is_file():
            continue

        text = skill_file.read_text(encoding="utf-8")
        if not text.startswith("---\n"):
            continue

        parts = text.split("---\n", 2)
        if len(parts) != 3:
            continue

        _, frontmatter, body = parts
        frontmatter_lines = strip_hooks_section(frontmatter.splitlines())
        hook_lines = (
            render_skill_hook_lines(
                grouped.get(skill_dir.name, []), runtime_home, python_launcher
            )
            if skill_dir.name in grouped
            else []
        )

        if hook_lines:
            insert_idx = len(frontmatter_lines)
            for idx, line in enumerate(frontmatter_lines):
                if line.startswith("allowed-tools:"):
                    insert_idx = idx + 1
                    break
            frontmatter_lines = (
                frontmatter_lines[:insert_idx]
                + hook_lines
                + frontmatter_lines[insert_idx:]
            )

        new_frontmatter = "\n".join(frontmatter_lines).rstrip()
        updated = f"---\n{new_frontmatter}\n---\n{body}"
        if updated != text:
            skill_file.write_text(updated, encoding="utf-8")


def render_runtime_hook_entries(
    registry: dict,
    runtime: str,
    runtime_home: str,
    python_launcher: str,
    enabled_features: set[str] | None = None,
) -> dict:
    enabled_features = enabled_features or set()
    hooks: dict[str, list[dict]] = {}
    standard_events: list[str] = []
    internal_events: list[str] = []
    if runtime == "codex":
        standard_events = CODEX_HOOK_EVENTS[:]
        internal_events = collect_codex_internal_events(registry, enabled_features)
        unsupported_events = sorted(set(internal_events) - set(standard_events))
        if unsupported_events:
            raise ValueError(
                "Codex internal hooks use unsupported event(s): "
                + ", ".join(unsupported_events)
            )
        for event in standard_events + internal_events:
            hooks[event] = []

    for hook in registry["runtime_hooks"]:
        payload = hook[runtime]
        if not payload.get("supported"):
            continue
        if not feature_enabled(payload, enabled_features):
            continue

        event = payload["event"]
        if runtime == "codex" and event not in CODEX_HOOK_EVENTS:
            raise ValueError(f"Codex hook {hook['id']} uses unsupported event: {event}")
        command = render_command(
            runtime_home, payload["launcher"], payload["command_rel"], python_launcher
        ) + render_command_args(payload.get("args"))
        command_entry = {"type": "command", "command": command}
        timeout_sec = payload.get("timeout_sec")
        if timeout_sec:
            command_entry["timeout"] = timeout_sec

        event_entry = {"hooks": [command_entry]}
        matcher = payload.get("matcher")
        if matcher:
            event_entry["matcher"] = matcher

        hooks.setdefault(event, []).append(event_entry)

    rendered = {"hooks": hooks}
    if runtime == "codex":
        rendered["_org_skills"] = {
            "allowed_events": ordered_unique(standard_events + internal_events),
            "managed_only_events": internal_events,
        }
    return rendered


def main() -> int:
    parser = argparse.ArgumentParser(description="Render hook registry for Claude/Codex runtimes.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    settings_parser = subparsers.add_parser("claude-settings-fragment")
    settings_parser.add_argument("--registry", required=True)
    settings_parser.add_argument("--runtime-home", required=True)
    settings_parser.add_argument("--python-launcher", default="python3")

    inject_parser = subparsers.add_parser("inject-claude-skill-hooks")
    inject_parser.add_argument("--registry", required=True)
    inject_parser.add_argument("--skills-dir", required=True)
    inject_parser.add_argument("--runtime-home", required=True)
    inject_parser.add_argument("--python-launcher", default="python3")

    codex_parser = subparsers.add_parser("codex-hooks")
    codex_parser.add_argument("--registry", required=True)
    codex_parser.add_argument("--runtime-home", required=True)
    codex_parser.add_argument("--python-launcher", default="python3")
    codex_parser.add_argument("--enable-feature", action="append", default=[])

    args = parser.parse_args()
    registry = load_registry(Path(args.registry))

    if args.command == "claude-settings-fragment":
        payload = render_runtime_hook_entries(
            registry, "claude", args.runtime_home, args.python_launcher
        )
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return 0

    if args.command == "inject-claude-skill-hooks":
        inject_claude_skill_hooks(
            registry, Path(args.skills_dir), args.runtime_home, args.python_launcher
        )
        return 0

    if args.command == "codex-hooks":
        payload = render_runtime_hook_entries(
            registry,
            "codex",
            args.runtime_home,
            args.python_launcher,
            set(args.enable_feature),
        )
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return 0

    raise ValueError(f"unknown command: {args.command}")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pragma: no cover - fail-close CLI wrapper
        print(f"FATAL: {exc}", file=sys.stderr)
        raise SystemExit(1)
