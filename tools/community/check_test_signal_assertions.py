#!/usr/bin/env python3
# Reject newly introduced low-signal prose assertions while preserving the frozen legacy baseline.
from __future__ import annotations

import argparse
import re
import shlex
import sys
from collections import Counter
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
SECTION_ASSERT_RE = re.compile(r"^assert_section_(present|absent)\b")
VAR_RE = re.compile(r"^\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?$")


# Finding reports a prose assertion against the frozen baseline.
class Finding(NamedTuple):
    # Shell test path relative to repo root.
    path: str
    # Source line for human remediation.
    line: int
    # assert_present/assert_absent polarity.
    assertion: str
    # heading or sentence policy category.
    kind: str
    # Original grep pattern.
    pattern: str
    # Assertion target path.
    target: str

    # Line numbers are excluded so the baseline survives unrelated local test reshaping.
    def key(self) -> str:
        return "\t".join(
            [self.path, self.assertion, self.kind, self.pattern, self.target]
        )


# AssertionCall preserves only the parsed helper arguments we enforce.
class AssertionCall(NamedTuple):
    # assert_present/assert_absent polarity.
    assertion: str
    # First positional shell argument.
    pattern: str
    # Second positional shell argument before alias resolution.
    target: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Reject low-signal prose assertions against skill Markdown."
    )
    parser.add_argument("--repo-root", type=Path, default=None)
    parser.add_argument("--tests-dir", type=Path, default=None)
    parser.add_argument("--baseline", type=Path, default=None)
    parser.add_argument("--write-baseline", action="store_true")
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
    for line_no, line in enumerate(lines, start=1):
        if heredoc_end is not None:
            if line.strip() == heredoc_end:
                heredoc_end = None
            continue
        executable.append((line_no, line))
        match = re.search(r"<<[-]?['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?", line)
        if match:
            heredoc_end = match.group(1)
    return executable


def collect_assignments(lines: list[str]) -> dict[str, str]:
    assignments = {}
    for _, line in executable_lines(lines):
        stripped = line.strip()
        match = ASSIGN_RE.match(stripped)
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


def assertion_call(line: str) -> AssertionCall | None:
    stripped = line.strip()
    words = shell_words(stripped)
    if not words:
        return None
    match = ASSERT_RE.match(stripped)
    if match:
        if len(words) < 3:
            return None
        return AssertionCall(assertion=match.group(1), pattern=words[1], target=words[2])
    match = SECTION_ASSERT_RE.match(stripped)
    if match:
        if len(words) < 4:
            return None
        return AssertionCall(assertion=match.group(1), pattern=words[3], target=words[1])
    return None


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
    if CONTRACT_TOKENS.search(normalized) and has_prose_before_contract_token(normalized):
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


def scan_file(path: Path, root: Path) -> list[Finding]:
    lines = read_lines(path)
    assignments = collect_assignments(lines)
    findings = []
    relative_path = display_path(path, root)
    for line_no, line in executable_lines(lines):
        call = assertion_call(line)
        if call is None:
            continue
        target = resolve_target(call.target, assignments)
        if not is_markdown_prose_target(target):
            continue
        kind = low_signal_kind(call.assertion, call.pattern, target)
        if kind is None:
            continue
        findings.append(
            Finding(
                path=relative_path,
                line=line_no,
                assertion=call.assertion,
                kind=kind,
                pattern=call.pattern,
                target=target,
            )
        )
    return findings


def scan_tests(tests_dir: Path, root: Path) -> list[Finding]:
    findings = []
    for path in sorted(tests_dir.glob("test-*.sh")):
        findings.extend(scan_file(path, root))
    return findings


def load_baseline(path: Path | None) -> Counter[str]:
    if path is None:
        return Counter()
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except FileNotFoundError:
        return Counter()
    except OSError as exc:
        raise SystemExit(f"cannot read baseline {path}: {exc}") from exc
    return Counter(line for line in lines if line and not line.startswith("#"))


def report_unexpected(findings: list[Finding], baseline: Counter[str]) -> int:
    current = Counter(finding.key() for finding in findings)
    unexpected = current - baseline
    if not unexpected:
        return 0
    by_key = {finding.key(): finding for finding in findings}
    for key in sorted(unexpected):
        finding = by_key[key]
        for _ in range(unexpected[key]):
            print(
                "LOW_SIGNAL_PROSE_ASSERTION "
                f"{finding.path}:{finding.line} {finding.assertion} {finding.kind}: "
                f"{finding.pattern} -> {finding.target}",
                file=sys.stderr,
            )
    return 1


def default_paths(args: argparse.Namespace) -> tuple[Path, Path, Path | None]:
    root = (args.repo_root or Path.cwd()).resolve()
    tests_dir = args.tests_dir.resolve() if args.tests_dir else root / "tests"
    baseline = args.baseline
    if baseline is None:
        baseline = (
            root
            / "tests/fixtures/test-assertion-boundary/low-signal-prose-assertions.baseline"
        )
    return root, tests_dir, baseline


def main() -> int:
    args = parse_args()
    root, tests_dir, baseline_path = default_paths(args)
    findings = scan_tests(tests_dir, root)
    if args.write_baseline:
        for key, count in sorted(
            Counter(finding.key() for finding in findings).items()
        ):
            for _ in range(count):
                print(key)
        return 0
    return report_unexpected(findings, load_baseline(baseline_path))


if __name__ == "__main__":
    raise SystemExit(main())
