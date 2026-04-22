#!/usr/bin/env python3
"""Validate standard-chain pilot audit reports against realized evidence."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

from standard_chain_pilot_audit_core import (
    AuditError,
    assert_developer_tdd,
    assert_noise_checks,
    collect_resolution_checks,
    collect_resolved_findings,
    infer_domain_terms,
    load_json,
    require_list,
    require_text,
    resolve_repo_path,
)
from standard_chain_pilot_audit_proof import assert_resolution_proofs


def parse_args() -> argparse.Namespace:
    """Read the audit report location selected by the caller."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--audit", type=Path, required=True)
    return parser.parse_args()


def assert_pilot(pilot: dict[str, object], required_terms: set[str]) -> None:
    """Validate one pilot entry against its phase artifacts and report proof."""
    feature_id = require_text(pilot, "feature_id", "pilot")
    phase_dir = resolve_repo_path(require_text(pilot, "phase_dir", feature_id))
    smoke_script = resolve_repo_path(require_text(pilot, "smoke_script", feature_id))
    if not phase_dir.is_dir():
        raise AuditError(f"{feature_id}: missing phase_dir {phase_dir}")
    if not smoke_script.is_file():
        raise AuditError(f"{feature_id}: missing smoke_script {smoke_script}")
    noise_profiles = assert_noise_checks(pilot, phase_dir, required_terms)
    assert_developer_tdd(phase_dir, feature_id)
    findings = collect_resolved_findings(phase_dir, feature_id)
    checks = collect_resolution_checks(pilot, feature_id)
    assert_resolution_proofs(feature_id, findings, checks, noise_profiles)


def assert_audit_report(audit_path: Path) -> None:
    """Validate the full report and all declared pilot entries."""
    payload = load_json(audit_path)
    if payload.get("report_type") != "standard-chain-pilot-audit":
        raise AuditError("audit report_type must be standard-chain-pilot-audit")
    if payload.get("conclusion") != "PASS":
        raise AuditError("audit conclusion must be PASS")
    pilots = require_list(payload, "pilots", "audit")
    if len(pilots) < 2:
        raise AuditError("audit must include at least two pilots")
    domain_terms = collect_domain_terms(pilots)
    for pilot in pilots:
        feature_id = require_text(pilot, "feature_id", "pilot")
        foreign_terms = set().union(
            *(terms for source_id, terms in domain_terms.items() if source_id != feature_id)
        )
        assert_pilot(pilot, foreign_terms - domain_terms[feature_id])


def collect_domain_terms(pilots: list[object]) -> dict[str, set[str]]:
    """Infer each pilot domain before checking cross-pilot residue."""
    domain_terms: dict[str, set[str]] = {}
    for pilot in pilots:
        if not isinstance(pilot, dict):
            raise AuditError("audit pilots entry must be an object")
        feature_id = require_text(pilot, "feature_id", "pilot")
        phase_dir = resolve_repo_path(require_text(pilot, "phase_dir", feature_id))
        domain_terms[feature_id] = infer_domain_terms(feature_id, phase_dir)
    return domain_terms


def main() -> int:
    """Run the pilot audit validator and print a compact PASS marker."""
    args = parse_args()
    try:
        assert_audit_report(args.audit.resolve())
    except (AuditError, OSError, json.JSONDecodeError, subprocess.TimeoutExpired) as exc:
        print(f"[pilot-audit][ERROR] {exc}", file=sys.stderr)
        return 1
    print("[PASS] standard-chain pilot audit report")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
