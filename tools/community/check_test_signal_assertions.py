#!/usr/bin/env python3
# Reject low-signal prose assertions against skill Markdown.
from __future__ import annotations

import argparse
import re
import shlex
import sys
from pathlib import Path
from typing import NamedTuple


TARGET_TERMS = (
    "shared/skills/",
    "shared/agents/",
    "/references/",
    "/projections/",
    "skill",
    "reference",
    "projection",
    "agent",
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
HEREDOC_RE = re.compile(r"<<[-]?['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?")
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

    def key(self) -> str:
        return "\t".join(
            [self.path, self.assertion, self.kind, self.pattern, self.target]
        )


class AssertionCall(NamedTuple):
    assertion: str
    pattern: str
    target: str


class SearchCall(NamedTuple):
    pattern: str
    target: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Reject low-signal prose assertions against skill Markdown."
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


def executable_lines(lines: list[str]) -> list[tuple[int, str]]:
    executable = []
    heredoc_end = None
    start_line = None
    parts: list[str] = []
    for line_no, line in enumerate(lines, start=1):
        stripped = line.strip()
        if heredoc_end is not None:
            if stripped == heredoc_end:
                heredoc_end = None
            continue

        if start_line is None:
            start_line = line_no
        fragment = line.rstrip()
        if fragment.endswith("\\"):
            parts.append(fragment[:-1].strip())
            continue

        parts.append(fragment.strip())
        command = " ".join(part for part in parts if part)
        executable.append((start_line, command))
        match = HEREDOC_RE.search(command)
        if match:
            heredoc_end = match.group(1)
        start_line = None
        parts = []

    if parts and start_line is not None:
        command = " ".join(part for part in parts if part)
        executable.append((start_line, command))
    return executable


def collect_assignments(lines: list[str]) -> dict[str, str]:
    assignments = {}
    for _, line in executable_lines(lines):
        match = ASSIGN_RE.match(line.strip())
        if not match:
            continue
        name, rhs = match.groups()
        words = shell_words(rhs)
        if words and len(words) == 1:
            assignments[name] = words[0]
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
        target = words[1]
        return [AssertionCall("present", pattern, target) for pattern in words[2:]]

    return []


def is_option_with_value(option: str) -> bool:
    if "=" in option:
        return False
    return option in RG_OPTIONS_WITH_VALUE


def token_stops_command(token: str) -> bool:
    return token in SHELL_STOP_TOKENS or token.startswith(">") or token.startswith("2>")


def rg_search_calls(words: list[str]) -> list[SearchCall]:
    index = 1
    while index < len(words):
        word = words[index]
        if token_stops_command(word):
            return []
        if word == "--":
            index += 1
            break
        if word.startswith("-"):
            index += 2 if is_option_with_value(word) else 1
            continue
        break

    if index >= len(words):
        return []
    pattern = words[index]
    index += 1
    targets = []
    while index < len(words):
        word = words[index]
        if token_stops_command(word):
            break
        if word.startswith("-"):
            index += 2 if is_option_with_value(word) else 1
            continue
        targets.append(word)
        index += 1
    return [SearchCall(pattern, target) for target in targets]


def grep_search_calls(words: list[str]) -> list[SearchCall]:
    index = 1
    pattern = None
    while index < len(words):
        word = words[index]
        if token_stops_command(word):
            return []
        if word == "--":
            index += 1
            break
        if word in {"-e", "--regexp"}:
            if index + 1 >= len(words):
                return []
            pattern = words[index + 1]
            index += 2
            break
        if word.startswith("-"):
            index += 1
            continue
        pattern = word
        index += 1
        break

    if pattern is None or index >= len(words):
        return []
    targets = []
    while index < len(words):
        word = words[index]
        if token_stops_command(word):
            break
        targets.append(word)
        index += 1
    return [SearchCall(pattern, target) for target in targets]


def search_calls(line: str) -> list[SearchCall]:
    words = shell_words(line.strip())
    if not words:
        return []
    if words[0] == "rg":
        return rg_search_calls(words)
    if words[0] == "grep":
        return grep_search_calls(words)
    return []


def is_markdown_prose_target(target: str) -> bool:
    haystack = target.lower()
    return ".md" in haystack and any(term in haystack for term in TARGET_TERMS)


def normalized_pattern(pattern: str) -> str:
    normalized = pattern.strip()
    normalized = re.sub(r"^\^", "", normalized)
    normalized = re.sub(r"\$$", "", normalized)
    return (
        normalized.replace(r"\`", "`")
        .replace(r"\.", ".")
        .replace(r"\+", "+")
        .replace(r"\-", "-")
    )


def has_contract_pattern_shape(pattern: str) -> bool:
    return bool(re.search(r"[|$\[\]{}()\\`/\"]", pattern))


def has_prose_regex_shape(pattern: str) -> bool:
    return bool(re.search(r"\||\.\*|\[\[:[a-z]+:\]\]", pattern))


def has_cjk_prose(text: str, minimum: int = 2) -> bool:
    return len(re.findall(r"[一-鿿]", text)) >= minimum


def has_prose_before_contract_token(pattern: str) -> bool:
    match = CONTRACT_TOKENS.search(pattern)
    if match is None:
        return False
    return has_cjk_prose(pattern[: match.start()])


def low_signal_kind(assertion: str, pattern: str, target: str = "") -> str | None:
    normalized = normalized_pattern(pattern)
    if re.match(r"#{1,6}\s+", normalized):
        return "heading"
    if CONTRACT_TOKENS.search(normalized) and has_prose_before_contract_token(
        normalized
    ):
        return "prose-wrapped-contract"
    if CONTRACT_TOKENS.search(normalized) and has_contract_pattern_shape(normalized):
        return None
    letter_count = len(re.findall(r"[A-Za-z一-鿿]", normalized))
    cjk_count = len(re.findall(r"[一-鿿]", normalized))
    if assertion == "absent" and cjk_count >= 2:
        return "short-absent-phrase"
    if (
        assertion == "present"
        and "shared/skills/" in target.lower()
        and cjk_count >= 4
        and not CONTRACT_TOKENS.search(normalized)
    ):
        return "short-present-phrase"
    if (
        assertion == "present"
        and "shared/skills/" in target.lower()
        and has_cjk_prose(normalized, minimum=2)
        and has_prose_regex_shape(normalized)
        and not CONTRACT_TOKENS.search(normalized)
    ):
        return "short-prose-regex"
    has_sentence_shape = (
        normalized.count(" ") >= 6
        or cjk_count >= 18
        or normalized.endswith((".", "。", "！", "？", "!", "?"))
    )
    if letter_count >= 45 and has_sentence_shape:
        return "sentence"
    if CONTRACT_TOKENS.search(normalized):
        return None
    return None


def display_path(path: Path, root: Path) -> str:
    try:
        return path.relative_to(root).as_posix()
    except ValueError:
        return path.as_posix()


def finding_for_call(
    path: str,
    line_no: int,
    assertion: str,
    pattern: str,
    target: str,
    assignments: dict[str, str],
) -> Finding | None:
    resolved_target = resolve_target(target, assignments)
    if not is_markdown_prose_target(resolved_target):
        return None
    kind = low_signal_kind(assertion, pattern, resolved_target)
    if kind is None:
        return None
    return Finding(path, line_no, assertion, kind, pattern, resolved_target)


def scan_file(path: Path, root: Path) -> list[Finding]:
    lines = read_lines(path)
    assignments = collect_assignments(lines)
    findings = []
    relative_path = display_path(path, root)
    for line_no, line in executable_lines(lines):
        for call in assertion_calls(line):
            finding = finding_for_call(
                relative_path,
                line_no,
                call.assertion,
                call.pattern,
                call.target,
                assignments,
            )
            if finding is not None:
                findings.append(finding)
        for call in search_calls(line):
            finding = finding_for_call(
                relative_path,
                line_no,
                "present",
                call.pattern,
                call.target,
                assignments,
            )
            if finding is not None:
                findings.append(finding)
    return findings


def scan_tests(tests_dir: Path, root: Path) -> list[Finding]:
    findings = []
    for path in sorted(tests_dir.glob("test-*.sh")):
        findings.extend(scan_file(path, root))
    return findings


def report_findings(findings: list[Finding]) -> int:
    if not findings:
        return 0
    for finding in sorted(findings, key=lambda item: (item.key(), item.line)):
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
