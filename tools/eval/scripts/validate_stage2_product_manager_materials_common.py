"""Shared review helpers for Stage 2 product-manager material fixtures."""

from __future__ import annotations

import copy
import hashlib
import json
from typing import Any


POST_REVIEW_FIELDS = {"review_conclusion", "issue_ledger", "delivery_confirmation"}
REVIEWED_REFS = ["brief.json", "phase-1/phase-prd.json", "phase-1/units/UNIT-1.json"]


def digest(value: Any) -> str:
    raw = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return "sha256:" + hashlib.sha256(raw.encode("utf-8")).hexdigest()


def strip_post_review(payload: dict[str, Any]) -> dict[str, Any]:
    clone = copy.deepcopy(payload)
    for field in POST_REVIEW_FIELDS:
        clone.pop(field, None)
    return clone


def bundle_digest(artifacts: list[dict[str, Any]]) -> str:
    return digest(
        [
            {"ref": ref, "payload": strip_post_review(artifact)}
            for ref, artifact in zip(REVIEWED_REFS, artifacts)
        ]
    )


def review_conclusion(reviewed_digest: str) -> dict[str, Any]:
    verdicts = []
    for perspective, evidence_refs in [
        ("product", ["brief.json#acceptance_criteria", "phase-1/phase-prd.json#business_flows"]),
        ("architecture", ["phase-1/units/UNIT-1.json#integration_context"]),
        ("test", ["phase-1/units/UNIT-1.json#verification_plan"]),
    ]:
        verdicts.append(
            {
                "perspective": perspective,
                "round": "R2",
                "verdict": "PASS",
                "reviewer_output_ref": f"agent-team://{perspective}-reviewer/R2",
                "artifact_refs": REVIEWED_REFS,
                "reviewed_bundle_digest": reviewed_digest,
                "finding_refs": [],
                "evidence_refs": evidence_refs,
                "read_only": True,
            }
        )
    return {
        "verdict": "PASS",
        "summary": "PM artifacts are closed for design consumption",
        "agent_team_review": {
            "mode": "agent_teams",
            "round": "R2",
            "reviewed_artifact_refs": REVIEWED_REFS,
            "reviewed_bundle_digest": reviewed_digest,
            "reviewer_verdicts": verdicts,
            "convergence_evidence": [
                {
                    "round": "R2",
                    "status": "CONFIRMATION",
                    "evidence_refs": [
                        "brief.json#review_conclusion.agent_team_review",
                        "phase-1/phase-prd.json#review_conclusion.agent_team_review",
                    ],
                }
            ],
        },
    }
