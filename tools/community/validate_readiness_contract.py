#!/usr/bin/env python3
"""Semantic readiness checks that bind registry, task artifacts, and signoff."""

from __future__ import annotations

import re
from pathlib import Path

from authority_proof import load_yaml, verify_authority_proof
from manage_artifact_registry import get_active_revision
from normalize_canonical_artifact import ROOT, load_json
from readiness_closure_checks import assert_signoff_closure as _assert_signoff_closure
from readiness_review_checks import assert_code_review_pass as _assert_code_review_pass
from readiness_runtime_checks import (
    assert_task_runtime_identity as _assert_task_runtime_identity,
)
from readiness_signoff_checks import (
    assert_authority_proof as _assert_authority_proof,
    assert_registry_director_lock_digest,
    assert_signoff_runtime_evidence_matrix as _assert_signoff_runtime_evidence_matrix,
)

CANONICAL_REF_RE = re.compile(r"^artifact://([^/]+)/([^@]+)@([^#]+)#(.+)$")


def resolve_registry_path(phase_dir: Path, artifact_path: str) -> Path:
    candidate = Path(artifact_path)
    if candidate.is_absolute():
        return candidate.resolve()
    return (phase_dir / candidate).resolve()


def active_entries(registry: dict) -> list[dict]:
    return [
        entry
        for entry in get_active_revision(registry).get("entries", [])
        if entry.get("active_for_consumption") is True
    ]


def artifact_key(path: Path, payload: dict) -> tuple[str, str, Path]:
    """Return the identity tuple that an active registry entry must bind."""

    return (
        str(payload.get("artifact_type", "")),
        str(payload.get("artifact_id", "")),
        path.resolve(),
    )


def split_artifact_ref(ref: str) -> tuple[str, str, str, str]:
    match = CANONICAL_REF_RE.match(ref)
    if not match:
        raise ValueError(f"invalid canonical artifact ref: {ref}")
    return match.group(1), match.group(2), match.group(3), match.group(4)


def version_from_ref(ref: str) -> str:
    return split_artifact_ref(ref)[2]


def phase_goal_ref(phase_dir: Path) -> str:
    phase_prd = load_json(phase_dir / "phase-prd.json")
    return f"artifact://phase-prd/{phase_prd['artifact_id']}@v1#phase-goal"


def expected_registry_version(
    phase_dir: Path, artifact_type: str, payload: dict
) -> str:
    if artifact_type == "plan":
        return str(payload.get("plan_version", ""))
    if artifact_type == "tasks":
        delivery_state = load_json(phase_dir / "delivery-state.json")
        return version_from_ref(str(delivery_state.get("active_tasks_version_ref", "")))
    return "v1"


def expected_registry_scope_ref(
    phase_dir: Path, artifact_type: str, payload: dict
) -> str:
    if artifact_type in {"developer-report", "verify-result"}:
        delivery_state = load_json(phase_dir / "delivery-state.json")
        tasks_ref = str(delivery_state.get("active_tasks_version_ref", ""))
        task_id = str(payload.get("task_id", ""))
        artifact_type_ref, artifact_id, version, _anchor = split_artifact_ref(tasks_ref)
        if artifact_type_ref != "tasks" or not task_id:
            raise ValueError(
                f"cannot derive task scope_ref for {artifact_type}:{payload.get('artifact_id')}"
            )
        return f"artifact://tasks/{artifact_id}@{version}#task-{task_id}"
    return phase_goal_ref(phase_dir)


def expected_active_artifact_keys(
    artifact_paths: list[Path],
) -> set[tuple[str, str, Path]]:
    """Collect finalized delivery artifacts that readiness validates directly."""

    keys = set()
    for artifact_path in artifact_paths:
        payload = load_json(artifact_path)
        if payload.get("artifact_type") == "artifact-registry":
            continue
        keys.add(artifact_key(artifact_path, payload))
    return keys


def assert_active_registry_matches_artifacts(
    phase_dir: Path,
    artifact_paths: list[Path],
    registry: dict,
) -> None:
    entries = active_entries(registry)
    expected_keys = expected_active_artifact_keys(artifact_paths)
    for artifact_path in artifact_paths:
        payload = load_json(artifact_path)
        artifact_type = payload.get("artifact_type")
        if artifact_type == "artifact-registry":
            continue
        artifact_id = payload.get("artifact_id")
        matches = []
        for entry in entries:
            if (
                entry.get("artifact_type") != artifact_type
                or entry.get("artifact_id") != artifact_id
            ):
                continue
            if entry.get("lifecycle_state") != "FINALIZED":
                raise ValueError(
                    f"readiness active artifact must be FINALIZED: {artifact_type}:{artifact_id}"
                )
            expected_version = expected_registry_version(
                phase_dir, str(artifact_type), payload
            )
            if entry.get("version") != expected_version:
                raise ValueError(
                    f"active registry entry version drift: {artifact_type}:{artifact_id}"
                )
            expected_scope = expected_registry_scope_ref(
                phase_dir, str(artifact_type), payload
            )
            if entry.get("scope_ref") != expected_scope:
                raise ValueError(
                    f"active registry entry scope_ref drift: {artifact_type}:{artifact_id}"
                )
            resolved_path = resolve_registry_path(
                phase_dir, str(entry.get("artifact_path", ""))
            )
            if resolved_path == artifact_path.resolve():
                matches.append(entry)
        if len(matches) != 1:
            raise ValueError(
                f"missing active registry binding: {artifact_type}:{artifact_id}"
            )
        assert_registry_director_lock_digest(str(artifact_type), payload, matches[0])

        entry_payload = load_json(
            resolve_registry_path(phase_dir, matches[0]["artifact_path"])
        )
        if (
            entry_payload.get("artifact_type") != artifact_type
            or entry_payload.get("artifact_id") != artifact_id
        ):
            raise ValueError(
                f"active registry entry identity drift: {artifact_type}:{artifact_id}"
            )

    for entry in entries:
        if entry.get("lifecycle_state") != "FINALIZED":
            raise ValueError(
                f"readiness active artifact must be FINALIZED: {entry.get('artifact_type')}:{entry.get('artifact_id')}"
            )
        resolved_path = resolve_registry_path(
            phase_dir, str(entry.get("artifact_path", ""))
        )
        if not resolved_path.is_file():
            raise FileNotFoundError(
                f"active registry artifact_path is not present: {entry.get('artifact_path')}"
            )
        payload = load_json(resolved_path)
        entry_key = (
            str(entry.get("artifact_type", "")),
            str(entry.get("artifact_id", "")),
            resolved_path,
        )
        if artifact_key(resolved_path, payload) != entry_key:
            raise ValueError(
                f"active registry entry identity drift: {entry.get('artifact_type')}:{entry.get('artifact_id')}"
            )
        if entry.get("version") != expected_registry_version(
            phase_dir, str(entry.get("artifact_type", "")), payload
        ):
            raise ValueError(
                f"active registry entry version drift: {entry.get('artifact_type')}:{entry.get('artifact_id')}"
            )
        if entry.get("scope_ref") != expected_registry_scope_ref(
            phase_dir, str(entry.get("artifact_type", "")), payload
        ):
            raise ValueError(
                f"active registry entry scope_ref drift: {entry.get('artifact_type')}:{entry.get('artifact_id')}"
            )
        assert_registry_director_lock_digest(
            str(entry.get("artifact_type", "")), payload, entry
        )
        if entry_key not in expected_keys:
            raise ValueError(
                f"unexpected active registry entry outside readiness artifact set: {entry.get('artifact_type')}:{entry.get('artifact_id')}"
            )


def assert_authority_proof(phase_dir: Path) -> None:
    _assert_authority_proof(
        phase_dir,
        load_json,
        load_yaml,
        ROOT / "contracts/canonical/authority-registry.yaml",
        verify_authority_proof,
    )


def assert_code_review_pass(phase_dir: Path) -> None:
    _assert_code_review_pass(phase_dir, load_json)


def assert_signoff_closure(feature_dir: Path, phase_dir: Path) -> None:
    _assert_signoff_closure(
        feature_dir,
        phase_dir,
        load_json,
        version_from_ref,
        split_artifact_ref,
    )


def assert_task_runtime_identity(
    task_runtime_entries: list[tuple[str, str, Path]], phase_dir: Path
) -> None:
    _assert_task_runtime_identity(task_runtime_entries, phase_dir, load_json)


def assert_signoff_runtime_evidence_matrix(phase_dir: Path, registry: dict) -> None:
    _assert_signoff_runtime_evidence_matrix(
        phase_dir,
        registry,
        load_json,
        split_artifact_ref,
        active_entries,
        resolve_registry_path,
    )
