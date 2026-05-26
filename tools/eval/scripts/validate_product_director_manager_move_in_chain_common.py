"""Shared fixture helpers for the move-in Director-to-PM eval."""

from __future__ import annotations

import copy
import hashlib
import json
from typing import Any


POST_REVIEW_FIELDS = {"review_conclusion", "issue_ledger", "delivery_confirmation"}


def digest(value: Any) -> str:
    raw = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return "sha256:" + hashlib.sha256(raw.encode("utf-8")).hexdigest()


def strip_post_review(payload: dict[str, Any]) -> dict[str, Any]:
    clone = copy.deepcopy(payload)
    for field in POST_REVIEW_FIELDS:
        clone.pop(field, None)
    return clone


def bundle_digest(refs: list[str], artifacts: list[dict[str, Any]]) -> str:
    return digest(
        [
            {"ref": ref, "payload": strip_post_review(artifact)}
            for ref, artifact in zip(refs, artifacts)
        ]
    )


def with_director_lock(payload: dict[str, Any], fields: list[str], confirmed_at: str) -> dict[str, Any]:
    locked = {field: payload[field] for field in fields}
    payload["director_confirmation"] = {
        "status": "passed",
        "confirmed_at": confirmed_at,
        "locked_field_digest": digest(locked),
        "locked_fields": locked,
    }
    return payload


def review_conclusion(refs: list[str], reviewed_digest: str) -> dict[str, Any]:
    perspectives = [
        ("product", ["phase-1/phase-prd.json#coverage_matrix", "phase-1/units/UNIT-1.json#acceptance_criteria"]),
        ("architecture", ["phase-1/phase-prd.json#technical_evidence_requirements"]),
        ("test", ["phase-1/units/UNIT-1.json#verification_plan", "phase-1/units/UNIT-2.json#verification_plan"]),
    ]
    return {
        "verdict": "PASS",
        "summary": "Move-in PM artifacts cover the accepted PRD rubric and are ready for design",
        "agent_team_review": {
            "mode": "agent_teams",
            "round": "R2",
            "reviewed_artifact_refs": refs,
            "reviewed_bundle_digest": reviewed_digest,
            "reviewer_verdicts": [
                {
                    "perspective": perspective,
                    "round": "R2",
                    "verdict": "PASS",
                    "reviewer_output_ref": f"agent-team://move-in-{perspective}-reviewer/R2",
                    "artifact_refs": refs,
                    "reviewed_bundle_digest": reviewed_digest,
                    "finding_refs": [],
                    "evidence_refs": evidence_refs,
                    "read_only": True,
                }
                for perspective, evidence_refs in perspectives
            ],
            "convergence_evidence": [
                {"round": "R2", "status": "CONFIRMATION", "evidence_refs": ["golden-rubric.json#core_thesis"]}
            ],
        },
    }
