#!/usr/bin/env python3
"""Verify authority proofs for finalized user-decision payloads."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path

from normalize_canonical_artifact import ROOT, load_json
from runtime_yaml import load_yaml
from write_user_decision import canonical_digest


def parse_timestamp(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def verify_authority_proof(
    proof: dict,
    decision_payload: dict,
    payload_digest: str,
    registry: dict,
    runtime_state: dict,
) -> dict:
    decision_source = decision_payload["decision_source"]
    rules = registry["decision_source_rules"]
    if decision_source not in rules:
        raise ValueError(f"unknown decision_source: {decision_source}")
    rule = rules[decision_source]
    if not rule.get("finalized_allowed"):
        raise ValueError(f"{decision_source} cannot produce finalized user decision")
    if proof["proof_type"] != rule["required_proof_type"]:
        raise ValueError("proof_type does not match decision_source")
    if proof["decision_payload_digest"] != payload_digest:
        raise ValueError("payload digest mismatch")
    if decision_payload["actor_id"] != proof["verified_actor_id"]:
        raise ValueError("actor must match verified actor")
    if proof["verified_channel"] not in rule["allowed_channels"]:
        raise ValueError("channel not allowed for source")
    produced_at = parse_timestamp(decision_payload["produced_at"])
    if parse_timestamp(proof["verified_at"]) > produced_at:
        raise ValueError("proof was not yet valid when decision was produced")
    if parse_timestamp(proof["verified_until"]) < produced_at:
        raise ValueError("expired proof")
    if runtime_state["active_plan_version_ref"] != decision_payload["active_plan_version_ref"]:
        raise ValueError("stale decision after replan")
    if runtime_state["active_tasks_version_ref"] != decision_payload["active_tasks_version_ref"]:
        raise ValueError("stale task baseline after replan")
    return {
        "verified_actor_id": proof["verified_actor_id"],
        "verified_channel": proof["verified_channel"],
        "proof_type": proof["proof_type"],
    }


def dump_json(document: dict) -> None:
    json.dump(document, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", type=Path, required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    fixture = load_json(args.fixture.resolve())
    decision_payload = fixture.get("decision_payload")
    proof = fixture.get("proof")
    runtime_state = fixture.get("runtime_state")
    if not isinstance(decision_payload, dict):
        raise ValueError("decision_payload 必须存在")
    if not isinstance(proof, dict):
        raise ValueError("proof 必须存在")
    if not isinstance(runtime_state, dict):
        raise ValueError("runtime_state 必须存在")
    if not decision_payload.get("authority_proof_refs"):
        raise ValueError("authority_proof_refs 不能为空")
    for proof_ref in decision_payload["authority_proof_refs"]:
        if not str(proof_ref).startswith("artifact://evidence/"):
            raise ValueError("authority proof refs must point to evidence artifacts")
    payload_digest = canonical_digest(decision_payload)
    registry = load_yaml(ROOT / "contracts/canonical/authority-registry.yaml")
    dump_json(verify_authority_proof(proof, decision_payload, payload_digest, registry, runtime_state))


if __name__ == "__main__":
    main()
