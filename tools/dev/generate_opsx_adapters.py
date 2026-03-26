#!/usr/bin/env python3
"""Generate or verify OpenSpec command adapters from upstream templates."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
OPEN_SPEC_ROOT = REPO_ROOT / "third_party" / "community" / "openspec"
CLAUDE_OUT = REPO_ROOT / "community-adapters" / "claude" / "commands" / "opsx"
CODEX_OUT = REPO_ROOT / "community-adapters" / "codex" / "prompts"

COMMAND_SPECS = [
    {
        "id": "propose",
        "source": OPEN_SPEC_ROOT / "src" / "core" / "templates" / "workflows" / "propose.ts",
        "export": "getOpsxProposeCommandTemplate",
    },
    {
        "id": "apply",
        "source": OPEN_SPEC_ROOT / "src" / "core" / "templates" / "workflows" / "apply-change.ts",
        "export": "getOpsxApplyCommandTemplate",
    },
    {
        "id": "verify",
        "source": OPEN_SPEC_ROOT / "src" / "core" / "templates" / "workflows" / "verify-change.ts",
        "export": "getOpsxVerifyCommandTemplate",
    },
    {
        "id": "archive",
        "source": OPEN_SPEC_ROOT / "src" / "core" / "templates" / "workflows" / "archive-change.ts",
        "export": "getOpsxArchiveCommandTemplate",
    },
]


def extract_block(source_text: str, export_name: str) -> str:
    pattern = re.compile(
        rf"export function {re.escape(export_name)}\(\): CommandTemplate \{{\s*return \{{(?P<body>.*?)\n  \}};\n\}}",
        re.DOTALL,
    )
    match = pattern.search(source_text)
    if not match:
        raise ValueError(f"Failed to locate export block: {export_name}")
    return match.group("body")


def extract_field(block: str, field: str) -> str:
    match = re.search(rf"{re.escape(field)}:\s*'([^']*)'", block)
    if not match:
        raise ValueError(f"Missing field '{field}' in command template")
    return match.group(1)


def extract_tags(block: str) -> list[str]:
    match = re.search(r"tags:\s*\[(.*?)\]", block, re.DOTALL)
    if not match:
        raise ValueError("Missing field 'tags' in command template")
    return re.findall(r"'([^']+)'", match.group(1))


def extract_content(block: str) -> str:
    match = re.search(r"content:\s*`(?P<content>.*)`\s*$", block, re.DOTALL)
    if not match:
        raise ValueError("Missing field 'content' in command template")
    return match.group("content").replace("\\`", "`").rstrip() + "\n"


def escape_yaml(value: str) -> str:
    if re.search(r"[:\n\r#{}[\],&*!|>'\"%@`]|^\s|\s$", value):
        escaped = value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
        return f'"{escaped}"'
    return value


def format_tags(tags: list[str]) -> str:
    return "[" + ", ".join(escape_yaml(tag) for tag in tags) + "]"


def build_outputs(spec: dict[str, Path | str]) -> tuple[Path, str, Path, str]:
    source_text = Path(spec["source"]).read_text(encoding="utf-8")
    block = extract_block(source_text, str(spec["export"]))
    name = extract_field(block, "name")
    description = extract_field(block, "description")
    category = extract_field(block, "category")
    tags = extract_tags(block)
    content = extract_content(block)
    command_id = str(spec["id"])

    claude_text = (
        "---\n"
        f"name: {escape_yaml(name)}\n"
        f"description: {escape_yaml(description)}\n"
        f"category: {escape_yaml(category)}\n"
        f"tags: {format_tags(tags)}\n"
        "---\n\n"
        f"{content}"
    )
    codex_text = (
        "---\n"
        f"description: {escape_yaml(description)}\n"
        "argument-hint: command arguments\n"
        "---\n\n"
        f"{content}"
    )

    return (
        CLAUDE_OUT / f"{command_id}.md",
        claude_text,
        CODEX_OUT / f"opsx-{command_id}.md",
        codex_text,
    )


def write_outputs() -> int:
    for spec in COMMAND_SPECS:
        claude_path, claude_text, codex_path, codex_text = build_outputs(spec)
        claude_path.parent.mkdir(parents=True, exist_ok=True)
        codex_path.parent.mkdir(parents=True, exist_ok=True)
        claude_path.write_text(claude_text, encoding="utf-8")
        codex_path.write_text(codex_text, encoding="utf-8")
    return 0


def check_outputs() -> int:
    mismatches: list[str] = []
    for spec in COMMAND_SPECS:
        claude_path, claude_text, codex_path, codex_text = build_outputs(spec)
        if not claude_path.is_file():
            mismatches.append(f"Missing file: {claude_path}")
        elif claude_path.read_text(encoding="utf-8") != claude_text:
            mismatches.append(f"Out of sync: {claude_path}")

        if not codex_path.is_file():
            mismatches.append(f"Missing file: {codex_path}")
        elif codex_path.read_text(encoding="utf-8") != codex_text:
            mismatches.append(f"Out of sync: {codex_path}")

    if mismatches:
        for item in mismatches:
            print(item, file=sys.stderr)
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="Validate repository adapters against upstream templates")
    args = parser.parse_args()
    return check_outputs() if args.check else write_outputs()


if __name__ == "__main__":
    raise SystemExit(main())
