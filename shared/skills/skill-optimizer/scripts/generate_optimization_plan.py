#!/usr/bin/env python3
"""Generate optimization-plan.json from accepted audit findings."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def file_path_from_ref(file_ref: str) -> str:
    if ":" not in file_ref:
        return file_ref
    return file_ref.rsplit(":", 1)[0]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("audit_artifact")
    parser.add_argument("--accept", action="append", default=[])
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    if not args.accept:
        fail("at least one accepted finding id is required")

    audit_path = Path(args.audit_artifact)
    audit = load_json(audit_path)
    findings = {finding["id"]: finding for finding in audit.get("findings", [])}
    missing = [finding_id for finding_id in args.accept if finding_id not in findings]
    if missing:
        fail(f"accepted finding ids not found: {', '.join(missing)}")

    accepted = [findings[finding_id] for finding_id in args.accept]
    accepted_ids = [finding["id"] for finding in accepted]
    plan = {
        "artifact_type": "optimization-plan",
        "schema_version": "1.0.0",
        "artifact_id": audit["artifact_id"].replace("skill-audit", "optimization-plan"),
        "producer": {"name": "generate_optimization_plan.py", "command": "generate_optimization_plan.py"},
        "inputs": [{"path": str(audit_path), "role": "skill_audit", "artifact_id": audit["artifact_id"]}],
        "status": "planned",
        "design_anchors": sorted({anchor for finding in accepted for anchor in finding.get("design_anchors", [])}),
        "evidence_refs": audit.get("evidence_refs", []),
        "rendered_views": [],
        "accepted_findings": accepted_ids,
        "rejected_findings": [finding_id for finding_id in findings if finding_id not in accepted_ids],
        "file_boundaries": [
            {"finding_id": finding["id"], "path": file_path_from_ref(finding.get("file_ref", "")), "mode": "edit"}
            for finding in accepted
        ],
        "non_goals": ["new Skill creation", "global hook registry integration"],
        "rollback": [
            {"finding_id": finding["id"], "action": "restore previous Skill route"}
            for finding in accepted
        ],
        "verification_contracts": [
            {
                "finding_id": finding["id"],
                "dimension": finding["dimension"],
                "success_standard_ref": f"{finding['id']}:{finding['dimension']}",
                "expected_behavior": finding["recommendation"],
                "command": finding["verification"],
                "expected_output": "PASS",
            }
            for finding in accepted
        ],
    }
    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
