"""Fail-closed parsing for Codex execution route evidence."""

from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
import re
import shlex

from rule_runtime_eval.contracts import SceneContract


_READERS = frozenset({"cat", "sed", "head", "tail", "nl"})
_SHELLS = frozenset({"sh", "bash", "zsh"})
_KNOWN_EVENT_TYPES = frozenset(
    {
        "thread.started",
        "turn.started",
        "turn.completed",
        "item.started",
        "item.updated",
        "item.completed",
        "error",
    }
)
_KNOWN_ITEM_TYPES = frozenset(
    {"agent_message", "command_execution", "reasoning", "file_change", "mcp_tool_call", "todo_list", "web_search"}
)


@dataclass(frozen=True)
class RouteEvidence:
    """Route verdict with IDs only; command output is retained only in raw JSONL."""

    route_evidence_available: bool
    route_pass: bool
    parser_uncertain: bool
    expected_contract_ids: tuple[str, ...]
    read_contract_ids: tuple[str, ...]
    observed_event_ids: tuple[str, ...]
    observed_command_ids: tuple[str, ...]


def load_jsonl(path: Path) -> list[dict]:
    """Load JSONL records without accepting malformed or non-object lines."""

    records: list[dict] = []
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        raise ValueError("executor JSONL is unavailable") from exc
    for line in lines:
        if not line.strip():
            continue
        try:
            record = json.loads(line)
        except json.JSONDecodeError as exc:
            raise ValueError("executor JSONL is invalid") from exc
        if not isinstance(record, dict):
            raise ValueError("executor JSONL event must be an object")
        records.append(record)
    return records


def classify_route_reads(
    events: list[dict],
    expected_contracts: tuple[SceneContract, ...],
    runtime_codex_home: Path,
) -> RouteEvidence:
    """Accept only completed successful reader commands with an exact installed target."""

    expected_targets = {
        _installed_target(runtime_codex_home, contract.installed_path): contract.id
        for contract in expected_contracts
    }
    event_ids: list[str] = []
    command_ids: list[str] = []
    read_ids: set[str] = set()
    uncertain = False

    for event in events:
        if not _known_event(event):
            uncertain = True
            continue
        item = event.get("item")
        if not isinstance(item, dict) or event.get("type") != "item.completed":
            continue
        item_id = item.get("id")
        if isinstance(item_id, str) and item_id:
            event_ids.append(item_id)
        if item.get("type") != "command_execution":
            continue
        if not isinstance(item_id, str) or not item_id:
            uncertain = True
            continue
        command_ids.append(item_id)
        command = item.get("command")
        if not isinstance(command, str):
            uncertain = True
            continue
        if not _completed_success(item):
            continue
        targets, command_uncertain = _read_targets(command, set(expected_targets), runtime_codex_home)
        uncertain = uncertain or command_uncertain
        read_ids.update(expected_targets[target] for target in targets)

    available = not uncertain
    expected_ids = tuple(contract.id for contract in expected_contracts)
    return RouteEvidence(
        route_evidence_available=available,
        route_pass=available and set(expected_ids) <= read_ids,
        parser_uncertain=uncertain,
        expected_contract_ids=expected_ids,
        read_contract_ids=tuple(sorted(read_ids)),
        observed_event_ids=tuple(event_ids),
        observed_command_ids=tuple(command_ids),
    )


def _known_event(event: dict) -> bool:
    event_type = event.get("type")
    if not isinstance(event_type, str) or event_type not in _KNOWN_EVENT_TYPES:
        return False
    if event_type.startswith("item."):
        item = event.get("item")
        return isinstance(item, dict) and isinstance(item.get("type"), str) and item["type"] in _KNOWN_ITEM_TYPES
    return True


def _completed_success(item: dict) -> bool:
    return (
        item.get("exit_code") == 0
        and item.get("status") == "completed"
        and isinstance(item.get("aggregated_output"), str)
        and bool(item["aggregated_output"].strip())
    )


def _installed_target(runtime_codex_home: Path, installed_path: Path) -> Path:
    target = (runtime_codex_home / installed_path).resolve()
    try:
        target.relative_to(runtime_codex_home.resolve())
    except ValueError as exc:
        raise ValueError("scene installed path escapes CODEX_HOME") from exc
    return target


def _read_targets(
    command: str, expected_targets: set[Path], runtime_codex_home: Path
) -> tuple[set[Path], bool]:
    try:
        tokens = _shell_tokens(command)
    except ValueError:
        return set(), _mentions_target(command, expected_targets, runtime_codex_home)
    if not tokens:
        return set(), False
    executable = Path(tokens[0]).name
    if executable in _SHELLS:
        return _shell_read_targets(tokens, expected_targets, runtime_codex_home)
    if executable not in _READERS:
        return set(), _mentions_target_alias(command, expected_targets, runtime_codex_home)
    return _direct_read_targets(tokens, expected_targets, runtime_codex_home)


def _shell_read_targets(
    tokens: list[str], expected_targets: set[Path], runtime_codex_home: Path
) -> tuple[set[Path], bool]:
    if len(tokens) != 3 or tokens[1] != "-lc":
        return set(), _mentions_target(" ".join(tokens), expected_targets, runtime_codex_home)
    script = tokens[2]
    if any(operator in script for operator in ("||", "|", "\n", "`", "$()", "<", ">")):
        return set(), _mentions_target(script, expected_targets, runtime_codex_home)
    try:
        script_tokens = _shell_tokens(script)
    except ValueError:
        return set(), _mentions_target(script, expected_targets, runtime_codex_home)
    if "&" in script_tokens:
        return set(), True
    commands = _split_safe_shell_commands(script_tokens)
    if commands is None:
        return set(), _mentions_target(script, expected_targets, runtime_codex_home)
    targets: set[Path] = set()
    for command_tokens in commands:
        if _is_wc_line_probe(command_tokens, runtime_codex_home):
            continue
        if _is_neutral_diagnostic(command_tokens):
            continue
        if not command_tokens or Path(command_tokens[0]).name not in _READERS:
            return set(), _mentions_target(script, expected_targets, runtime_codex_home)
        command_targets, command_uncertain = _direct_read_targets(
            command_tokens, expected_targets, runtime_codex_home
        )
        if command_uncertain:
            return set(), True
        targets.update(command_targets)
    return targets, False


def _is_wc_line_probe(tokens: list[str], runtime_codex_home: Path) -> bool:
    if len(tokens) < 3 or Path(tokens[0]).name != "wc" or tokens[1] != "-l":
        return False
    allowed_roots = (runtime_codex_home.resolve(), runtime_codex_home.parent / ".agents" / "skills")
    for value in tokens[2:]:
        target, uncertain = _normal_path(value, runtime_codex_home)
        if uncertain or target is None or not any(_is_relative_to(target, root) for root in allowed_roots):
            return False
    return True


def _is_neutral_diagnostic(tokens: list[str]) -> bool:
    if not tokens:
        return False
    executable = Path(tokens[0]).name
    return (executable == "pwd" and len(tokens) == 1) or (
        executable == "printenv" and tokens[1:] == ["HOME"]
    )


def _is_relative_to(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root.resolve())
    except ValueError:
        return False
    return True


def _split_safe_shell_commands(tokens: list[str]) -> list[list[str]] | None:
    """Allow only reader commands joined by sequential shell operators."""

    commands: list[list[str]] = []
    command: list[str] = []
    for token in tokens:
        if token in {";", "&&"}:
            if not command:
                return None
            commands.append(command)
            command = []
            continue
        if token in {"&", "||", "|", "<", ">", "<<", ">>"}:
            return None
        command.append(token)
    if not command:
        return None
    commands.append(command)
    return commands


def _direct_read_targets(
    tokens: list[str], expected_targets: set[Path], runtime_codex_home: Path
) -> tuple[set[Path], bool]:
    if not tokens or Path(tokens[0]).name not in _READERS:
        return set(), _mentions_target(" ".join(tokens), expected_targets, runtime_codex_home)
    if any(token in {";", "&&", "||", "|", "<", ">", "<<", ">>"} for token in tokens[1:]):
        return set(), True
    if _provably_zero_content_reader(tokens):
        return set(), False
    targets: set[Path] = set()
    for token in tokens[1:]:
        target, uncertain = _normal_path(token, runtime_codex_home)
        if uncertain:
            return set(), True
        if target is not None:
            targets.add(target)
    return targets & expected_targets, False


def _provably_zero_content_reader(tokens: list[str]) -> bool:
    """Reject supported reader forms whose own options guarantee no file content."""

    executable = Path(tokens[0]).name
    arguments = tokens[1:]
    if executable in {"head", "tail"}:
        for index, value in enumerate(arguments):
            if value in {"-n", "--lines", "-c", "--bytes"} and index + 1 < len(arguments) and arguments[index + 1] == "0":
                return True
            if value in {"-0", "-n0", "--lines=0", "-c0", "--bytes=0"}:
                return True
        return False
    if executable != "sed":
        return False
    quiet = any(value in {"-n", "--quiet", "--silent"} or value.startswith("-n") for value in arguments)
    if not quiet:
        return False
    program_predecessors = {"-e", "--expression", "-n", "--quiet", "--silent"}
    for index, value in enumerate(arguments):
        previous_is_program_option = index > 0 and (
            arguments[index - 1] in program_predecessors
            or re.fullmatch(r"-n+e", arguments[index - 1]) is not None
        )
        if value in {"", "0p"} and (index == 0 or previous_is_program_option):
            return True
        if value in {"-e0p", "--expression=", "--expression=0p"}:
            return True
    return False


def _normal_path(value: str, runtime_codex_home: Path) -> tuple[Path | None, bool]:
    codex_home = runtime_codex_home.resolve()
    home = codex_home.parent
    substitutions = (
        ("$CODEX_HOME/", codex_home),
        ("${CODEX_HOME}/", codex_home),
        ("$HOME/.codex/", codex_home),
        ("${HOME}/.codex/", codex_home),
        (".codex/", codex_home),
        ("./.codex/", codex_home),
        (".agents/", home / ".agents"),
        ("./.agents/", home / ".agents"),
        ("$HOME/.agents/", home / ".agents"),
        ("${HOME}/.agents/", home / ".agents"),
    )
    for prefix, root in substitutions:
        if value.startswith(prefix):
            return (root / value[len(prefix) :]).resolve(), False
    path = Path(value).expanduser()
    if path.is_absolute():
        return path.resolve(), False
    return (None, True) if "$" in value else (path.resolve(), False)


def _mentions_target(
    value: str, expected_targets: set[Path], runtime_codex_home: Path
) -> bool:
    return any(str(target) in value for target in expected_targets) or _mentions_target_alias(
        value, expected_targets, runtime_codex_home
    )


def _mentions_target_alias(
    value: str, expected_targets: set[Path], runtime_codex_home: Path
) -> bool:
    codex_home = runtime_codex_home.resolve()
    aliases: set[str] = set()
    for target in expected_targets:
        try:
            relative = target.relative_to(codex_home)
        except ValueError:
            continue
        suffix = relative.as_posix()
        aliases.update(
            {
                f"$CODEX_HOME/{suffix}",
                f"${{CODEX_HOME}}/{suffix}",
                f"$HOME/.codex/{suffix}",
                f"${{HOME}}/.codex/{suffix}",
                f".codex/{suffix}",
                f"./.codex/{suffix}",
            }
        )
    return any(_alias_mentioned(value, alias) for alias in aliases)


def _alias_mentioned(value: str, alias: str) -> bool:
    if not alias.startswith(".codex/"):
        return alias in value
    return re.search(rf"(?<![/\w.-]){re.escape(alias)}", value) is not None


def _shell_tokens(command: str) -> list[str]:
    lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|<>")
    lexer.whitespace_split = True
    lexer.commenters = ""
    return list(lexer)
