from __future__ import annotations

from pathlib import Path
from typing import Callable

from write_user_decision import canonical_digest

DIRECTOR_LOCK_ARTIFACTS = ("brief", "phase-prd")
SIGNOFF_RUNTIME_EVIDENCE_TYPES = {
    "developer-report",
    "verify-result",
    "code-review-result",
    "qa-result",
    "consistency-audit-result",
}

LoadJson = Callable[[Path], dict]
SplitArtifactRef = Callable[[str], tuple[str, str, str, str]]
ActiveEntries = Callable[[dict], list[dict]]
ResolveRegistryPath = Callable[[Path, str], Path]
VerifyAuthorityProof = Callable[[dict, dict, str, dict, dict], None]


def director_lock_digest(payload: dict, artifact_type: str) -> str:
    confirmation = payload.get("director_confirmation")
    if not isinstance(confirmation, dict):
        raise ValueError(
            f"director lock artifact missing director_confirmation: {artifact_type}:{payload.get('artifact_id')}"
        )
    digest = str(confirmation.get("locked_field_digest", "")).strip()
    if not digest:
        raise ValueError(
            f"director lock artifact missing locked_field_digest: {artifact_type}:{payload.get('artifact_id')}"
        )
    return digest


def assert_registry_director_lock_digest(
    artifact_type: str, payload: dict, entry: dict
) -> None:
    if artifact_type not in DIRECTOR_LOCK_ARTIFACTS:
        return
    expected = director_lock_digest(payload, artifact_type)
    actual = str(entry.get("director_lock_digest", "")).strip()
    if not actual:
        raise ValueError(
            f"active registry entry missing director_lock_digest: {artifact_type}:{payload.get('artifact_id')}"
        )
    if actual != expected:
        raise ValueError(
            f"active registry director_lock_digest drift: {artifact_type}:{payload.get('artifact_id')}"
        )


def assert_user_decision_director_lock_digests(
    phase_dir: Path, decision: dict, load_json: LoadJson
) -> None:
    actual = decision.get("director_lock_digests")
    if not isinstance(actual, dict):
        raise ValueError("user-decision director_lock_digests must be an object")
    expected = {
        "brief": director_lock_digest(
            load_json(phase_dir.parent / "brief.json"), "brief"
        ),
        "phase-prd": director_lock_digest(
            load_json(phase_dir / "phase-prd.json"), "phase-prd"
        ),
    }
    if set(actual.keys()) != set(expected.keys()):
        raise ValueError(
            "user-decision director_lock_digests must exactly cover brief and phase-prd"
        )
    for artifact_type, expected_digest in expected.items():
        actual_digest = str(actual.get(artifact_type, "")).strip()
        if actual_digest != expected_digest:
            raise ValueError(
                f"user-decision director_lock_digests drift: {artifact_type}"
            )


def find_authority_proof(phase_dir: Path, proof_ref: str, load_json: LoadJson) -> dict:
    for proof_path in sorted((phase_dir / "evidence").glob("*.json")):
        proof = load_json(proof_path)
        if proof_ref in proof.get("proof_basis_refs", []):
            return proof
    raise FileNotFoundError(f"authority proof not found for {proof_ref}")


def assert_authority_proof(
    phase_dir: Path,
    load_json: LoadJson,
    load_yaml: Callable[[Path], dict],
    authority_registry_path: Path,
    verify_authority_proof: VerifyAuthorityProof,
) -> None:
    decision = load_json(phase_dir / "user-decision.json")
    refs = decision.get("authority_proof_refs")
    if not isinstance(refs, list) or not refs:
        raise ValueError("user-decision authority_proof_refs must be non-empty")
    registry = load_yaml(authority_registry_path)
    runtime_state = load_json(phase_dir / "delivery-state.json")
    digest = canonical_digest(decision)
    if decision.get("decision_payload_digest") != digest:
        raise ValueError(
            "user-decision decision_payload_digest must match canonical payload digest"
        )
    assert_user_decision_director_lock_digests(phase_dir, decision, load_json)
    for index, proof_ref in enumerate(refs, start=1):
        proof = find_authority_proof(phase_dir, str(proof_ref), load_json)
        try:
            verify_authority_proof(proof, decision, digest, registry, runtime_state)
        except ValueError as exc:
            raise ValueError(
                f"user-decision authority_proof_refs[{index}] failed verification: {proof_ref}"
            ) from exc


def expected_runtime_status(artifact_type: str, payload: dict) -> str:
    if artifact_type == "developer-report":
        return str(payload.get("runtime_status", ""))
    if artifact_type in {"verify-result", "code-review-result", "qa-result"}:
        return str(payload.get("gate_result", ""))
    if artifact_type == "consistency-audit-result":
        runtime_chain = payload.get("runtime_chain", {})
        if not isinstance(runtime_chain, dict):
            return ""
        return str(runtime_chain.get("status", ""))
    return ""


def expected_freshness_basis_ref(artifact_type: str, payload: dict) -> str:
    ref = payload.get("active_tasks_version_ref")
    if not isinstance(ref, str) or not ref.strip():
        raise ValueError(
            f"{artifact_type} missing active_tasks_version_ref for signoff evidence freshness"
        )
    return ref


def active_registry_proof_key(
    registry: dict, entry: dict, split_artifact_ref: SplitArtifactRef
) -> tuple[str, str, str]:
    proof = entry.get("active_registry_proof")
    if not isinstance(proof, dict):
        raise ValueError(
            "signoff runtime_evidence_matrix entry missing active_registry_proof"
        )
    registry_type, registry_id, revision_id, anchor = split_artifact_ref(
        str(proof.get("registry_ref", ""))
    )
    if registry_type != "artifact-registry":
        raise ValueError(
            "signoff runtime evidence active_registry_proof.registry_ref must target artifact-registry"
        )
    if registry_id != registry.get("artifact_id"):
        raise ValueError(
            "signoff runtime evidence active registry proof artifact_id drift"
        )
    if revision_id != registry.get("active_revision_id"):
        raise ValueError(
            "signoff runtime evidence active registry proof revision drift"
        )
    if not anchor.startswith("active-entry:"):
        raise ValueError(
            "signoff runtime evidence active registry proof anchor must name active-entry"
        )
    if proof.get("lifecycle_state") != "FINALIZED":
        raise ValueError(
            "signoff runtime evidence active_registry_proof.lifecycle_state must be FINALIZED"
        )
    if proof.get("active_for_consumption") is not True:
        raise ValueError(
            "signoff runtime evidence active_registry_proof.active_for_consumption must be true"
        )
    try:
        _prefix, artifact_type, artifact_id = anchor.split(":", 2)
    except ValueError as exc:
        raise ValueError(
            "signoff runtime evidence active registry proof anchor is malformed"
        ) from exc
    return artifact_type, artifact_id, revision_id


def assert_signoff_runtime_evidence_matrix(
    phase_dir: Path,
    registry: dict,
    load_json: LoadJson,
    split_artifact_ref: SplitArtifactRef,
    active_entries: ActiveEntries,
    resolve_registry_path: ResolveRegistryPath,
) -> None:
    signoff = load_json(phase_dir / "signoff-package.json")
    matrix = signoff.get("runtime_evidence_matrix")
    if not isinstance(matrix, list) or not matrix:
        raise ValueError(
            "signoff-package runtime_evidence_matrix must be a non-empty array"
        )

    expected_entries = {
        (
            str(entry.get("artifact_type")),
            str(entry.get("artifact_id")),
            str(entry.get("version")),
        ): entry
        for entry in active_entries(registry)
        if entry.get("artifact_type") in SIGNOFF_RUNTIME_EVIDENCE_TYPES
    }
    seen: set[tuple[str, str, str]] = set()

    for index, row in enumerate(matrix, start=1):
        if not isinstance(row, dict):
            raise ValueError(
                f"signoff-package runtime_evidence_matrix[{index}] must be an object"
            )
        artifact_type = str(row.get("artifact_type", ""))
        if artifact_type not in SIGNOFF_RUNTIME_EVIDENCE_TYPES:
            raise ValueError(
                f"signoff-package runtime_evidence_matrix[{index}] has unsupported artifact_type"
            )
        ref_type, artifact_id, version, _anchor = split_artifact_ref(
            str(row.get("artifact_ref", ""))
        )
        key = (artifact_type, artifact_id, version)
        if ref_type != artifact_type:
            raise ValueError(
                f"signoff-package runtime_evidence_matrix[{index}] artifact_ref type drift"
            )
        if key not in expected_entries:
            raise ValueError(
                f"signoff-package runtime_evidence_matrix[{index}] does not match an active registry entry"
            )
        if key in seen:
            raise ValueError(
                f"signoff-package runtime_evidence_matrix duplicates active evidence: {key}"
            )
        seen.add(key)

        registry_entry = expected_entries[key]
        proof_type, proof_artifact_id, _proof_revision = active_registry_proof_key(
            registry, row, split_artifact_ref
        )
        if proof_type != artifact_type or proof_artifact_id != artifact_id:
            raise ValueError(
                f"signoff-package runtime_evidence_matrix[{index}] active registry proof drift"
            )
        if row.get("producer") != registry_entry.get("produced_by"):
            raise ValueError(
                f"signoff-package runtime_evidence_matrix[{index}] producer drift"
            )

        payload = load_json(
            resolve_registry_path(
                phase_dir, str(registry_entry.get("artifact_path", ""))
            )
        )
        if row.get("status") != expected_runtime_status(artifact_type, payload):
            raise ValueError(
                f"signoff-package runtime_evidence_matrix[{index}] status drift"
            )
        if row.get("freshness_basis_ref") != expected_freshness_basis_ref(
            artifact_type, payload
        ):
            raise ValueError(
                f"signoff-package runtime_evidence_matrix[{index}] freshness_basis_ref drift"
            )
        if row.get("stale_superseded_check") != "CURRENT":
            raise ValueError(
                f"signoff-package runtime_evidence_matrix[{index}] must prove CURRENT evidence"
            )

    missing = sorted(set(expected_entries) - seen)
    if missing:
        raise ValueError(
            f"signoff-package runtime_evidence_matrix missing active runtime evidence: {missing}"
        )
