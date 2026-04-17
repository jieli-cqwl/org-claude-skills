#!/usr/bin/env python3
"""Build or verify replay oracle records for a canonical phase directory."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from authority_proof import load_json as load_authority_fixture_json
from canonical_ref_resolver import split_artifact_ref
from manage_artifact_registry import entry_tuple, get_active_revision, load_json as load_registry_json
from normalize_canonical_artifact import load_json


def load_profiles(path: Path) -> dict:
    return load_json(path)["profiles"]


def extract_fields(document: dict, fields: list[str]) -> dict[str, object]:
    result: dict[str, object] = {}
    for field in fields:
        if "[]." in field:
            key, item_field = field.split("[].", 1)
            values = [item.get(item_field) for item in document.get(key, [])]
            if item_field != "result":
                values = [value for value in values if value is not None]
            result[field] = values
        elif field == "restore_entry_tuples":
            result[field] = document.get(field, [])
        else:
            result[field] = document.get(field)
    return result


def oracle_field_value(document: dict, field: str) -> object:
    if field in document:
        return document.get(field)
    return extract_fields(document, [field])[field]


def add_profile(profiles: list[str], profile_name: str, enabled: bool) -> None:
    if enabled and profile_name not in profiles:
        profiles.append(profile_name)


def infer_profiles(
    delivery_state: dict,
    signoff: dict,
    proof: dict,
    restore_basis_refs: list[str],
) -> list[str]:
    profiles = ["shared"]
    add_profile(
        profiles,
        "blocked-resume",
        any(
            delivery_state.get(field)
            for field in ("blocker_id", "resume_stage", "unblocked_by_ref")
        ),
    )
    add_profile(
        profiles,
        "conditional-allow",
        signoff.get("release_recommendation") == "CONDITIONAL_ALLOW"
        or bool(signoff.get("waiver_entries")),
    )
    goal_results = [item.get("result") for item in signoff.get("goal_closure", [])]
    add_profile(profiles, "partial-goal-closure", "PARTIAL" in goal_results)
    add_profile(profiles, "not-applicable", "N_A" in goal_results)
    add_profile(
        profiles,
        "authority-conflict",
        any(proof.get(field) for field in ("verified_actor_id", "verified_channel", "proof_type")),
    )
    add_profile(profiles, "quarantined-restore", bool(restore_basis_refs))
    return profiles


def build_oracle_record(phase_dir: Path) -> dict:
    delivery_state = load_json(phase_dir / "delivery-state.json")
    artifact_registry = load_registry_json(phase_dir / "artifact-registry.json")
    qa_result = load_json(phase_dir / "qa-result.json")
    signoff = load_json(phase_dir / "signoff-package.json")
    decision = load_json(phase_dir / "user-decision.json")
    manifest = load_json(phase_dir / "views/phase-operational.projection-manifest.json")
    proof_path = phase_dir / "evidence/authority-proof.json"
    proof = load_authority_fixture_json(proof_path) if proof_path.is_file() else {}

    active_revision = get_active_revision(artifact_registry)
    active_entries = active_revision.get("entries", [])
    active_entry_tuples = [
        list(entry_tuple(entry))
        for entry in active_entries
        if entry.get("active_for_consumption")
    ]
    quarantined_entry_tuples = [
        list(entry_tuple(entry))
        for entry in active_entries
        if entry.get("lifecycle_state") == "QUARANTINED"
    ]
    restore_entry_tuples = [
        [
            entry["artifact_type"],
            entry["artifact_id"],
            entry["version"],
            list(entry.get("restore_basis_refs", [])),
        ]
        for entry in active_entries
        if entry.get("restore_basis_refs")
    ]
    restore_basis_refs = sorted(
        {
            ref
            for entry in active_entries
            for ref in entry.get("restore_basis_refs", [])
        }
    )
    profile_names = infer_profiles(delivery_state, signoff, proof, restore_basis_refs)

    return {
        "profiles": profile_names,
        "artifacts": {
            "delivery-state": {
                "artifact_id": delivery_state["artifact_id"],
                "schema_version": delivery_state["schema_version"],
                "chain_version": delivery_state["chain_version"],
                "chain_registry_digest": delivery_state["chain_registry_digest"],
                "active_plan_version_ref": delivery_state["active_plan_version_ref"],
                "active_tasks_version_ref": delivery_state["active_tasks_version_ref"],
                "current_stage": delivery_state["current_stage"],
                "status": delivery_state["status"],
                "control_action": delivery_state["control_action"],
                "blocker_id": delivery_state.get("blocker_id"),
                "blocked_from_stage": delivery_state.get("blocked_from_stage"),
                "resume_stage": delivery_state.get("resume_stage"),
                "blocker_reason_code": delivery_state.get("blocker_reason_code"),
                "blocker_basis_refs": delivery_state.get("blocker_basis_refs", []),
                "blocker_resolution_evidence_refs": delivery_state.get("blocker_resolution_evidence_refs", []),
                "unblocked_by_ref": delivery_state.get("unblocked_by_ref"),
            },
            "artifact-registry": {
                "artifact_id": artifact_registry["artifact_id"],
                "schema_version": artifact_registry["schema_version"],
                "chain_version": artifact_registry["chain_version"],
                "chain_registry_digest": artifact_registry["chain_registry_digest"],
                "scope_ref": artifact_registry["scope_ref"],
                "registry_revision": artifact_registry["registry_revision"],
                "active_entry_tuples": active_entry_tuples,
                "quarantined_entry_tuples": quarantined_entry_tuples,
                "restore_entry_tuples": restore_entry_tuples,
                "restore_basis_refs": restore_basis_refs,
            },
            "qa-result": {
                "artifact_id": qa_result["artifact_id"],
                "schema_version": qa_result["schema_version"],
                "chain_version": qa_result["chain_version"],
                "chain_registry_digest": qa_result["chain_registry_digest"],
                "baseline_plan_version_ref": qa_result["baseline_plan_version_ref"],
                "baseline_tasks_version_ref": qa_result["baseline_tasks_version_ref"],
                "gate_result": qa_result["gate_result"],
                "related_issue_ids": qa_result.get("related_issue_ids", []),
            },
            "signoff-package": {
                "artifact_id": signoff["artifact_id"],
                "schema_version": signoff["schema_version"],
                "chain_version": signoff["chain_version"],
                "chain_registry_digest": signoff["chain_registry_digest"],
                "baseline_plan_version_ref": signoff["baseline_plan_version_ref"],
                "baseline_tasks_version_ref": signoff["baseline_tasks_version_ref"],
                "active_plan_version_ref": signoff["active_plan_version_ref"],
                "active_tasks_version_ref": signoff["active_tasks_version_ref"],
                "last_observed_at": signoff.get("last_observed_at"),
                "runtime_snapshot": signoff.get("runtime_snapshot"),
                "decision_basis_refs": signoff.get("decision_basis_refs", []),
                "release_recommendation": signoff["release_recommendation"],
                "goal_closure[].result": [item.get("result") for item in signoff.get("goal_closure", [])],
                "goal_closure[].remaining_gap_text": [
                    item.get("remaining_gap_text")
                    for item in signoff.get("goal_closure", [])
                    if item.get("remaining_gap_text")
                ],
                "goal_closure[].reason_code": [
                    item.get("reason_code")
                    for item in signoff.get("goal_closure", [])
                    if item.get("reason_code")
                ],
                "waiver_entries[].waiver_id": [
                    item.get("waiver_id") for item in signoff.get("waiver_entries", [])
                ],
            },
            "user-decision": {
                "artifact_id": decision["artifact_id"],
                "schema_version": decision["schema_version"],
                "chain_version": decision["chain_version"],
                "chain_registry_digest": decision["chain_registry_digest"],
                "baseline_plan_version_ref": decision["baseline_plan_version_ref"],
                "baseline_tasks_version_ref": decision["baseline_tasks_version_ref"],
                "active_plan_version_ref": decision["active_plan_version_ref"],
                "active_tasks_version_ref": decision["active_tasks_version_ref"],
                "sign_off_status": decision["sign_off_status"],
                "business_risk_acceptance_status": decision["business_risk_acceptance_status"],
                "decision_basis_refs": decision["decision_basis_refs"],
                "authority_proof_refs": decision["authority_proof_refs"],
                "director_lock_digests": decision["director_lock_digests"],
                "decision_payload_digest": decision["decision_payload_digest"],
            },
            "projection-manifest": {
                "artifact_id": manifest["artifact_id"],
                "schema_version": manifest["schema_version"],
                "chain_version": manifest["chain_version"],
                "chain_registry_digest": manifest["chain_registry_digest"],
                "source_artifact_refs": manifest["source_artifact_refs"],
                "section_source_map": manifest["section_source_map"],
                "rendered_artifact_ref": manifest["rendered_artifact_ref"],
                "rendered_content_digest": manifest["rendered_content_digest"],
            },
        },
        "proof": {
            "verified_actor_id": proof.get("verified_actor_id"),
            "verified_channel": proof.get("verified_channel"),
            "proof_type": proof.get("proof_type"),
        },
    }


def compare_record(actual: dict, expected: dict, profiles: dict) -> None:
    for artifact_name, expected_payload in expected.get("artifacts", {}).items():
        actual_payload = actual["artifacts"][artifact_name]
        for field in profiles["shared"]["must_match"]:
            if actual_payload.get(field) != expected_payload.get(field):
                raise ValueError(f"shared mismatch for {artifact_name}.{field}")
        for field, expected_value in expected_payload.items():
            if actual_payload.get(field) != expected_value:
                raise ValueError(f"oracle mismatch for {artifact_name}.{field}")
    profile_names = expected.get("profiles", [])
    if "blocked-resume" in profile_names:
        fields = profiles["blocked-resume"]["extra_must_match"]
        for field in fields:
            actual_value = oracle_field_value(actual["artifacts"]["delivery-state"], field)
            if actual_value != expected["artifacts"]["delivery-state"].get(field):
                raise ValueError(f"blocked-resume mismatch: {field}")
    if "conditional-allow" in profile_names:
        for field in profiles["conditional-allow"]["extra_must_match"]:
            actual_value = oracle_field_value(actual["artifacts"]["signoff-package"], field)
            if actual_value != expected["artifacts"]["signoff-package"].get(field):
                raise ValueError(f"conditional-allow mismatch: {field}")
    if "partial-goal-closure" in profile_names:
        partial = actual["artifacts"]["signoff-package"]
        expected_partial = expected["artifacts"]["signoff-package"]
        if partial.get("goal_closure[].result") != expected_partial.get("goal_closure[].result"):
            raise ValueError("partial-goal-closure result mismatch")
        if not (
            partial.get("goal_closure[].remaining_gap_text")
            or partial.get("waiver_entries[].waiver_id")
        ):
            raise ValueError("partial-goal-closure missing gap or waiver")
    if "not-applicable" in profile_names:
        fields = profiles["not-applicable"]["extra_must_match"]
        for field in fields:
            actual_value = oracle_field_value(actual["artifacts"]["signoff-package"], field)
            if actual_value != expected["artifacts"]["signoff-package"].get(field):
                raise ValueError(f"not-applicable mismatch: {field}")
    if "authority-conflict" in profile_names:
        for field in profiles["authority-conflict"]["extra_must_match"]:
            if actual["proof"].get(field) != expected["proof"].get(field):
                raise ValueError(f"authority-conflict mismatch: {field}")
        for field, expected_value in expected.get("proof", {}).items():
            if actual["proof"].get(field) != expected_value:
                raise ValueError(f"oracle mismatch for proof.{field}")
    if "quarantined-restore" in profile_names:
        fields = profiles["quarantined-restore"]["extra_must_match"]
        for field in fields:
            actual_value = oracle_field_value(actual["artifacts"]["artifact-registry"], field)
            if actual_value != expected["artifacts"]["artifact-registry"].get(field):
                raise ValueError(f"quarantined-restore mismatch: {field}")


def assert_projection_sources_resolve(actual: dict, profiles: dict) -> None:
    active_entries = actual["artifacts"]["artifact-registry"].get("active_entry_tuples", [])
    active_keys = {
        (artifact_type, artifact_id, version)
        for artifact_type, artifact_id, _version, _path, lifecycle_state, active_for_consumption in active_entries
        for version in (_version, "active")
        if lifecycle_state == "FINALIZED" and active_for_consumption
    }
    for source_ref in actual["artifacts"]["projection-manifest"].get("source_artifact_refs", []):
        artifact_type, artifact_id, version, _anchor = split_artifact_ref(source_ref)
        if (artifact_type, artifact_id, version) not in active_keys:
            raise ValueError(profiles["ref-break"]["must_fail_with"])


def assert_active_version_alignment(actual: dict, profiles: dict) -> None:
    delivery_state = actual["artifacts"]["delivery-state"]
    expected_plan_ref = delivery_state.get("active_plan_version_ref")
    expected_tasks_ref = delivery_state.get("active_tasks_version_ref")
    for artifact_name in ("signoff-package", "user-decision"):
        artifact = actual["artifacts"][artifact_name]
        if artifact.get("active_plan_version_ref") != expected_plan_ref:
            raise ValueError(profiles["mixed-version"]["must_fail_with"])
        if artifact.get("active_tasks_version_ref") != expected_tasks_ref:
            raise ValueError(profiles["mixed-version"]["must_fail_with"])


def dump_json(document: dict) -> None:
    json.dump(document, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase-dir", type=Path, required=True)
    parser.add_argument("--profiles", type=Path, required=True)
    parser.add_argument("--oracle", type=Path)
    parser.add_argument("--write-oracle", type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    profiles = load_profiles(args.profiles.resolve())
    actual = build_oracle_record(args.phase_dir.resolve())
    assert_projection_sources_resolve(actual, profiles)
    assert_active_version_alignment(actual, profiles)
    if args.write_oracle is not None:
        args.write_oracle.parent.mkdir(parents=True, exist_ok=True)
        args.write_oracle.write_text(json.dumps(actual, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if args.oracle is not None:
        expected = load_json(args.oracle.resolve())
        compare_record(actual, expected, profiles)
    elif args.write_oracle is None:
        dump_json(actual)


if __name__ == "__main__":
    main()
