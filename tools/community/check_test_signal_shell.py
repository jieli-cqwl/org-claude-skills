from __future__ import annotations

import re
import shlex
from typing import NamedTuple


class AssertionCall(NamedTuple):
    assertion: str
    pattern: str
    target: str


class SearchCall(NamedTuple):
    pattern: str
    target: str


ASSIGN_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$")
ASSERT_RE = re.compile(r"^assert_(present|absent)\b")
ASSERT_ANY_RE = re.compile(r"^assert_any_present\b")
SECTION_ASSERT_RE = re.compile(r"^assert_section_(present|absent)\b")
FUNCTION_RE = re.compile(
    r"^(?:function\s+)?([A-Za-z_][A-Za-z0-9_]*)(?:\s*\(\))?\s*\{"
)
FOR_RE = re.compile(r"^for\s+([A-Za-z_][A-Za-z0-9_]*)\s+in\s+(.+?);?\s*(?:do)?$")
VAR_RE = re.compile(r"^\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?$")
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


def shell_words(line: str) -> list[str] | None:
    try:
        return shlex.split(line, comments=False, posix=True)
    except ValueError:
        return None


def collect_assignments(commands: list[str]) -> dict[str, str]:
    assignments = {}
    for command in commands:
        match = ASSIGN_RE.match(command.strip())
        if not match:
            continue
        words = shell_words(match.group(2))
        if words and len(words) == 1:
            assignments[match.group(1)] = words[0]
    return assignments


def collect_function_arities(commands: list[str]) -> dict[str, int]:
    arities: dict[str, int] = {}
    current: str | None = None
    max_arg = 0
    depth = 0
    for command in commands:
        stripped = command.strip()
        match = FUNCTION_RE.match(stripped)
        if match:
            current = match.group(1)
            max_arg = 0
            depth = stripped.count("{") - stripped.count("}")
            continue
        if current is None:
            continue
        for braced_arg, bare_arg in re.findall(r"\$\{(\d+)\}|\$(\d+)", stripped):
            max_arg = max(max_arg, int(braced_arg or bare_arg))
        depth += stripped.count("{") - stripped.count("}")
        if depth <= 0:
            arities[current] = max_arg
            current = None
    return arities


def collect_loop_values(commands: list[str]) -> dict[str, list[str]]:
    values: dict[str, list[str]] = {}
    for command in commands:
        binding = loop_binding(command)
        if binding is None:
            continue
        name, literal_values = binding
        values[name] = literal_values
    return values


def loop_binding(command: str) -> tuple[str, list[str]] | None:
    stripped = command.strip()
    match = FOR_RE.match(stripped)
    if not match:
        return None
    raw_values = match.group(2).removesuffix("do").strip()
    words = shell_words(raw_values) or []
    literal_values = [word for word in words if word not in {"$@", "$*"}]
    if not literal_values:
        return None
    return match.group(1), literal_values


def closes_loop(command: str) -> bool:
    return command.strip() == "done"


def expand_loop_token(token: str, loop_values: dict[str, list[str]]) -> list[str]:
    match = VAR_RE.match(token.strip())
    if match:
        return loop_values.get(match.group(1), [token])
    return [token]


def expand_pattern(pattern: str, loop_values: dict[str, list[str]]) -> list[str]:
    return expand_loop_token(pattern, loop_values)


def expand_target(target: str, loop_values: dict[str, list[str]]) -> list[str]:
    return expand_loop_token(target, loop_values)


def resolve_target(raw: str, assignments: dict[str, str]) -> str:
    positional_match = re.fullmatch(r"\$\{?([0-9]+)\}?", raw.strip())
    if positional_match:
        return assignments.get(positional_match.group(1), raw)
    match = VAR_RE.match(raw.strip())
    if match:
        return assignments.get(match.group(1), raw)
    return raw


def assertion_calls(line: str, arities: dict[str, int]) -> list[AssertionCall]:
    stripped = line.strip()
    words = shell_words(stripped)
    if not words:
        return []
    name = words[0]
    match = ASSERT_RE.match(stripped)
    if match and len(words) >= 3:
        if arities.get(name) == 3 and len(words) >= 4:
            return [AssertionCall(match.group(1), words[2], words[3])]
        return [AssertionCall(match.group(1), words[1], words[2])]
    match = SECTION_ASSERT_RE.match(stripped)
    if match and len(words) >= 4:
        return [AssertionCall(match.group(1), words[3], words[1])]
    if ASSERT_ANY_RE.match(stripped) and len(words) >= 3:
        return [AssertionCall("present", pattern, words[1]) for pattern in words[2:]]
    if name == "assert_hard_gate_absent" and len(words) >= 3:
        return [AssertionCall("absent", words[1], words[2])]
    if name == "assert_hard_gate_terms" and len(words) >= 4:
        return [AssertionCall("present", pattern, words[1]) for pattern in words[3:]]
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
