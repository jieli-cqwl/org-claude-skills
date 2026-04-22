"""Proof-command validation for standard-chain pilot audits."""

from __future__ import annotations

import ast
import os
import re
import shlex
import subprocess
from pathlib import Path
from typing import Any

from standard_chain_pilot_audit_core import (
    ROOT,
    AuditError,
    require_list,
    require_text,
    resolve_repo_path,
)

PROOF_RESULT_RE = re.compile(r"PASS|OK|All tests passed|no matches|0 matches", re.IGNORECASE)
CODE_PROOF_RE = re.compile(r"PASS|OK|Ran [0-9]+ tests?", re.IGNORECASE)
RELEVANCE_STOPWORDS = {
    "after",
    "before",
    "code",
    "command",
    "evidence",
    "expected",
    "failed",
    "finding",
    "green",
    "pass",
    "proof",
    "red",
    "returned",
    "tests",
    "with",
}


def tokenize_relevance_text(value: str) -> set[str]:
    """Extract comparable evidence tokens for finding-to-test matching."""
    return {
        token
        for token in re.findall(r"[a-z0-9]+", value.lower())
        if len(token) >= 3 and token not in RELEVANCE_STOPWORDS
    }


def finding_relevance_tokens(finding: dict[str, Any]) -> set[str]:
    """Infer terms that a code-finding regression test must exercise."""
    text = " ".join(
        str(finding.get(field, ""))
        for field in ("finding_id", "dimension", "red_evidence", "green_evidence")
    )
    tokens = tokenize_relevance_text(text)
    if "len" in tokens:
        tokens.add("length")
    if "obs" in tokens:
        tokens.update({"access", "log", "observability"})
    return tokens


def symbol_matches_finding(symbol: str, finding: dict[str, Any]) -> bool:
    """Check that a regression test name is relevant to the resolved finding."""
    overlap = tokenize_relevance_text(symbol) & finding_relevance_tokens(finding)
    return len(overlap) >= 2


def expected_exit_codes(check: dict[str, Any], context: str) -> set[int]:
    """Read accepted command exit codes, defaulting to normal success."""
    if "expected_exit_code" not in check:
        return {0}
    value = check["expected_exit_code"]
    if not isinstance(value, int):
        raise AuditError(f"{context}: expected_exit_code must be an integer")
    return {value}


def split_command_with_env(command: str) -> tuple[list[str], dict[str, str]]:
    """Split a proof command and support leading KEY=value environment pairs."""
    parts = shlex.split(command)
    env = os.environ.copy()
    while parts and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", parts[0]):
        key, value = parts.pop(0).split("=", 1)
        env[key] = value
    return parts, env


def assert_proof_command(check: dict[str, Any], feature_id: str, finding_id: str) -> tuple[list[str], str]:
    """Execute the declared proof command instead of trusting report text."""
    command = require_text(check, "proof_command", f"{feature_id}:{finding_id}")
    args, env = split_command_with_env(command)
    if not args:
        raise AuditError(f"{feature_id}:{finding_id}: empty proof_command")
    result = subprocess.run(
        args,
        cwd=ROOT,
        env=env,
        check=False,
        capture_output=True,
        text=True,
        timeout=90,
    )
    if result.returncode not in expected_exit_codes(check, f"{feature_id}:{finding_id}"):
        raise AuditError(f"{feature_id}: proof_command failed for finding {finding_id}: exit {result.returncode}")
    output = f"{result.stdout}\n{result.stderr}"
    return args, output


def assert_proof_result_matches(check: dict[str, Any], output: str, context: str) -> None:
    """Bind the reported proof result to actual command output."""
    proof_result = require_text(check, "proof_result", context)
    if not PROOF_RESULT_RE.search(proof_result):
        raise AuditError(f"{context}: proof_result must show passing evidence")
    if proof_result == "0 matches" and not output.strip():
        return
    if proof_result not in output:
        raise AuditError(f"{context}: proof_result not found in proof command output")


def assert_unittest_command(args: list[str], context: str) -> None:
    """Require code-finding proof commands to run Python unittest directly."""
    executable = Path(args[0]).name if args else ""
    if len(args) < 3 or not executable.startswith("python") or args[1:3] != ["-m", "unittest"]:
        raise AuditError(f"{context}: proof_command must run unittest")


def collect_python_test_symbols(file_path: Path) -> set[str]:
    """Extract real Python test function names from a test file AST."""
    tree = ast.parse(file_path.read_text(encoding="utf-8"), filename=str(file_path))
    return {
        node.name
        for node in ast.walk(tree)
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name.startswith("test_")
    }


def shell_test_symbols(file_path: Path) -> set[str]:
    """Extract shell test helper names from a non-Python test file."""
    text = file_path.read_text(encoding="utf-8")
    return {match.group(2) for match in re.finditer(r"\b(function )?(test_[A-Za-z0-9_]+)\b", text)}


def assert_test_symbol(ref: dict[str, Any], command_output: str, context: str) -> str:
    """Ensure a regression proof points to a real test symbol."""
    file_path = resolve_repo_path(require_text(ref, "file", context))
    symbol = require_text(ref, "symbol", context)
    if not symbol.startswith("test_"):
        raise AuditError(f"{context}: regression test symbol must start with test_")
    if not file_path.is_file():
        raise AuditError(f"{context}: missing regression test file {file_path}")
    symbols = collect_python_test_symbols(file_path) if file_path.suffix == ".py" else shell_test_symbols(file_path)
    if symbol not in symbols:
        raise AuditError(f"{context}: missing regression test symbol {symbol}")
    if symbol not in command_output:
        raise AuditError(f"{context}: proof output missing test symbol {symbol}")
    return symbol


def parse_rg_command(args: list[str], context: str) -> tuple[str, set[Path]]:
    """Parse the rg command used to prove a docs residue scan."""
    executable = Path(args[0]).name if args else ""
    if executable != "rg":
        raise AuditError(f"{context}: noise proof_command must run rg")
    pattern = ""
    paths: set[Path] = set()
    for arg in args[1:]:
        if arg.startswith("-"):
            continue
        if not pattern:
            pattern = arg.lower()
        else:
            paths.add(resolve_repo_path(arg))
    if not pattern or not paths:
        raise AuditError(f"{context}: noise proof_command must include pattern and paths")
    return pattern, paths


def assert_noise_proof_command(args: list[str], profile: dict[str, Any], context: str) -> None:
    """Bind a docs finding proof command to its configured residue scan."""
    pattern, command_paths = parse_rg_command(args, context)
    if command_paths != profile["paths"]:
        raise AuditError(f"{context}: noise proof_command paths do not match noise_check")
    for term in sorted(profile["terms"]):
        if term not in pattern:
            raise AuditError(f"{context}: noise proof_command missing term {term}")


def assert_resolution_proofs(
    feature_id: str,
    findings: dict[str, dict[str, Any]],
    checks: dict[str, dict[str, Any]],
    noise_profiles: dict[str, dict[str, Any]],
) -> None:
    """Match every resolved finding to either a regression test or noise scan."""
    assert_finding_sets_match(feature_id, findings, checks)
    for finding_id, finding in findings.items():
        check = checks[finding_id]
        args, command_output = assert_proof_command(check, feature_id, finding_id)
        saw_test, saw_relevant, saw_noise = scan_proof_refs(
            feature_id, finding_id, finding, check, args, command_output, noise_profiles
        )
        file_path = str(finding.get("file_path", ""))
        assert_finding_proof_shape(feature_id, finding_id, finding, file_path, saw_test, saw_relevant, saw_noise)
        assert_proof_result_matches(check, command_output, f"{feature_id}:{finding_id}")


def assert_finding_sets_match(
    feature_id: str, findings: dict[str, dict[str, Any]], checks: dict[str, dict[str, Any]]
) -> None:
    """Ensure the audit report covers exactly the resolved review findings."""
    missing = sorted(set(findings) - set(checks))
    if missing:
        raise AuditError(f"{feature_id}: missing resolution check for finding {missing[0]}")
    extra = sorted(set(checks) - set(findings))
    if extra:
        raise AuditError(f"{feature_id}: resolution check has no finding {extra[0]}")


def scan_proof_refs(
    feature_id: str,
    finding_id: str,
    finding: dict[str, Any],
    check: dict[str, Any],
    args: list[str],
    command_output: str,
    noise_profiles: dict[str, dict[str, Any]],
) -> tuple[bool, bool, bool]:
    """Validate proof refs and return which proof classes were seen."""
    saw_test = saw_relevant = saw_noise = False
    for ref in require_list(check, "proof_refs", f"{feature_id}:{finding_id}"):
        if not isinstance(ref, dict):
            raise AuditError(f"{feature_id}:{finding_id}: proof_ref must be an object")
        kind = require_text(ref, "kind", f"{feature_id}:{finding_id}")
        if kind == "test_symbol":
            assert_unittest_command(args, f"{feature_id}:{finding_id}")
            symbol = assert_test_symbol(ref, command_output, f"{feature_id}:{finding_id}")
            saw_test = True
            saw_relevant = saw_relevant or symbol_matches_finding(symbol, finding)
        elif kind == "noise_check":
            label = require_text(ref, "label", f"{feature_id}:{finding_id}")
            if label not in noise_profiles:
                raise AuditError(f"{feature_id}:{finding_id}: unknown noise_check {label}")
            assert_noise_proof_command(args, noise_profiles[label], f"{feature_id}:{finding_id}")
            saw_noise = True
        else:
            raise AuditError(f"{feature_id}:{finding_id}: unsupported proof kind {kind}")
    return saw_test, saw_relevant, saw_noise


def assert_finding_proof_shape(
    feature_id: str,
    finding_id: str,
    finding: dict[str, Any],
    file_path: str,
    saw_test: bool,
    saw_relevant: bool,
    saw_noise: bool,
) -> None:
    """Check proof class and relevance against the finding target."""
    if file_path.startswith("docs/"):
        if not saw_noise:
            raise AuditError(f"{feature_id}:{finding_id}: docs finding must use noise_check proof")
        return
    if not saw_test:
        raise AuditError(f"{feature_id}:{finding_id}: code finding must use test_symbol proof")
    if not saw_relevant:
        raise AuditError(f"{feature_id}: no relevant regression test symbol for finding {finding_id}")
    if not CODE_PROOF_RE.search(str(finding.get("green_evidence", ""))):
        raise AuditError(f"{feature_id}:{finding_id}: green_evidence must show test pass proof")
