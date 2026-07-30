"""Fail-closed parsing for Codex execution route evidence."""

from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
import re
import shlex

from rule_runtime_eval.contracts import SceneContract


_READERS = frozenset({"cat", "sed", "head", "tail", "nl", "awk"})
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
    {"agent_message", "command_execution", "reasoning", "file_change", "mcp_tool_call", "web_search"}
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
        targets, command_uncertain = _read_targets(command, set(expected_targets))
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


def _read_targets(command: str, expected_targets: set[Path]) -> tuple[set[Path], bool]:
    try:
        tokens = _shell_tokens(command)
    except ValueError:
        return set(), _mentions_target(command, expected_targets)
    if not tokens:
        return set(), False
    executable = Path(tokens[0]).name
    if executable in _SHELLS:
        return _shell_read_targets(tokens, expected_targets)
    if executable not in _READERS:
        return set(), False
    return _direct_read_targets(tokens, expected_targets)


def _shell_read_targets(tokens: list[str], expected_targets: set[Path]) -> tuple[set[Path], bool]:
    if len(tokens) != 3 or tokens[1] != "-lc":
        return set(), _mentions_target(" ".join(tokens), expected_targets)
    script = tokens[2]
    if any(operator in script for operator in (";", "&&", "||", "|", "\n", "`", "$()")):
        return set(), _mentions_target(script, expected_targets)
    try:
        return _direct_read_targets(_shell_tokens(script), expected_targets)
    except ValueError:
        return set(), _mentions_target(script, expected_targets)


def _direct_read_targets(tokens: list[str], expected_targets: set[Path]) -> tuple[set[Path], bool]:
    if not tokens or Path(tokens[0]).name not in _READERS:
        return set(), _mentions_target(" ".join(tokens), expected_targets)
    if any(token in {";", "&&", "||", "|", "<", ">", "<<", ">>"} for token in tokens[1:]):
        return set(), True
    if Path(tokens[0]).name == "awk":
        return _awk_read_targets(tokens, expected_targets)
    targets = {_normal_path(token) for token in tokens[1:]}
    return targets & expected_targets, False


def _awk_read_targets(tokens: list[str], expected_targets: set[Path]) -> tuple[set[Path], bool]:
    """Accept only record-processing awk programs with one explicit target file."""

    if len(tokens) != 3 or _has_awk_fileless_rule(tokens[1]):
        return set(), True
    target = _normal_path(tokens[2])
    return ({target} & expected_targets), False


def _has_awk_fileless_rule(program: str) -> bool:
    return re.search(r"\b(?:BEGIN|END)\b", program) is not None


def _normal_path(value: str) -> Path:
    return Path(value).expanduser().resolve()


def _mentions_target(value: str, expected_targets: set[Path]) -> bool:
    return any(str(target) in value for target in expected_targets)


def _shell_tokens(command: str) -> list[str]:
    lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|<>")
    lexer.whitespace_split = True
    lexer.commenters = ""
    return list(lexer)
