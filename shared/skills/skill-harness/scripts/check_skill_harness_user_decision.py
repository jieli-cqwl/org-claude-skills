"""Validate standard-chain user-decision authority gates."""
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

import yaml

REPO_ROOT = Path(__file__).resolve().parents[4]
SHA256_REF = re.compile(r"^sha256:[0-9a-f]{64}$")
USER_DECISION_FIELDS = set("artifact_type artifact_id schema_version producer produced_at chain_version chain_registry_digest authority_scope authoritative_fields baseline_plan_version_ref baseline_tasks_version_ref active_plan_version_ref active_tasks_version_ref current_stage decision decision_source actor_id sign_off_status business_risk_acceptance_status authority_proof_refs decision_basis_refs director_lock_digests".split())
USER_DECISION_FLAGS = "must_verify_authority_proof_refs must_verify_payload_digest must_match_actor_and_channel".split()
ARRAY_FIELDS = {"authoritative_fields", "authority_proof_refs", "decision_basis_refs"}
STRING_FIELDS = USER_DECISION_FIELDS - ARRAY_FIELDS - {"director_lock_digests"}


def fail(message: str) -> None:
    print(f"[FAIL] {message}", file=sys.stderr)
    raise SystemExit(1)


def missing(value: Any) -> bool:
    return value in (None, "", [], {})


def require_keys(sample: dict[str, Any], keys: set[str], code: str) -> None:
    for key in keys:
        if missing(sample.get(key)):
            fail(code)


def require_string(value: Any, code: str) -> str:
    if not isinstance(value, str) or not value.strip():
        fail(code)
    return value


def require_string_array(value: Any, code: str) -> list[str]:
    if not isinstance(value, list) or not value or any(not isinstance(item, str) or not item.strip() for item in value):
        fail(code)
    return value


def require_sha256(value: Any, code: str) -> str:
    digest = require_string(value, code)
    if not SHA256_REF.match(digest):
        fail(code)
    return digest


def require_director_lock_digests(value: Any) -> None:
    if not isinstance(value, dict) or set(value) != {"brief", "phase-prd"}:
        fail("USER_DECISION_SHAPE_INVALID")
    require_sha256(value["brief"], "USER_DECISION_SHAPE_INVALID")
    require_sha256(value["phase-prd"], "USER_DECISION_SHAPE_INVALID")


def load_authority_registry() -> dict[str, Any]:
    return yaml.safe_load((REPO_ROOT / "contracts/canonical/authority-registry.yaml").read_text(encoding="utf-8"))


def decision_payload_digest(sample: dict[str, Any]) -> str:
    payload = {key: sample[key] for key in sorted(USER_DECISION_FIELDS) if key in sample}
    return "sha256:" + hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()


def validate_user_decision_shape(sample: dict[str, Any], registry: dict[str, Any]) -> dict[str, Any]:
    require_keys(sample, USER_DECISION_FIELDS | {"decision_payload_digest", "allowed_final_decision_sources", "authority_proof"} | set(USER_DECISION_FLAGS), "USER_AUTHORITY_REQUIRED")
    if any(sample[field] is not True for field in USER_DECISION_FLAGS):
        fail("USER_AUTHORITY_REQUIRED")
    for field in STRING_FIELDS:
        require_string(sample[field], "USER_DECISION_SHAPE_INVALID")
    for field in ARRAY_FIELDS:
        require_string_array(sample[field], "USER_DECISION_SHAPE_INVALID")
    require_director_lock_digests(sample["director_lock_digests"])
    require_sha256(sample["decision_payload_digest"], "DIGEST_MISMATCH")
    if sample["artifact_type"] != "user-decision":
        fail("USER_AUTHORITY_REQUIRED")
    allowed = registry["v1_user_decision_policy"]["allowed_final_sources"]
    if sample["allowed_final_decision_sources"] != allowed or sample["decision_source"] not in allowed:
        fail("USER_AUTHORITY_REQUIRED")
    rule = registry["decision_source_rules"].get(sample["decision_source"])
    if not isinstance(rule, dict):
        fail("USER_AUTHORITY_REQUIRED")
    return rule


def validate_user_authority(sample: dict[str, Any], rule: dict[str, Any]) -> None:
    proof = sample["authority_proof"]
    if not isinstance(proof, dict):
        fail("USER_AUTHORITY_REQUIRED")
    require_keys(proof, {"proof_type", "verified_actor_id", "verified_channel", "decision_payload_digest"}, "USER_AUTHORITY_REQUIRED")
    proof_type = require_string(proof["proof_type"], "USER_AUTHORITY_REQUIRED")
    channel = require_string(proof["verified_channel"], "USER_AUTHORITY_REQUIRED")
    actor = require_string(proof["verified_actor_id"], "USER_AUTHORITY_REQUIRED")
    proof_digest = require_sha256(proof["decision_payload_digest"], "DIGEST_MISMATCH")
    if proof_type != rule["required_proof_type"]:
        fail("PROOF_TYPE_MISMATCH")
    if channel not in rule["allowed_channels"]:
        fail("CHANNEL_MISMATCH")
    if actor != sample["actor_id"]:
        fail("ACTOR_MISMATCH")
    if proof_digest != sample["decision_payload_digest"]:
        fail("DIGEST_MISMATCH")


def validate_user_decision(sample: dict[str, Any]) -> None:
    rule = validate_user_decision_shape(sample, load_authority_registry())
    if sample["baseline_plan_version_ref"] != sample["active_plan_version_ref"]:
        fail("BASELINE_DRIFT")
    if sample["baseline_tasks_version_ref"] != sample["active_tasks_version_ref"]:
        fail("BASELINE_DRIFT")
    validate_user_authority(sample, rule)
    if sample["decision_payload_digest"] != decision_payload_digest(sample):
        fail("DIGEST_MISMATCH")
