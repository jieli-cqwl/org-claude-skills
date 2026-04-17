#!/usr/bin/env python3
"""Audit a target Skill and emit skill-audit.json."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def sha256_text(text: str) -> str:
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def line_for(text: str, needle: str) -> int:
    for index, line in enumerate(text.splitlines(), start=1):
        if needle in line:
            return index
    return 1


def parse_allowed_tools(text: str) -> list[str]:
    match = re.search(r"^allowed-tools:\s*(.+)$", text, re.MULTILINE)
    if not match:
        return []
    return [part.strip() for part in match.group(1).split(",") if part.strip()]


def parse_name(text: str) -> str:
    match = re.search(r"^name:\s*(.+)$", text, re.MULTILINE)
    return match.group(1).strip() if match else ""


def make_finding(
    *,
    finding_id: str,
    severity: str,
    dimension: str,
    evidence_level: str,
    source_marker: str,
    file_ref: str,
    design_anchors: list[str],
    evidence_refs: list[str],
    impact: str,
    recommendation: str,
    verification: str,
) -> dict[str, Any]:
    return {
        "id": finding_id,
        "severity": severity,
        "dimension": dimension,
        "evidence_level": evidence_level,
        "source_marker": source_marker,
        "file_ref": file_ref,
        "design_anchors": design_anchors,
        "evidence_refs": evidence_refs,
        "impact": impact,
        "recommendation": recommendation,
        "verification": verification,
    }


def missing_reference_findings(target_dir: Path, skill_text: str) -> tuple[list[dict[str, Any]], list[dict[str, str]]]:
    findings: list[dict[str, Any]] = []
    contracts: list[dict[str, str]] = []
    for ref in sorted(set(re.findall(r"`(references/[^`]+)`", skill_text))):
        ref_path = target_dir / ref
        status = "PASS" if ref_path.exists() else "FAIL"
        contracts.append({"path": ref, "status": status, "consumer": "audit runner"})
        if status == "FAIL":
            findings.append(
                make_finding(
                    finding_id="finding-reference-contract",
                    severity="FAIL",
                    dimension="D2",
                    evidence_level="E1",
                    source_marker="C11",
                    file_ref=f"{target_dir / 'SKILL.md'}:{line_for(skill_text, ref)}",
                    design_anchors=["SO-REFERENCE-01"],
                    evidence_refs=["ev-skill-file"],
                    impact="Referenced resource cannot be loaded by the runtime audit flow",
                    recommendation=f"Create referenced file or remove route: {ref}",
                    verification="bash tests/test-skill-optimizer-runtime-artifacts.sh",
                )
            )
    return findings, contracts


def audit_readonly_runtime(target_dir: Path, skill_text: str) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []
    name = parse_name(skill_text)
    is_audit_like = bool(re.search(r"(audit|review|explain|审计|检查|验证)", name, re.IGNORECASE))
    if not is_audit_like:
        return findings

    dangerous_tools = sorted(set(parse_allowed_tools(skill_text)) & {"Bash", "Write", "Edit", "MultiEdit"})
    if dangerous_tools:
        findings.append(
            make_finding(
                finding_id="finding-permission-boundary",
                severity="FAIL",
                dimension="D4",
                evidence_level="E3",
                source_marker="L",
                file_ref=f"{target_dir / 'SKILL.md'}:{line_for(skill_text, 'allowed-tools:')}",
                design_anchors=["SO-PERMISSION-01"],
                evidence_refs=["ev-skill-file"],
                impact="Read-only audit role exposes write or raw shell tool surface",
                recommendation=f"Remove unscoped tools from audit entry: {', '.join(dangerous_tools)}",
                verification="bash tests/test-skill-optimizer-runtime-artifacts.sh",
            )
        )

    if "## 完成校验" not in skill_text and "## Verification" not in skill_text:
        findings.append(
            make_finding(
                finding_id="finding-verification-contract",
                severity="FAIL",
                dimension="D6",
                evidence_level="E3",
                source_marker="L",
                file_ref=f"{target_dir / 'SKILL.md'}:1",
                design_anchors=["SO-VALIDATION-01"],
                evidence_refs=["ev-skill-file"],
                impact="Audit result has no explicit completion or verification contract",
                recommendation="Add completion checks with fresh proving command requirements",
                verification="bash tests/test-skill-optimizer-runtime-artifacts.sh",
            )
        )
    return findings


def build_artifact(target_dir: Path) -> dict[str, Any]:
    skill_file = target_dir / "SKILL.md"
    skill_text = read_text(skill_file)
    skill_hash = sha256_text(skill_text)
    findings, reference_contracts = missing_reference_findings(target_dir, skill_text)
    findings.extend(audit_readonly_runtime(target_dir, skill_text))
    if not findings:
        findings.append(
            make_finding(
                finding_id="finding-trigger-info",
                severity="INFO",
                dimension="D1",
                evidence_level="E1",
                source_marker="C09",
                file_ref=f"{skill_file}:1",
                design_anchors=["SO-TRIGGER-01"],
                evidence_refs=["ev-skill-file"],
                impact="Trigger boundary remains available for routing review",
                recommendation="Keep trigger boundary explicit",
                verification="bash tests/test-skill-optimizer-runtime-artifacts.sh",
            )
        )
    anchors = sorted({anchor for finding in findings for anchor in finding["design_anchors"]} | {"SO-RUNTIME-01"})
    return {
        "artifact_type": "skill-audit",
        "schema_version": "1.0.0",
        "artifact_id": f"skill-audit:{target_dir.name}",
        "producer": {"name": "audit_skill.py", "command": "audit_skill.py"},
        "inputs": [{"path": str(skill_file), "role": "target_skill", "hash": skill_hash}],
        "status": "audited",
        "design_anchors": anchors,
        "evidence_refs": [{"id": "ev-skill-file", "kind": "file", "ref": f"{skill_file}:1"}],
        "rendered_views": [],
        "target_skill": {
            "path": str(target_dir),
            "hash": skill_hash,
            "description": target_dir.name,
        },
        "scope": {
            "mode": "deterministic-smoke",
            "include": ["SKILL.md", "references/"],
            "exclude": [],
            "requires_manual_review_for": ["D1", "D3", "D5", "D7", "D8"],
        },
        "findings": findings,
        "permission_profile": {"mode": "read", "allowed_tools": parse_allowed_tools(skill_text)},
        "reference_contracts": reference_contracts,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("target_skill_dir")
    parser.add_argument("--out-dir", required=True)
    args = parser.parse_args()
    target_dir = Path(args.target_skill_dir)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    artifact = build_artifact(target_dir)
    (out_dir / "skill-audit.json").write_text(
        json.dumps(artifact, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
