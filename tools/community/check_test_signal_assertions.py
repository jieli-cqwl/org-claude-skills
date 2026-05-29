#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import shlex
import sys
from pathlib import Path
from typing import NamedTuple

from check_test_signal_python import ShellUnit, python_heredoc_findings

TARGET_MARKERS = (
    "shared/skills/",
    "shared/rules/",
    "shared/reference/",
    "shared/references/",
    "shared/agents/",
    "/references/",
    "/projections/",
)
CONTRACT_TOKENS = re.compile(
    r"(\.(?:json|ya?ml|py|sh|toml)\b|artifact://|sha256:|"
    r"\bvalidate_[A-Za-z0-9_]+\b|--[a-z0-9-]+|\$\{|"
    r"\b[A-Z]{1,5}-[A-Z0-9-]+\b|\bS\d+\b|"
    r"\b[A-Z][A-Z0-9]+(?:_[A-Z0-9]+)+\b|"
    r"^name:|^allowed-tools:|^disable-model-invocation:|"
    r"\b[a-z][a-z0-9]+(?:_[a-z0-9]+)+\b)"
)
ASSIGN_RE = re.compile(r"^(?:local\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$")
ASSERT_RE = re.compile(r"^assert_(present|absent)\b")
ASSERT_ANY_RE = re.compile(r"^assert_any_present\b")
SECTION_ASSERT_RE = re.compile(r"^assert_section_(present|absent)\b")
VAR_RE = re.compile(r"^\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?$")
HEREDOC_RE = re.compile(r"<<-?['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?")
RG_OPTIONS_WITH_VALUE = {
    "-A",
    "-B",
    "-C",
    "-g",
    "-m",
    "-t",
    "-T",
    "--after-context",
    "--before-context",
    "--context",
    "--glob",
    "--max-count",
    "--max-depth",
    "--path-separator",
    "--sort",
    "--type",
    "--type-not",
}
SHELL_STOP_TOKENS = {"|", "||", "&&", ";", "then", "do"}


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
    return parser.parse_args()


def read_lines(path: Path) -> list[str]:
    try:
        return path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        raise SystemExit(f"cannot read {path}: {exc}") from exc


def shell_words(line: str) -> list[str] | None:
    try:
        return shlex.split(line, comments=False, posix=True)
    except ValueError:
        return None


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


def collect_assignments(units: list[ShellUnit]) -> dict[str, str]:
    assignments = {}
    for unit in units:
        if unit.kind != "command":
            continue
        match = ASSIGN_RE.match(unit.command.strip())
        if not match:
            continue
        words = shell_words(match.group(2))
        if words and len(words) == 1:
            assignments[match.group(1)] = words[0]
    return assignments


def resolve_target(raw: str, assignments: dict[str, str]) -> str:
    match = VAR_RE.match(raw.strip())
    if match:
        return assignments.get(match.group(1), raw)
    return raw


def assertion_calls(line: str) -> list[AssertionCall]:
    stripped = line.strip()
    words = shell_words(stripped)
    if not words:
        return []
    match = ASSERT_RE.match(stripped)
    if match and len(words) >= 3:
        return [AssertionCall(match.group(1), words[1], words[2])]
    match = SECTION_ASSERT_RE.match(stripped)
    if match and len(words) >= 4:
        return [AssertionCall(match.group(1), words[3], words[1])]
    if ASSERT_ANY_RE.match(stripped) and len(words) >= 3:
        return [AssertionCall("present", pattern, words[1]) for pattern in words[2:]]
    return []


def token_stops_command(token: str) -> bool:
    return token in SHELL_STOP_TOKENS or token.startswith(">") or token.startswith("2>")


def search_args(words: list[str], grep_mode: bool) -> tuple[str | None, list[str]]:
    index = 1
    pattern = None
    while index < len(words):
        word = words[index]
        if token_stops_command(word):
            return None, []
        if word == "--":
            index += 1
            break
        if grep_mode and word in {"-e", "--regexp"}:
            if index + 1 >= len(words):
                return None, []
            pattern = words[index + 1]
            index += 2
            break
        if word.startswith("-"):
            has_value = (
                not grep_mode and "=" not in word and word in RG_OPTIONS_WITH_VALUE
            )
            index += 2 if has_value else 1
            continue
        pattern = word
        index += 1
        break
    if pattern is None and index < len(words):
        pattern = words[index]
        index += 1
    if pattern is None:
        return None, []
    return pattern, [word for word in words[index:] if not token_stops_command(word)]


def search_calls(line: str) -> list[SearchCall]:
    words = shell_words(line.strip())
    if not words:
        return []
    calls: list[SearchCall] = []
    for index, word in enumerate(words):
        if word not in {"rg", "grep"}:
            continue
        pattern, targets = search_args(words[index:], grep_mode=word == "grep")
        if pattern is not None:
            calls.extend(SearchCall(pattern, target) for target in targets)
    return calls


def is_markdown_prose_target(target: str) -> bool:
    haystack = target.replace("\\", "/").lower()
    return ".md" in haystack and any(marker in haystack for marker in TARGET_MARKERS)


def normalized_pattern(pattern: str) -> str:
    normalized = re.sub(r"^\^", "", pattern.strip())
    normalized = re.sub(r"\$$", "", normalized)
    return (
        normalized.replace(r"\`", "`")
        .replace(r"\.", ".")
        .replace(r"\+", "+")
        .replace(r"\-", "-")
    )


def has_contract_shape(pattern: str) -> bool:
    return bool(re.search(r"[|$\[\]{}()\\`/\"]", pattern))


def cjk_count(text: str) -> int:
    return len(re.findall(r"[一-鿿]", text))


def sentence_like(text: str) -> bool:
    return (
        text.count(" ") >= 6
        or cjk_count(text) >= 18
        or text.endswith((".", "。", "！", "？", "!", "?"))
    )


def machine_contract_literal(text: str) -> bool:
    if re.match(r"(name|allowed-tools|disable-model-invocation):", text):
        return True
    if re.match(r"(python3|bash|node|jq|rg|grep)\b", text):
        return True
    return bool(
        "/" in text
        and re.search(r"\.(?:md|json|py|sh|ya?ml|toml)\b", text)
        and not re.search(r"\s", text)
    )


def low_signal_kind(assertion: str, pattern: str) -> str | None:
    normalized = normalized_pattern(pattern)
    if machine_contract_literal(normalized):
        return None
    has_contract = bool(CONTRACT_TOKENS.search(normalized))
    if re.match(r"#{1,6}\s+", normalized):
        return "heading"
    if has_contract and has_contract_shape(normalized):
        if cjk_count(normalized) >= 2 or sentence_like(normalized):
            return "prose-wrapped-contract"
        return None
    if has_contract and re.search(r"[`_.:/-]", normalized):
        return None
    if assertion == "absent" and (
        cjk_count(normalized) >= 2 or sentence_like(normalized)
    ):
        return "absent-prose"
    if assertion == "present" and cjk_count(normalized) >= 2 and not has_contract:
        return "short-present-phrase"
    if (
        assertion == "present"
        and cjk_count(normalized) >= 2
        and re.search(r"\||\.\*|\[\[:[a-z]+:\]\]", normalized)
    ):
        return "short-prose-regex"
    if len(re.findall(r"[A-Za-z一-鿿]", normalized)) >= 45 and sentence_like(
        normalized
    ):
        return "sentence"
    return None


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
    units = shell_units(read_lines(path))
    assignments = collect_assignments(units)
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
                findings.extend(python_heredoc_findings(unit, add_finding))
            continue
        calls = assertion_calls(unit.command)
        calls.extend(
            SearchCall(call.pattern, call.target) for call in search_calls(unit.command)
        )
        for call in calls:
            finding = build_finding(
                relative_path,
                assignments,
                unit.line,
                getattr(call, "assertion", "present"),
                call.pattern,
                call.target,
            )
            if finding is not None:
                findings.append(finding)
    return findings


def scan_tests(tests_dir: Path, root: Path) -> list[Finding]:
    findings: list[Finding] = []
    for path in sorted(tests_dir.glob("test-*.sh")):
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


def default_paths(args: argparse.Namespace) -> tuple[Path, Path]:
    root = (args.repo_root or Path.cwd()).resolve()
    tests_dir = args.tests_dir.resolve() if args.tests_dir else root / "tests"
    return root, tests_dir


def main() -> int:
    args = parse_args()
    root, tests_dir = default_paths(args)
    return report_findings(scan_tests(tests_dir, root))


if __name__ == "__main__":
    raise SystemExit(main())
