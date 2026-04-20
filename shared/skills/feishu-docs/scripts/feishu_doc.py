#!/usr/bin/env python3
"""Safe command preview and execution helper for Feishu `lark-cli` docs work."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass

CLI = "lark-cli"
READ_OPS = {"fetch", "search"}
WRITE_OPS = {"create", "append", "replace_range", "insert_before", "insert_after"}
DESTRUCTIVE_OPS = {"overwrite", "delete_range", "delete_file"}
SECRET_KEY_PATTERN = re.compile(
    r"(?P<prefix>[\"']?(?:tenant_access_token|user_access_token|app_access_token|refresh_token|app_secret)[\"']?\s*[:=]\s*[\"']?)"
    r"(?P<secret>[^\"'\s,}]+)"
    r"(?P<suffix>[\"']?)",
    re.IGNORECASE,
)
AUTHORIZATION_JSON_PATTERN = re.compile(
    r"(?P<prefix>[\"']?Authorization[\"']?\s*:\s*[\"']?Bearer\s+)"
    r"(?P<secret>[^\"'}\s]+)"
    r"(?P<suffix>[\"']?)",
    re.IGNORECASE,
)
AUTHORIZATION_HEADER_PATTERN = re.compile(
    r"(?P<prefix>Authorization:\s*Bearer\s+)(?P<secret>\S+)",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class CommandPlan:
    """Command metadata returned before optional execution."""

    operation: str
    risk: str
    execute: bool
    argv: list[str]


def redact(text: str) -> str:
    """Mask token-like CLI output before it is shown to the user."""
    redacted = SECRET_KEY_PATTERN.sub(r"\g<prefix>[REDACTED]\g<suffix>", text)
    redacted = AUTHORIZATION_JSON_PATTERN.sub(r"\g<prefix>[REDACTED]\g<suffix>", redacted)
    return AUTHORIZATION_HEADER_PATTERN.sub(r"\g<prefix>[REDACTED]", redacted)


def risk_for(operation: str) -> str:
    """Return the safety risk category for a supported operation."""
    if operation in READ_OPS:
        return "read"
    if operation in WRITE_OPS:
        return "write"
    if operation in DESTRUCTIVE_OPS:
        return "destructive"
    raise ValueError(f"unsupported operation: {operation}")


def require_value(name: str, value: str) -> None:
    """Require a non-empty CLI argument before command preview."""
    if not value:
        raise ValueError(f"{name} is required")


def append_optional(argv: list[str], flag: str, value: str) -> None:
    """Append a flag-value pair only when the value is non-empty."""
    if value:
        argv.extend([flag, value])


def append_selection(argv: list[str], args: argparse.Namespace) -> None:
    """Append exactly one supported Feishu document selection option."""
    if args.selection_by_title and args.selection_with_ellipsis:
        raise ValueError("use one selection mode: --selection-by-title or --selection-with-ellipsis")
    if args.selection_by_title:
        argv.extend(["--selection-by-title", args.selection_by_title])
        return
    if args.selection_with_ellipsis:
        argv.extend(["--selection-with-ellipsis", args.selection_with_ellipsis])
        return
    raise ValueError("selection is required")


def require_second_confirmation(args: argparse.Namespace) -> None:
    """Require destructive operations to name the target token or title twice."""
    if args.operation not in DESTRUCTIVE_OPS:
        return
    allowed = {args.target}
    if args.target_title:
        allowed.add(args.target_title)
    if args.second_confirmation not in allowed:
        raise PermissionError("second confirmation must match target token or target title")


def build_docs_command(args: argparse.Namespace) -> CommandPlan:
    """Build a `lark-cli` command without executing it."""
    risk = risk_for(args.operation)
    if risk in {"write", "destructive"} and not args.confirmed:
        raise PermissionError("confirmation required for write and destructive operations")
    require_second_confirmation(args)

    if args.operation == "fetch":
        require_value("--target", args.target)
        argv = [CLI, "docs", "+fetch", "--doc", args.target]
        append_optional(argv, "--format", args.format)
    elif args.operation == "search":
        require_value("--target", args.target)
        argv = [CLI, "docs", "+search", "--query", args.target]
    elif args.operation == "create":
        require_value("--title", args.title)
        require_value("--markdown", args.markdown)
        argv = [CLI, "docs", "+create", "--title", args.title, "--markdown", args.markdown]
        append_optional(argv, "--folder-token", args.folder_token)
        append_optional(argv, "--wiki-node", args.wiki_node)
        append_optional(argv, "--wiki-space", args.wiki_space)
    elif args.operation in {"append", "overwrite"}:
        require_value("--target", args.target)
        require_value("--markdown", args.markdown)
        argv = [CLI, "docs", "+update", "--doc", args.target, "--mode", args.operation, "--markdown", args.markdown]
    elif args.operation in {"replace_range", "insert_before", "insert_after"}:
        require_value("--target", args.target)
        require_value("--markdown", args.markdown)
        argv = [CLI, "docs", "+update", "--doc", args.target, "--mode", args.operation]
        append_selection(argv, args)
        argv.extend(["--markdown", args.markdown])
    elif args.operation == "delete_range":
        require_value("--target", args.target)
        argv = [CLI, "docs", "+update", "--doc", args.target, "--mode", "delete_range"]
        append_selection(argv, args)
    elif args.operation == "delete_file":
        require_value("--target", args.target)
        require_value("--file-type", args.file_type)
        argv = [CLI, "drive", "+delete", "--file-token", args.target, "--type", args.file_type, "--yes"]
    else:
        raise ValueError(f"unsupported operation: {args.operation}")

    return CommandPlan(operation=args.operation, risk=risk, execute=args.execute, argv=argv)


def run_doctor() -> int:
    """Check that the official CLI is available; do not install or fallback."""
    if shutil.which(CLI) is None:
        print(
            "lark-cli not found; install @larksuite/cli and run lark-cli auth login; no fallback tool will be used.",
            file=sys.stderr,
        )
        return 3
    version = subprocess.run(
        [CLI, "--version"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=15,
        check=False,
    )
    print(redact(version.stdout or version.stderr), end="")
    return version.returncode


def ensure_cli_for_execution() -> None:
    """Fail closed before executing if the official CLI is unavailable."""
    if shutil.which(CLI) is None:
        raise FileNotFoundError("lark-cli not found; no fallback tool will be used")


def run_preview(args: argparse.Namespace) -> int:
    """Print a JSON command plan and optionally execute with timeout."""
    try:
        plan = build_docs_command(args)
    except PermissionError as exc:
        print(str(exc), file=sys.stderr)
        return 2
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 2

    payload: dict[str, object] = {
        "operation": plan.operation,
        "risk": plan.risk,
        "execute": plan.execute,
        "argv": plan.argv,
    }
    if not args.execute:
        print(json.dumps(payload, ensure_ascii=False, sort_keys=True))
        return 0

    try:
        ensure_cli_for_execution()
    except FileNotFoundError as exc:
        print(str(exc), file=sys.stderr)
        return 3

    completed = subprocess.run(
        plan.argv,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=args.timeout,
        check=False,
    )
    payload["returncode"] = completed.returncode
    payload["stdout"] = redact(completed.stdout)
    payload["stderr"] = redact(completed.stderr)
    print(json.dumps(payload, ensure_ascii=False, sort_keys=True))
    return completed.returncode


def build_parser() -> argparse.ArgumentParser:
    """Create the command-line parser for the wrapper."""
    parser = argparse.ArgumentParser(description="Safe Feishu docs lark-cli helper")
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("doctor", help="Check lark-cli availability")
    subparsers.add_parser("redact", help="Redact token-like stdin")

    preview = subparsers.add_parser("preview", help="Build or execute a guarded command")
    preview.add_argument("--operation", required=True)
    preview.add_argument("--target", default="")
    preview.add_argument("--target-title", default="")
    preview.add_argument("--title", default="")
    preview.add_argument("--markdown", default="")
    preview.add_argument("--selection-by-title", default="")
    preview.add_argument("--selection-with-ellipsis", default="")
    preview.add_argument("--format", default="")
    preview.add_argument("--folder-token", default="")
    preview.add_argument("--wiki-node", default="")
    preview.add_argument("--wiki-space", default="")
    preview.add_argument("--file-type", default="docx")
    preview.add_argument("--confirmed", action="store_true")
    preview.add_argument("--second-confirmation", default="")
    preview.add_argument("--execute", action="store_true")
    preview.add_argument("--timeout", type=int, default=60)
    return parser


def main(argv: list[str] | None = None) -> int:
    """Run the requested helper command."""
    args = build_parser().parse_args(argv)
    if args.command == "doctor":
        return run_doctor()
    if args.command == "redact":
        print(redact(sys.stdin.read()), end="")
        return 0
    if args.command == "preview":
        return run_preview(args)
    print("unsupported command", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
