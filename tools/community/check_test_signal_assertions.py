#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import NamedTuple

from check_test_signal_python import ShellUnit, python_heredoc_findings
from check_test_signal_rules import is_markdown_prose_target, low_signal_kind
from check_test_signal_shell import (
    assertion_calls,
    collect_assignments,
    collect_function_arities,
    collect_loop_values,
    expand_pattern,
    resolve_target,
    search_calls,
)

HEREDOC_RE = re.compile(r"<<-?['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?")


class Finding(NamedTuple):
    path: str
    line: int
    assertion: str
    kind: str
    pattern: str
    target: str


class AssertionCall(NamedTuple):
    assertion: str
    pattern: str
    target: str


class SearchCall(NamedTuple):
    pattern: str
    target: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Reject low-signal prose assertions against instruction Markdown."
    )
    parser.add_argument("--repo-root", type=Path, default=None)
    parser.add_argument("--tests-dir", type=Path, default=None)
    parser.add_argument("--scan-root", action="append", type=Path, default=[])
    return parser.parse_args()


def read_lines(path: Path) -> list[str] | None:
    try:
        return path.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError:
        return None
    except OSError as exc:
        raise SystemExit(f"cannot read {path}: {exc}") from exc


def shell_units(lines: list[str]) -> list[ShellUnit]:
    units: list[ShellUnit] = []
    heredoc_end: str | None = None
    heredoc_command = ""
    heredoc_line = 0
    body: list[str] = []
    start_line: int | None = None
    parts: list[str] = []
    for line_no, line in enumerate(lines, start=1):
        stripped = line.strip()
        if heredoc_end is not None:
            if stripped == heredoc_end:
                units.append(ShellUnit("heredoc", heredoc_line, heredoc_command, body))
                heredoc_end = None
                body = []
            else:
                body.append(line)
            continue
        if start_line is None:
            start_line = line_no
        fragment = line.rstrip()
        if fragment.endswith("\\"):
            parts.append(fragment[:-1].strip())
            continue
        parts.append(fragment.strip())
        command = " ".join(part for part in parts if part)
        units.append(ShellUnit("command", start_line, command, []))
        match = HEREDOC_RE.search(command)
        if match:
            heredoc_end = match.group(1)
            heredoc_command = command
            heredoc_line = line_no + 1
        start_line = None
        parts = []
    if parts and start_line is not None:
        units.append(ShellUnit("command", start_line, " ".join(parts), []))
    return units


def display_path(path: Path, root: Path) -> str:
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return path.as_posix()


def build_finding(
    path: str,
    assignments: dict[str, str],
    line_no: int,
    assertion: str,
    pattern: str,
    target: str,
) -> Finding | None:
    resolved_target = resolve_target(target, assignments)
    if not is_markdown_prose_target(resolved_target):
        return None
    kind = low_signal_kind(assertion, pattern)
    if kind is None:
        return None
    return Finding(path, line_no, assertion, kind, pattern, resolved_target)


def scan_file(path: Path, root: Path) -> list[Finding]:
    lines = read_lines(path)
    if lines is None:
        return []
    units = shell_units(lines)
    commands = [unit.command for unit in units if unit.kind == "command"]
    assignments = collect_assignments(commands)
    arities = collect_function_arities(commands)
    loop_values = collect_loop_values(commands)
    findings: list[Finding] = []
    relative_path = display_path(path, root)

    def add_finding(
        line: int, assertion: str, pattern: str, target: str
    ) -> Finding | None:
        return build_finding(
            relative_path, assignments, line, assertion, pattern, target
        )

    for unit in units:
        if unit.kind == "heredoc":
            if re.search(r"(^|[\s;(])python3?\b", unit.command):
                findings.extend(python_heredoc_findings(unit, add_finding, assignments))
            continue
        calls = assertion_calls(unit.command, arities)
        calls.extend(
            SearchCall(call.pattern, call.target) for call in search_calls(unit.command)
        )
        for call in calls:
            for pattern in expand_pattern(call.pattern, loop_values):
                finding = build_finding(
                    relative_path,
                    assignments,
                    unit.line,
                    getattr(call, "assertion", "present"),
                    pattern,
                    call.target,
                )
                if finding is not None:
                    findings.append(finding)
    return findings


def iter_scan_files(scan_root: Path) -> list[Path]:
    if not scan_root.exists():
        return []
    if scan_root.is_file():
        return [scan_root]
    return sorted(
        path
        for path in scan_root.rglob("*")
        if path.is_file()
        and (path.name.startswith("test-") or path.suffix in {".sh", ".bash"})
    )


def scan_roots(scan_roots: list[Path], root: Path) -> list[Finding]:
    findings: list[Finding] = []
    seen: set[Path] = set()
    for scan_root in scan_roots:
        for path in iter_scan_files(scan_root):
            resolved = path.resolve()
            if resolved in seen:
                continue
            seen.add(resolved)
            findings.extend(scan_file(path, root))
    return findings


def report_findings(findings: list[Finding]) -> int:
    if not findings:
        return 0
    for finding in sorted(findings):
        print(
            "LOW_SIGNAL_PROSE_ASSERTION "
            f"{finding.path}:{finding.line} {finding.assertion} {finding.kind}: "
            f"{finding.pattern} -> {finding.target}",
            file=sys.stderr,
        )
    return 1


def default_paths(args: argparse.Namespace) -> tuple[Path, list[Path]]:
    root = (args.repo_root or Path.cwd()).resolve()
    if args.tests_dir:
        return root, [args.tests_dir.resolve()]
    if args.scan_root:
        return root, [path.resolve() for path in args.scan_root]
    return root, [root / "tests", root / "tools"]


def main() -> int:
    args = parse_args()
    root, scan_roots_arg = default_paths(args)
    return report_findings(scan_roots(scan_roots_arg, root))


if __name__ == "__main__":
    raise SystemExit(main())
