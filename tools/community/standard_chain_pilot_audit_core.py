"""Core artifact and residue checks for standard-chain pilot audits."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
TEXT_EXTENSIONS = {".json", ".md", ".txt", ".sh", ".py", ".html"}
DOMAIN_VOCABULARY = {
    "credential",
    "feedback",
    "homepage",
    "login",
    "logout",
    "message",
    "password",
    "session",
    "submission",
    "thanks",
}
GENERIC_FEATURE_TOKENS = {"pilot", "phase", "standard", "chain", "feature"}
REPO_PATH_PATTERN = re.compile(
    r"\b(?:claude|codex|community|contracts|docs|examples|shared|tests|tools)/[^\s\"'<>;,)]*"
)
ACTIVE_DOMAIN_FILES = [
    "phase-prd.json",
    "design.json",
    "plan.json",
    "tasks.json",
]


class AuditError(ValueError):
    """Raised when a pilot audit report no longer matches its evidence."""


def load_json(path: Path) -> dict[str, Any]:
    """Load a JSON object and report malformed audit evidence as a gate failure."""
    with path.open(encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict):
        raise AuditError(f"{path}: expected JSON object")
    return payload


def resolve_repo_path(raw_path: str) -> Path:
    """Resolve audit report paths from repository root unless already absolute."""
    path = Path(raw_path)
    if path.is_absolute():
        return path
    return (ROOT / path).resolve()


def resolve_phase_child(phase_dir: Path, raw_path: str) -> Path:
    """Resolve noise-check paths relative to the phase directory by default."""
    path = Path(raw_path)
    if path.is_absolute():
        return path
    if raw_path.startswith("docs/") or raw_path.startswith("tests/"):
        return resolve_repo_path(raw_path)
    return (phase_dir / path).resolve()


def require_text(mapping: dict[str, Any], field: str, context: str) -> str:
    """Fetch a required string field used as validator input."""
    value = mapping.get(field)
    if not isinstance(value, str) or not value.strip():
        raise AuditError(f"{context}: missing {field}")
    return value.strip()


def require_list(mapping: dict[str, Any], field: str, context: str) -> list[Any]:
    """Fetch a required non-empty list field used as validator input."""
    value = mapping.get(field)
    if not isinstance(value, list) or not value:
        raise AuditError(f"{context}: missing {field}")
    return value


def iter_text_files(target: Path) -> list[Path]:
    """Return readable text evidence files under a configured audit path."""
    if target.is_file():
        return [target]
    if not target.is_dir():
        raise AuditError(f"missing noise-check path: {target}")
    return [
        path
        for path in sorted(target.rglob("*"))
        if path.is_file() and path.suffix in TEXT_EXTENSIONS
    ]


def normalize_terms(values: list[Any]) -> set[str]:
    """Normalize configured term lists for case-insensitive comparison."""
    return {str(value).strip().lower() for value in values if str(value).strip()}


def split_feature_tokens(value: str) -> set[str]:
    """Extract stable feature tokens while ignoring process nouns."""
    return {
        token
        for token in re.findall(r"[a-z0-9]+", value.lower())
        if token and token not in GENERIC_FEATURE_TOKENS
    }


def read_existing_text(paths: list[Path]) -> str:
    """Join active artifact text without touching runtime history files."""
    chunks: list[str] = []
    for path in paths:
        if path.is_file():
            chunks.append(path.read_text(encoding="utf-8"))
    return "\n".join(chunks).lower()


def infer_interface_terms(text: str) -> set[str]:
    """Infer stable IF-* prefixes from active design and task artifacts."""
    terms: set[str] = set()
    for match in re.findall(r"\bIF-[A-Z0-9-]+\b", text.upper()):
        parts = match.lower().split("-")
        if len(parts) >= 2:
            terms.add("-".join(parts[:2]))
    return terms


def strip_repo_path_references(text: str) -> str:
    """Remove evidence paths so cross-pilot refs do not become local domain terms."""
    return REPO_PATH_PATTERN.sub(" ", text)


def infer_domain_terms(feature_id: str, phase_dir: Path) -> set[str]:
    """Infer minimum cross-pilot terms from active planning artifacts."""
    feature_dir = phase_dir.parent
    active_paths = [feature_dir / "brief.json"]
    active_paths.extend(phase_dir / relative_path for relative_path in ACTIVE_DOMAIN_FILES)
    active_paths.extend(sorted(phase_dir.glob("units/UNIT-*.json")))
    active_paths.extend(sorted(phase_dir.glob("unit-*/test-cases.json")))
    text = strip_repo_path_references(read_existing_text(active_paths))
    terms = split_feature_tokens(feature_id)
    terms.update(term for term in DOMAIN_VOCABULARY if re.search(rf"\b{re.escape(term)}\b", text))
    terms.update(infer_interface_terms(text))
    return terms


def assert_noise_checks(
    pilot: dict[str, Any], phase_dir: Path, required_terms: set[str]
) -> dict[str, dict[str, Any]]:
    """Block copied wording from another pilot in selected historical surfaces."""
    feature_id = require_text(pilot, "feature_id", "pilot")
    profiles: dict[str, dict[str, Any]] = {}
    configured_terms: set[str] = set()
    for check in require_list(pilot, "noise_checks", feature_id):
        if not isinstance(check, dict):
            raise AuditError(f"{feature_id}: noise_checks entry must be an object")
        label = require_text(check, "label", feature_id)
        if label in profiles:
            raise AuditError(f"{feature_id}: duplicate noise_check {label}")
        paths = require_list(check, "paths", f"{feature_id}:{label}")
        forbidden_terms = require_list(check, "forbidden_terms", f"{feature_id}:{label}")
        configured_terms.update(normalize_terms(forbidden_terms))
        scan_terms = sorted(normalize_terms(forbidden_terms) | required_terms)
        resolved_paths = scan_noise_paths(feature_id, label, paths, scan_terms, phase_dir)
        profiles[label] = {"paths": resolved_paths, "terms": set(scan_terms)}
    for term in sorted(required_terms - configured_terms):
        raise AuditError(f"{feature_id}: missing required forbidden term {term}")
    return profiles


def scan_noise_paths(
    feature_id: str,
    label: str,
    raw_paths: list[Any],
    scan_terms: list[str],
    phase_dir: Path,
) -> set[Path]:
    """Scan configured history and registry surfaces for forbidden terms."""
    resolved_paths: set[Path] = set()
    for raw_path in raw_paths:
        if not isinstance(raw_path, str) or not raw_path.strip():
            raise AuditError(f"{feature_id}:{label}: empty noise-check path")
        target_path = resolve_phase_child(phase_dir, raw_path)
        resolved_paths.add(target_path)
        for file_path in iter_text_files(target_path):
            assert_no_terms_in_file(feature_id, label, file_path, scan_terms)
    return resolved_paths


def assert_no_terms_in_file(feature_id: str, label: str, file_path: Path, terms: list[str]) -> None:
    """Fail when a scanned file contains a forbidden cross-pilot term."""
    text = file_path.read_text(encoding="utf-8").lower()
    for term in terms:
        if term in text:
            rel_path = file_path.relative_to(ROOT) if file_path.is_relative_to(ROOT) else file_path
            raise AuditError(f"{feature_id}:{label}:{rel_path}: forbidden term {term}")


def assert_developer_tdd(phase_dir: Path, feature_id: str) -> None:
    """Require every developer report to preserve RED and GREEN proof."""
    reports = sorted(phase_dir.glob("unit-*/tasks/*/developer-report.json"))
    if not reports:
        raise AuditError(f"{feature_id}: missing developer-report.json files")
    for report_path in reports:
        evidence = load_json(report_path).get("tdd_evidence_index")
        if not isinstance(evidence, list) or not evidence:
            raise AuditError(f"{report_path}: missing tdd_evidence_index")
        if not has_tdd_result(evidence, "RED", "FAIL_EXPECTED"):
            raise AuditError(f"{report_path}: missing RED FAIL_EXPECTED evidence")
        if not has_tdd_result(evidence, "GREEN", "PASS"):
            raise AuditError(f"{report_path}: missing GREEN PASS evidence")


def has_tdd_result(evidence: list[Any], phase: str, result: str) -> bool:
    """Return whether a developer report records the required TDD phase."""
    return any(
        item.get("phase") == phase and item.get("result") == result
        for item in evidence
        if isinstance(item, dict)
    )


def collect_resolved_findings(phase_dir: Path, feature_id: str) -> dict[str, dict[str, Any]]:
    """Load resolved review findings that must be backed by audit proof."""
    review = load_json(phase_dir / "code-review-result.json")
    findings = review.get("resolved_findings", [])
    if not isinstance(findings, list):
        raise AuditError(f"{feature_id}: resolved_findings must be an array")
    resolved: dict[str, dict[str, Any]] = {}
    for item in findings:
        if not isinstance(item, dict):
            raise AuditError(f"{feature_id}: resolved_findings entry must be an object")
        finding_id = require_text(item, "finding_id", feature_id)
        if item.get("status") != "RESOLVED":
            raise AuditError(f"{feature_id}:{finding_id}: status must be RESOLVED")
        require_text(item, "file_path", f"{feature_id}:{finding_id}")
        require_text(item, "red_evidence", f"{feature_id}:{finding_id}")
        require_text(item, "green_evidence", f"{feature_id}:{finding_id}")
        if finding_id in resolved:
            raise AuditError(f"{feature_id}: duplicate resolved finding {finding_id}")
        resolved[finding_id] = item
    return resolved


def collect_resolution_checks(pilot: dict[str, Any], feature_id: str) -> dict[str, dict[str, Any]]:
    """Index report-level proof for resolved review findings."""
    checks: dict[str, dict[str, Any]] = {}
    for item in require_list(pilot, "review_resolution_checks", feature_id):
        if not isinstance(item, dict):
            raise AuditError(f"{feature_id}: review_resolution_checks entry must be an object")
        finding_id = require_text(item, "finding_id", feature_id)
        if finding_id in checks:
            raise AuditError(f"{feature_id}: duplicate resolution check {finding_id}")
        require_text(item, "proof_command", f"{feature_id}:{finding_id}")
        require_text(item, "proof_result", f"{feature_id}:{finding_id}")
        require_list(item, "proof_refs", f"{feature_id}:{finding_id}")
        checks[finding_id] = item
    return checks
