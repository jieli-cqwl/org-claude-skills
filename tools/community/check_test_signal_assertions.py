#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import shlex
import sys
from pathlib import Path
from typing import Callable, NamedTuple

from check_test_signal_python import ShellUnit, python_file_findings, python_heredoc_findings
from check_test_signal_rules import is_markdown_prose_target, low_signal_kind
from check_test_signal_shell import (
    assertion_calls,
    closes_loop,
    collect_assignments,
    collect_function_arities,
    expand_pattern,
    expand_target,
    loop_binding,
    resolve_target,
    search_calls,
    shell_words,
)

HEREDOC_RE = re.compile(r"<<-?['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?")
FUNCTION_START_RE = re.compile(
    r"^(?:function\s+)?([A-Za-z_][A-Za-z0-9_]*)(?:\s*\(\))?\s*\{"
)
VARARGS_TOKENS = {"$@", "${@}", "$*", "${*}"}


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
    resolved_pattern = resolve_target(pattern, assignments)
    resolved_target = resolve_target(target, assignments)
    if not is_markdown_prose_target(resolved_target):
        return None
    kind = low_signal_kind(assertion, resolved_pattern)
    if kind is None:
        return None
    return Finding(path, line_no, assertion, kind, resolved_pattern, resolved_target)


def shell_call_findings(
    command: str,
    relative_path: str,
    assignments: dict[str, str],
    line_no: int,
    arities: dict[str, int],
    loop_values: dict[str, list[str]],
) -> list[Finding]:
    calls = assertion_calls(command, arities)
    calls.extend(SearchCall(call.pattern, call.target) for call in search_calls(command))
    findings: list[Finding] = []
    for call in calls:
        for pattern in expand_pattern(call.pattern, loop_values):
            for target in expand_target(call.target, loop_values):
                finding = build_finding(
                    relative_path,
                    assignments,
                    line_no,
                    getattr(call, "assertion", "present"),
                    pattern,
                    target,
                )
                if finding is not None:
                    findings.append(finding)
    return findings


def scan_file(path: Path, root: Path) -> list[Finding]:
    lines = read_lines(path)
    if lines is None:
        return []
    relative_path = display_path(path, root)

    def add_finding(
        line: int, assertion: str, pattern: str, target: str
    ) -> Finding | None:
        return build_finding(relative_path, {}, line, assertion, pattern, target)

    if path.suffix == ".py":
        return [
            finding
            for finding in python_file_findings(lines, add_finding)
            if finding is not None
        ]

    units = shell_units(lines)
    commands = [unit.command for unit in units if unit.kind == "command"]
    assignments = collect_assignments(commands)
    arities = collect_function_arities(commands)
    findings: list[Finding] = []
    loop_stack: list[tuple[str, list[str]]] = []

    def add_shell_finding(
        line: int, assertion: str, pattern: str, target: str
    ) -> Finding | None:
        return build_finding(
            relative_path, assignments, line, assertion, pattern, target
        )

    def active_loop_values() -> dict[str, list[str]]:
        values: dict[str, list[str]] = {}
        for name, loop_values in loop_stack:
            values[name] = loop_values
        return values

    def assignment_variants(loop_values: dict[str, list[str]]) -> list[dict[str, str]]:
        variants = [assignments]
        for name, values in loop_values.items():
            variants = [
                {**variant, name: value}
                for variant in variants
                for value in values
            ]
        return variants

    for unit in units:
        unit_loop_values = active_loop_values()
        if unit.kind == "command":
            binding = loop_binding(unit.command)
            if binding is not None:
                loop_stack.append(binding)
                unit_loop_values = active_loop_values()
        if unit.kind == "heredoc":
            if re.search(r"(^|[\s;(])python3?\b", unit.command):
                for variant in assignment_variants(unit_loop_values):
                    findings.extend(
                        python_heredoc_findings(unit, add_shell_finding, variant)
                    )
            continue
        findings.extend(
            shell_call_findings(
                unit.command,
                relative_path,
                assignments,
                unit.line,
                arities,
                unit_loop_values,
            )
        )
        if unit.kind == "command" and closes_loop(unit.command) and loop_stack:
            loop_stack.pop()
    findings.extend(scan_function_calls(units, relative_path, assignments, add_shell_finding))
    return findings


def collect_function_bodies(units: list[ShellUnit]) -> dict[str, list[ShellUnit]]:
    bodies: dict[str, list[ShellUnit]] = {}
    current_name: str | None = None
    current_body: list[ShellUnit] = []
    depth = 0
    for unit in units:
        if unit.kind == "command":
            stripped = unit.command.strip()
            if current_name is None:
                match = FUNCTION_START_RE.match(stripped)
                if match:
                    current_name = match.group(1)
                    current_body = inline_function_units(unit, stripped)
                    depth = stripped.count("{") - stripped.count("}")
                    if depth <= 0:
                        bodies[current_name] = current_body
                        current_name = None
                    continue
            else:
                depth += stripped.count("{") - stripped.count("}")
                if depth <= 0:
                    bodies[current_name] = current_body
                    current_name = None
                    current_body = []
                    continue
        if current_name is not None:
            current_body.append(unit)
    return bodies


def inline_function_units(unit: ShellUnit, stripped: str) -> list[ShellUnit]:
    if "{" not in stripped:
        return []
    content = stripped.split("{", 1)[1]
    if "}" in content:
        content = content.rsplit("}", 1)[0]
    return [
        ShellUnit("command", unit.line, part.strip(), [])
        for part in content.split(";")
        if part.strip()
    ]


def function_call_args(command: str, function_names: set[str]) -> tuple[str, list[str]] | None:
    words = shell_words(command)
    if not words or words[0] not in function_names:
        return None
    return words[0], words[1:]


def shell_positional_value(value: str, args: list[str]) -> str | None:
    try:
        words = shlex.split(value, comments=False, posix=True)
    except ValueError:
        words = [value]
    if len(words) != 1:
        return None
    word = words[0]
    match = re.fullmatch(r"\$\{?([0-9]+)\}?", word)
    if not match:
        return word
    index = int(match.group(1)) - 1
    if index < 0 or index >= len(args):
        return None
    return args[index]


def function_local_assignments(body: list[ShellUnit], args: list[str]) -> dict[str, str]:
    assignments: dict[str, str] = {}
    for unit in body:
        if unit.kind != "command":
            continue
        words = shell_words(unit.command.strip()) or []
        if not words:
            continue
        candidates = words[1:] if words[0] == "local" else words
        for word in candidates:
            if "=" not in word:
                continue
            name, raw_value = word.split("=", 1)
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
                continue
            value = shell_positional_value(raw_value, args)
            if value is not None:
                assignments[name] = value
    return assignments


def loop_binding_with_function_args(
    command: str, active_args: list[str]
) -> tuple[str, list[str]] | None:
    binding = loop_binding(command)
    if binding is not None:
        return binding
    match = re.match(
        r"^for\s+([A-Za-z_][A-Za-z0-9_]*)\s+in\s+(.+?);?\s*(?:do)?$",
        command.strip(),
    )
    if not match:
        return None
    raw_values = match.group(2).removesuffix("do").strip()
    words = shell_words(raw_values) or []
    if not words or any(word not in VARARGS_TOKENS for word in words):
        return None
    return match.group(1), active_args


def shifted_function_args(command: str, active_args: list[str]) -> list[str]:
    words = shell_words(command.strip()) or []
    if not words or words[0] != "shift":
        return active_args
    shift_count = 1
    if len(words) > 1:
        try:
            shift_count = max(0, int(words[1]))
        except ValueError:
            return active_args
    return active_args[shift_count:]


def scan_function_calls(
    units: list[ShellUnit],
    relative_path: str,
    global_assignments: dict[str, str],
    add_finding: Callable[[int, str, str, str], Finding | None],
) -> list[Finding]:
    bodies = collect_function_bodies(units)
    if not bodies:
        return []
    findings: list[Finding] = []
    for unit in units:
        if unit.kind != "command":
            continue
        call = function_call_args(unit.command, set(bodies))
        if call is None:
            continue
        name, args = call
        positional_assignments = {
            str(index): value for index, value in enumerate(args, start=1)
        }
        assignments = {
            **global_assignments,
            **positional_assignments,
            **function_local_assignments(bodies[name], args),
        }

        def add_local_finding(
            line: int, assertion: str, pattern: str, target: str
        ) -> Finding | None:
            return build_finding(relative_path, assignments, line, assertion, pattern, target)

        function_loop_stack: list[tuple[str, list[str]]] = []
        active_args = list(args)

        def active_function_loop_values() -> dict[str, list[str]]:
            values: dict[str, list[str]] = {}
            for loop_name, values_for_name in function_loop_stack:
                values[loop_name] = values_for_name
            return values

        for body_unit in bodies[name]:
            if body_unit.kind == "command":
                active_args = shifted_function_args(body_unit.command, active_args)
                binding = loop_binding_with_function_args(body_unit.command, active_args)
                if binding is not None:
                    function_loop_stack.append(binding)
                findings.extend(
                    shell_call_findings(
                        body_unit.command,
                        relative_path,
                        assignments,
                        unit.line,
                        {},
                        active_function_loop_values(),
                    )
                )
                if closes_loop(body_unit.command) and function_loop_stack:
                    function_loop_stack.pop()
                continue
            if body_unit.kind != "heredoc":
                continue
            if re.search(r"(^|[\s;(])python3?\b", body_unit.command):
                findings.extend(
                    finding
                    for finding in python_heredoc_findings(
                        body_unit,
                        add_local_finding,
                        assignments,
                        track_collections=True,
                        collection_filter="all",
                    )
                    if finding is not None
                )
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
        and (
            path.name.startswith("test-")
            or path.name.startswith("test_")
            or path.suffix in {".sh", ".bash", ".py"}
        )
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
