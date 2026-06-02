from __future__ import annotations

import re
from datetime import datetime
from pathlib import Path
from typing import Any, Callable

from runtime_yaml import load_yaml
from readiness_signoff_checks import SIGNOFF_RUNTIME_EVIDENCE_TYPES
from write_user_decision import canonical_digest

LoadJson = Callable[[Path], dict]
SplitArtifactRef = Callable[[str], tuple[str, str, str, str]]
VersionFromRef = Callable[[str], str]

CANONICAL_REF_RE = re.compile(r"^(artifact://[^#]+)#.+$")
FULL_CANONICAL_REF_RE = re.compile(r"^artifact://([^/]+)/([^@]+)@([^#]+)#(.+)$")
ROOT = Path(__file__).resolve().parents[2]
AUTHORITY_REGISTRY_PATH = ROOT / "contracts/canonical/authority-registry.yaml"
ALLOWED_TARGET_CHANGE_SOURCE = "authenticated-target-change"
RUNTIME_EVIDENCE_TYPES = SIGNOFF_RUNTIME_EVIDENCE_TYPES
NO_BLOCKER_VALUES = {"", "none", "n/a", "na", "null", "无"}
SIGNOFF_ALLOW_RECOMMENDATION = "ALLOW"
SIGNOFF_CONDITIONAL_RECOMMENDATION = "CONDITIONAL_ALLOW"
RISK_WAIVER_TYPES = {"RISK_ACCEPTANCE", "CONDITIONAL_RELEASE"}


def normalize_text(value: object) -> str:
    return str(value or "").strip()


def is_no_blocker_value(value: object) -> bool:
    text = normalize_text(value)
    return text.lower() in NO_BLOCKER_VALUES or text in NO_BLOCKER_VALUES


def parse_iso_datetime(value: object, label: str) -> datetime:
    text = normalize_text(value)
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        return datetime.fromisoformat(text)
    except ValueError as exc:
        raise ValueError(f"{label} must be an ISO date-time") from exc


def assert_waiver_contract(signoff: dict, decision: dict) -> None:
    waiver_entries = signoff.get("waiver_entries")
    rows = waiver_entries if isinstance(waiver_entries, list) else []
    if not rows:
        return
    observed_at = parse_iso_datetime(
        signoff.get("last_observed_at"), "signoff-package last_observed_at"
    )
    for index, waiver in enumerate(rows, start=1):
        if not isinstance(waiver, dict):
            continue
        expires_at = parse_iso_datetime(
            waiver.get("expires_at"), f"waiver_entries[{index}].expires_at"
        )
        try:
            expired = expires_at <= observed_at
        except TypeError as exc:
            raise ValueError(
                f"waiver_entries[{index}].expires_at timezone must match signoff-package last_observed_at"
            ) from exc
        if expired:
            raise ValueError(
                f"waiver_entries[{index}].expires_at must be after signoff-package last_observed_at"
            )
        if waiver.get("waiver_type") in RISK_WAIVER_TYPES and (
            signoff.get("business_risk_acceptance_status") != "ACCEPTED"
            or decision.get("business_risk_acceptance_status") != "ACCEPTED"
        ):
            raise ValueError(
                f"waiver_entries[{index}].waiver_type requires business_risk_acceptance_status=ACCEPTED"
            )


def assert_signoff_release_route(signoff: dict, decision: dict) -> None:
    recommendation = normalize_text(signoff.get("release_recommendation"))
    if recommendation == SIGNOFF_ALLOW_RECOMMENDATION:
        pass
    elif recommendation == SIGNOFF_CONDITIONAL_RECOMMENDATION:
        if signoff.get("business_risk_acceptance_status") != "ACCEPTED":
            raise ValueError(
                "signoff-package release_recommendation=CONDITIONAL_ALLOW requires business_risk_acceptance_status=ACCEPTED"
            )
        if decision.get("business_risk_acceptance_status") != "ACCEPTED":
            raise ValueError(
                "signoff-package release_recommendation=CONDITIONAL_ALLOW requires accepted user-decision risk status"
            )
        if not signoff.get("waiver_entries"):
            raise ValueError(
                "signoff-package release_recommendation=CONDITIONAL_ALLOW requires waiver_entries"
            )
    else:
        raise ValueError(
            f"signoff-package release_recommendation blocks closeout: {recommendation or '<missing>'}"
        )

    if not is_no_blocker_value(signoff.get("active_blocker")):
        raise ValueError("signoff-package active_blocker must be empty at closeout")
    if not is_no_blocker_value(signoff.get("blocker_owner")):
        raise ValueError("signoff-package blocker_owner must be empty at closeout")


def ref_identity(ref: str) -> str:
    match = CANONICAL_REF_RE.match(ref)
    if not match:
        return ref
    return match.group(1)


def split_canonical_ref(ref: str, label: str) -> tuple[str, str, str, str]:
    match = FULL_CANONICAL_REF_RE.match(ref)
    if not match:
        raise ValueError(f"{label} must be a canonical artifact ref: {ref}")
    return match.group(1), match.group(2), match.group(3), match.group(4)


def active_registry_entries(registry: dict) -> list[dict]:
    active_revision_id = str(registry.get("active_revision_id", "")).strip()
    for revision in registry.get("revisions", []):
        if (
            isinstance(revision, dict)
            and revision.get("revision_id") == active_revision_id
        ):
            return [
                entry
                for entry in revision.get("entries", [])
                if isinstance(entry, dict)
                and entry.get("active_for_consumption") is True
            ]
    raise ValueError("artifact-registry active revision is not resolvable")


def active_entry_ref_identity(entry: dict) -> str:
    artifact_type = str(entry.get("artifact_type", "")).strip()
    artifact_id = str(entry.get("artifact_id", "")).strip()
    version = str(entry.get("version", "")).strip()
    if not artifact_type or not artifact_id or not version:
        raise ValueError("artifact-registry active entry missing artifact identity")
    return f"artifact://{artifact_type}/{artifact_id}@{version}"


def full_artifact_ref(entry: dict, anchor: str) -> str:
    return f"{active_entry_ref_identity(entry)}#{anchor}"


def canonical_refs_in_value(value: Any) -> set[str]:
    if isinstance(value, str):
        return {value} if FULL_CANONICAL_REF_RE.match(value) else set()
    if isinstance(value, list):
        refs: set[str] = set()
        for item in value:
            refs.update(canonical_refs_in_value(item))
        return refs
    if isinstance(value, dict):
        refs: set[str] = set()
        for item in value.values():
            refs.update(canonical_refs_in_value(item))
        return refs
    return set()


def known_artifact_anchors(artifact_type: str, artifact: dict) -> set[str]:
    anchors: set[str] = set()
    if artifact_type == "brief":
        anchors.update(
            f"goal-{index:03d}"
            for index, _ in enumerate(artifact.get("business_goals", []), start=1)
        )
        anchors.update(
            f"ac-{index:03d}"
            for index, _ in enumerate(artifact.get("acceptance_criteria", []), start=1)
        )
        anchors.update(
            f"delivery-plan-{item['phase_id']}"
            for item in artifact.get("delivery_plan", [])
            if isinstance(item, dict) and item.get("phase_id")
        )
    elif artifact_type == "phase-prd":
        anchors.update({"phase-goal", "unit-index"})
    elif artifact_type == "unit-definition":
        anchors.update({"unit", "unit-1"})
        anchors.update(
            str(row.get("ac_id"))
            for row in artifact.get("acceptance_criteria", [])
            if isinstance(row, dict) and row.get("ac_id")
        )
    elif artifact_type == "design":
        anchors.update(
            {
                "key-decisions",
                "interfaces",
                "quality-attributes",
                "verification-mapping",
                "product-handoff",
                "risk-response",
            }
        )
    elif artifact_type == "test-cases":
        anchors.update(
            str(row.get("ac_id"))
            for row in artifact.get("ac_coverage_matrix", [])
            if isinstance(row, dict) and row.get("ac_id")
        )
        anchors.update(
            str(row.get("case_id"))
            for row in artifact.get("test_cases", [])
            if isinstance(row, dict) and row.get("case_id")
        )
        anchors.update(
            f"traceability_matrix:{index}"
            for index, row in enumerate(
                artifact.get("traceability_matrix", []), start=1
            )
            if isinstance(row, dict)
        )
        anchors.update(
            f"qa_handoff_contract:{row.get('obligation_id')}"
            for row in artifact.get("qa_handoff_contract", [])
            if isinstance(row, dict) and row.get("obligation_id")
        )
        anchors.update(
            f"cross_unit_obligations:{row.get('journey_id')}"
            for row in artifact.get("cross_unit_obligations", [])
            if isinstance(row, dict) and row.get("journey_id")
        )
    elif artifact_type == "plan":
        anchors.update(
            {
                "plan-version",
                "execution-basis-refs",
                "goal-source-refs",
                "constraint-source-refs",
                "obligation-source-refs",
            }
        )
    elif artifact_type == "tasks":
        anchors.add("task-registry")
        anchors.update(
            f"task-{task.get('task_id')}"
            for task in artifact.get("tasks", [])
            if isinstance(task, dict) and task.get("task_id")
        )
    elif artifact_type == "developer-report":
        anchors.update({"runtime-status", "tdd-evidence-index", "fresh-proof"})
    elif artifact_type == "verify-result":
        anchors.update({"verify-root", "gate-result", "goal-closure"})
    elif artifact_type == "qa-result":
        anchors.update(
            {"release", "ac-trace", "gate-result", "issue-ledger", "obligation_results"}
        )
    elif artifact_type == "code-review-result":
        anchors.update({"round-1", "review-conclusion"})
    elif artifact_type == "consistency-audit-result":
        anchors.add("audit-root")
    elif artifact_type == "signoff-package":
        anchors.update({"goal-closure", "release-recommendation", "waiver-risk"})
    elif artifact_type == "user-decision":
        anchors.update({"accept-risk", "approve", "signoff-status"})
    return anchors


def registry_known_refs(
    phase_dir: Path, registry: dict, load_json: LoadJson
) -> set[str]:
    refs: set[str] = set()
    for revision in registry.get("revisions", []):
        if not isinstance(revision, dict):
            continue
        for entry in revision.get("entries", []):
            if not isinstance(entry, dict):
                continue
            artifact_type = str(entry.get("artifact_type", "")).strip()
            artifact_path = str(entry.get("artifact_path", "")).strip()
            if not artifact_path:
                continue
            path = (phase_dir / artifact_path).resolve()
            if not path.is_file():
                continue
            artifact = load_json(path)
            for anchor in known_artifact_anchors(artifact_type, artifact):
                refs.add(full_artifact_ref(entry, anchor))
    return refs


def signoff_known_refs(signoff: dict) -> set[str]:
    refs: set[str] = set()
    for field in ("baseline_tasks_version_ref", "active_tasks_version_ref"):
        value = signoff.get(field)
        if isinstance(value, str) and value.strip():
            refs.add(value)
    refs.update(canonical_refs_in_value(signoff.get("decision_basis_refs", [])))
    for row in signoff.get("runtime_evidence_matrix", []):
        if not isinstance(row, dict):
            continue
        for field in ("artifact_ref", "freshness_basis_ref"):
            value = row.get(field)
            if isinstance(value, str) and value.strip():
                refs.add(value)
        proof = row.get("active_registry_proof")
        if isinstance(proof, dict):
            registry_ref = proof.get("registry_ref")
            if isinstance(registry_ref, str) and registry_ref.strip():
                refs.add(registry_ref)
    for row in signoff.get("goal_closure", []):
        if not isinstance(row, dict):
            continue
        for field in ("goal_ref", "execution_basis_ref", "evidence_ref"):
            value = row.get(field)
            if isinstance(value, str) and value.strip():
                refs.add(value)
    for waiver in signoff.get("waiver_entries", []):
        if not isinstance(waiver, dict):
            continue
        approved_by_ref = waiver.get("approved_by_ref")
        if isinstance(approved_by_ref, str) and approved_by_ref.strip():
            refs.add(approved_by_ref)
        refs.update(canonical_refs_in_value(waiver.get("scope_refs", [])))
        refs.update(canonical_refs_in_value(waiver.get("decision_basis_refs", [])))
    return refs


def assert_target_change_ref_resolves(
    field: str,
    ref: str,
    index: int,
    known_refs: set[str],
) -> None:
    if ref not in known_refs:
        raise ValueError(
            f"target-change {field}[{index}] does not resolve to registry or known evidence: {ref}"
        )


def find_authority_proof(phase_dir: Path, proof_ref: str, load_json: LoadJson) -> dict:
    split_canonical_ref(proof_ref, "target-change authority_proof_refs")
    if not proof_ref.startswith("artifact://evidence/"):
        raise ValueError(
            "target-change authority_proof_refs must point to evidence artifacts"
        )
    for proof_path in sorted((phase_dir / "evidence").glob("*.json")):
        proof = load_json(proof_path)
        if proof_ref in proof.get("proof_basis_refs", []):
            return proof
    raise FileNotFoundError(f"target-change authority proof not found for {proof_ref}")


def parse_datetime(value: object, label: str) -> datetime:
    try:
        return datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError as exc:
        raise ValueError(f"{label} must be a valid date-time") from exc


def finalized_authority_pairs() -> set[tuple[str, str]]:
    registry = load_yaml(AUTHORITY_REGISTRY_PATH)
    rules = registry.get("decision_source_rules", {})
    if not isinstance(rules, dict):
        raise ValueError("authority-registry decision_source_rules must be an object")
    pairs: set[tuple[str, str]] = set()
    for rule in rules.values():
        if not isinstance(rule, dict) or rule.get("finalized_allowed") is not True:
            continue
        proof_type = str(rule.get("required_proof_type", "")).strip()
        for channel in rule.get("allowed_channels", []):
            if proof_type and str(channel).strip():
                pairs.add((proof_type, str(channel).strip()))
    if not pairs:
        raise ValueError("authority-registry has no finalized authority proof pairs")
    return pairs


def assert_target_change_payload_binding(
    target_change: dict, proof: dict, index: int
) -> None:
    change_source = str(target_change.get("change_source", "")).strip()
    if change_source != ALLOWED_TARGET_CHANGE_SOURCE:
        raise ValueError(
            f"target-change change_source must be {ALLOWED_TARGET_CHANGE_SOURCE}"
        )
    expected_digest = canonical_digest(target_change)
    recorded_digest = str(target_change.get("target_change_payload_digest", "")).strip()
    if recorded_digest != expected_digest:
        raise ValueError(
            "target-change target_change_payload_digest does not match payload"
        )
    if str(proof.get("target_change_payload_digest", "")).strip() != expected_digest:
        raise ValueError(
            f"target-change authority_proof_refs[{index}] target_change_payload_digest does not match target-change"
        )


def assert_target_change_authority_proofs(
    phase_dir: Path, target_change: dict, load_json: LoadJson
) -> None:
    actor_id = str(target_change.get("actor_id", "")).strip()
    allowed_pairs = finalized_authority_pairs()
    target_change_at = parse_datetime(
        target_change.get("produced_at", ""), "target-change produced_at"
    )
    for index, proof_ref in enumerate(
        target_change.get("authority_proof_refs", []), start=1
    ):
        proof = find_authority_proof(phase_dir, str(proof_ref), load_json)
        if str(proof.get("verified_actor_id", "")).strip() != actor_id:
            raise ValueError(
                f"target-change authority_proof_refs[{index}] actor does not match actor_id"
            )
        for field in (
            "proof_type",
            "verified_channel",
            "verified_at",
            "verified_until",
        ):
            if not str(proof.get(field, "")).strip():
                raise ValueError(
                    f"target-change authority_proof_refs[{index}] proof missing {field}"
                )
        proof_pair = (
            str(proof.get("proof_type", "")).strip(),
            str(proof.get("verified_channel", "")).strip(),
        )
        if proof_pair not in allowed_pairs:
            raise ValueError(
                f"target-change authority_proof_refs[{index}] proof_type/channel is not finalized authority"
            )
        verified_at = parse_datetime(
            proof.get("verified_at", ""),
            f"target-change authority_proof_refs[{index}] verified_at",
        )
        verified_until = parse_datetime(
            proof.get("verified_until", ""),
            f"target-change authority_proof_refs[{index}] verified_until",
        )
        if target_change_at < verified_at or target_change_at > verified_until:
            raise ValueError(
                f"target-change authority_proof_refs[{index}] target-change produced_at outside proof validity window"
            )
        assert_target_change_payload_binding(target_change, proof, index)


def assert_target_change_fresh_proof_contract(
    phase_dir: Path,
    target_change: dict,
    registry: dict,
    invalidated_refs: set[str],
    signoff: dict,
    load_json: LoadJson,
) -> None:
    required_types = {
        str(item).strip()
        for item in target_change.get("required_fresh_proof_after_rebaseline", [])
        if str(item).strip()
    }
    runtime_types_in_signoff = {
        str(row.get("artifact_type", "")).strip()
        for row in signoff.get("runtime_evidence_matrix", [])
        if isinstance(row, dict)
        and str(row.get("artifact_type", "")).strip() in RUNTIME_EVIDENCE_TYPES
    }
    missing_runtime_types = sorted(runtime_types_in_signoff - required_types)
    if missing_runtime_types:
        raise ValueError(
            "target-change required_fresh_proof_after_rebaseline must include active runtime evidence artifacts: "
            + ", ".join(missing_runtime_types)
        )
    required_types.update(runtime_types_in_signoff)
    active_entries = active_registry_entries(registry)
    active_by_type: dict[str, list[dict]] = {}
    for entry in active_entries:
        artifact_type = str(entry.get("artifact_type", "")).strip()
        active_by_type.setdefault(artifact_type, []).append(entry)
    missing_types = sorted(
        artifact_type
        for artifact_type in required_types
        if artifact_type not in active_by_type
    )
    if missing_types:
        raise ValueError(
            "target-change required_fresh_proof_after_rebaseline missing active artifacts: "
            + ", ".join(missing_types)
        )
    target_change_at = parse_datetime(
        target_change.get("produced_at", ""), "target-change produced_at"
    )
    stale_produced_at: list[str] = []
    for artifact_type in required_types:
        for entry in active_by_type.get(artifact_type, []):
            artifact_path = str(entry.get("artifact_path", "")).strip()
            if not artifact_path:
                raise ValueError(
                    "target-change required fresh proof active artifact missing artifact_path"
                )
            artifact = load_json((phase_dir / artifact_path).resolve())
            produced_at = parse_datetime(
                artifact.get("produced_at", ""),
                f"target-change required fresh proof {artifact_type} produced_at",
            )
            if produced_at <= target_change_at:
                stale_produced_at.append(active_entry_ref_identity(entry))
    if stale_produced_at:
        raise ValueError(
            "target-change required fresh proof artifact is not newer than target-change: "
            + ", ".join(sorted(stale_produced_at))
        )
    invalidated_identities = {
        ref_identity(ref) for ref in invalidated_refs if str(ref).strip()
    }
    stale_active = sorted(
        identity
        for artifact_type in required_types
        for identity in {
            active_entry_ref_identity(entry)
            for entry in active_by_type.get(artifact_type, [])
        }
        if identity in invalidated_identities
    )
    if stale_active:
        raise ValueError(
            "target-change required fresh proof still points at invalidated active artifact: "
            + ", ".join(stale_active)
        )


def expected_signoff_goal_refs(brief: dict, phase_prd: dict) -> list[str]:
    goals = brief.get("business_goals")
    if not isinstance(goals, list):
        raise ValueError("brief business_goals must be an array")
    artifact_id = str(brief.get("artifact_id", "")).strip()
    refs = [
        f"artifact://brief/{artifact_id}@v1#goal-{index:03d}"
        for index, _ in enumerate(goals, start=1)
    ]
    acceptance_criteria = brief.get("acceptance_criteria", [])
    if isinstance(acceptance_criteria, list):
        refs.extend(
            f"artifact://brief/{artifact_id}@v1#ac-{index:03d}"
            for index, _ in enumerate(acceptance_criteria, start=1)
        )
    delivery_plan = brief.get("delivery_plan", [])
    if isinstance(delivery_plan, list):
        for item in delivery_plan:
            if isinstance(item, dict) and item.get("phase_id"):
                refs.append(
                    f"artifact://brief/{artifact_id}@v1#delivery-plan-{item['phase_id']}"
                )
    phase_artifact_id = str(phase_prd.get("artifact_id", "")).strip()
    if not phase_artifact_id:
        raise ValueError("phase-prd artifact_id must be non-empty")
    refs.append(f"artifact://phase-prd/{phase_artifact_id}@v1#phase-goal")
    return refs


def signoff_ref_anchor_index(
    feature_dir: Path,
    phase_dir: Path,
    load_json: LoadJson,
    version_from_ref: VersionFromRef,
) -> dict[tuple[str, str, str], set[str]]:
    brief = load_json(feature_dir / "brief.json")
    phase_prd = load_json(phase_dir / "phase-prd.json")
    plan = load_json(phase_dir / "plan.json")
    tasks = load_json(phase_dir / "tasks.json")
    qa_result = load_json(phase_dir / "qa-result.json")
    code_review = load_json(phase_dir / "code-review-result.json")
    consistency_audit = load_json(phase_dir / "consistency-audit-result.json")
    signoff = load_json(phase_dir / "signoff-package.json")
    user_decision = load_json(phase_dir / "user-decision.json")
    return {
        ("brief", brief["artifact_id"], "v1"): {
            *[
                f"goal-{idx:03d}"
                for idx, _ in enumerate(brief.get("business_goals", []), start=1)
            ],
            *[
                f"ac-{idx:03d}"
                for idx, _ in enumerate(brief.get("acceptance_criteria", []), start=1)
            ],
            *[
                f"delivery-plan-{item['phase_id']}"
                for item in brief.get("delivery_plan", [])
                if isinstance(item, dict) and item.get("phase_id")
            ],
        },
        ("phase-prd", phase_prd["artifact_id"], "v1"): {"phase-goal"},
        ("plan", plan["artifact_id"], str(plan.get("plan_version", ""))): {
            "plan-version",
            "execution-basis-refs",
            "goal-source-refs",
            "constraint-source-refs",
            "obligation-source-refs",
        },
        (
            "tasks",
            tasks["artifact_id"],
            version_from_ref(
                load_json(phase_dir / "delivery-state.json")["active_tasks_version_ref"]
            ),
        ): {
            "task-registry",
            *[
                f"task-{task['task_id']}"
                for task in tasks.get("tasks", [])
                if isinstance(task, dict) and task.get("task_id")
            ],
        },
        ("qa-result", qa_result["artifact_id"], "v1"): {
            "release",
            "ac-trace",
            "gate-result",
            "issue-ledger",
        },
        ("code-review-result", code_review["artifact_id"], "v1"): {
            "round-1",
            "review-conclusion",
        },
        ("consistency-audit-result", consistency_audit["artifact_id"], "v1"): {
            "audit-root"
        },
        ("signoff-package", signoff["artifact_id"], "v1"): {
            "goal-closure",
            "release-recommendation",
            "waiver-risk",
        },
        ("user-decision", user_decision["artifact_id"], "v1"): {
            "accept-risk",
            "approve",
            "signoff-status",
        },
    }


def assert_ref_resolves(
    ref: str,
    anchor_index: dict[tuple[str, str, str], set[str]],
    label: str,
    split_artifact_ref: SplitArtifactRef,
) -> None:
    artifact_type, artifact_id, version, anchor = split_artifact_ref(ref)
    anchors = anchor_index.get((artifact_type, artifact_id, version))
    if anchors is None or anchor not in anchors:
        raise ValueError(
            f"{label} does not resolve to a known canonical artifact anchor: {ref}"
        )


def assert_goal_closure_refs(
    closure: list,
    anchor_index: dict[tuple[str, str, str], set[str]],
    split_artifact_ref: SplitArtifactRef,
) -> None:
    for index, item in enumerate(closure, start=1):
        if not isinstance(item, dict):
            continue
        assert_ref_resolves(
            str(item.get("goal_ref", "")),
            anchor_index,
            f"goal_closure[{index}].goal_ref",
            split_artifact_ref,
        )
        assert_ref_resolves(
            str(item.get("execution_basis_ref", "")),
            anchor_index,
            f"goal_closure[{index}].execution_basis_ref",
            split_artifact_ref,
        )
        assert_ref_resolves(
            str(item.get("evidence_ref", "")),
            anchor_index,
            f"goal_closure[{index}].evidence_ref",
            split_artifact_ref,
        )


def assert_waiver_refs(
    waiver_entries: object,
    anchor_index: dict[tuple[str, str, str], set[str]],
    split_artifact_ref: SplitArtifactRef,
) -> None:
    rows = waiver_entries if isinstance(waiver_entries, list) else []
    for waiver_index, waiver in enumerate(rows, start=1):
        if not isinstance(waiver, dict):
            continue
        assert_ref_resolves(
            str(waiver.get("approved_by_ref", "")),
            anchor_index,
            f"waiver_entries[{waiver_index}].approved_by_ref",
            split_artifact_ref,
        )
        for ref_index, ref in enumerate(waiver.get("decision_basis_refs", []), start=1):
            assert_ref_resolves(
                str(ref),
                anchor_index,
                f"waiver_entries[{waiver_index}].decision_basis_refs[{ref_index}]",
                split_artifact_ref,
            )


def assert_partial_waivers(
    closure: list, signoff: dict, expected_refs: set[str]
) -> None:
    partial = [
        item
        for item in closure
        if isinstance(item, dict) and item.get("result") == "PARTIAL"
    ]
    waiver_entries = signoff.get("waiver_entries")
    if partial and not waiver_entries:
        raise ValueError("PARTIAL goal closure requires explicit waiver_entries")
    waiver_scope_refs = {
        str(scope_ref)
        for waiver in waiver_entries or []
        if isinstance(waiver, dict)
        for scope_ref in waiver.get("scope_refs", [])
    }
    unexpected_waiver_refs = waiver_scope_refs - expected_refs
    if unexpected_waiver_refs:
        raise ValueError(
            f"signoff-package waiver scope_refs must target closed upstream goals: {sorted(unexpected_waiver_refs)}"
        )
    for item in partial:
        source_ref = str(item.get("goal_ref", ""))
        if source_ref not in waiver_scope_refs:
            raise ValueError(
                f"PARTIAL goal closure requires waiver scope_ref for {source_ref}"
            )
        if not str(item.get("remaining_gap_text", "")).strip():
            raise ValueError(
                f"PARTIAL goal closure requires remaining_gap_text for {source_ref}"
            )


def assert_delivery_state_closeout(phase_dir: Path, load_json: LoadJson) -> None:
    delivery_state = load_json(phase_dir / "delivery-state.json")
    status = delivery_state.get("status")
    if status == "DELIVERED":
        if delivery_state.get("commit_state") != "COMMIT_RESULT_RECORDED":
            raise ValueError(
                "DELIVERED requires commit_result_ref or equivalent_delivery_result_ref"
            )
        if not (
            delivery_state.get("commit_result_ref")
            or delivery_state.get("equivalent_delivery_result_ref")
        ):
            raise ValueError(
                "DELIVERED requires commit_result_ref or equivalent_delivery_result_ref"
            )
    if status == "READY_FOR_COMMIT":
        if delivery_state.get(
            "commit_state"
        ) != "HANDOFF_PREPARED" or not delivery_state.get("commit_handoff_ref"):
            raise ValueError(
                "READY_FOR_COMMIT requires commit_state=HANDOFF_PREPARED and commit_handoff_ref"
            )


def assert_target_change_signoff_freshness(
    phase_dir: Path, load_json: LoadJson
) -> None:
    target_change_path = phase_dir / "target-change.json"
    if not target_change_path.is_file():
        return
    target_change = load_json(target_change_path)
    signoff = load_json(phase_dir / "signoff-package.json")
    delivery_state = load_json(phase_dir / "delivery-state.json")
    registry = load_json(phase_dir / "artifact-registry.json")
    active_tasks_ref = str(delivery_state.get("active_tasks_version_ref", "")).strip()
    if not active_tasks_ref:
        raise ValueError(
            "delivery-state active_tasks_version_ref is required for target-change"
        )
    if (
        str(target_change.get("active_tasks_version_ref", "")).strip()
        != active_tasks_ref
    ):
        raise ValueError(
            "target-change active_tasks_version_ref must match delivery-state active_tasks_version_ref"
        )
    baseline_tasks_ref = str(
        target_change.get("baseline_tasks_version_ref", "")
    ).strip()
    split_canonical_ref(baseline_tasks_ref, "target-change baseline_tasks_version_ref")
    if not baseline_tasks_ref.startswith("artifact://tasks/"):
        raise ValueError(
            "target-change baseline_tasks_version_ref must point to a tasks artifact"
        )
    if ref_identity(baseline_tasks_ref) == ref_identity(active_tasks_ref):
        raise ValueError(
            "target-change baseline_tasks_version_ref must point to the invalidated prior tasks baseline"
        )
    required_nonempty_ref_fields = (
        "affected_refs",
        "invalidates_refs",
        "superseded_evidence_refs",
        "authority_proof_refs",
        "decision_basis_refs",
    )
    for field in required_nonempty_ref_fields:
        refs = target_change.get(field)
        if not isinstance(refs, list) or not any(str(ref).strip() for ref in refs):
            raise ValueError(f"target-change {field} must be non-empty")
        for index, ref in enumerate(refs, start=1):
            split_canonical_ref(str(ref), f"target-change {field}[{index}]")
    proofs = target_change.get("required_fresh_proof_after_rebaseline")
    if not isinstance(proofs, list) or not any(str(item).strip() for item in proofs):
        raise ValueError(
            "target-change required_fresh_proof_after_rebaseline must be non-empty"
        )
    if str(target_change.get("rebaseline_owner", "")).strip() == "":
        raise ValueError("target-change rebaseline_owner must be non-empty")
    assert_target_change_authority_proofs(phase_dir, target_change, load_json)
    invalidated_refs = {
        str(ref)
        for field in ("invalidates_refs", "superseded_evidence_refs")
        for ref in target_change.get(field, [])
        if str(ref).strip()
    }
    if baseline_tasks_ref not in invalidated_refs:
        raise ValueError(
            "target-change baseline_tasks_version_ref must be included in invalidates_refs or superseded_evidence_refs"
        )
    known_refs = registry_known_refs(
        phase_dir, registry, load_json
    ) | signoff_known_refs(signoff)
    for field in (
        "affected_refs",
        "invalidates_refs",
        "superseded_evidence_refs",
        "decision_basis_refs",
    ):
        for index, ref in enumerate(target_change.get(field, []), start=1):
            assert_target_change_ref_resolves(
                field,
                str(ref),
                index,
                known_refs,
            )
    if not invalidated_refs:
        return
    matrix_refs = {
        str(row.get("artifact_ref", ""))
        for row in signoff.get("runtime_evidence_matrix", [])
        if isinstance(row, dict)
    }
    freshness_refs = {
        str(row.get("freshness_basis_ref", ""))
        for row in signoff.get("runtime_evidence_matrix", [])
        if isinstance(row, dict)
    }
    matrix_identities = {ref_identity(ref) for ref in matrix_refs if ref.strip()}
    stale_refs = sorted(
        {
            ref
            for ref in invalidated_refs
            if ref in matrix_refs
            or ref in freshness_refs
            or ref_identity(ref) in matrix_identities
        }
    )
    if stale_refs:
        raise ValueError(
            "target-change superseded evidence remains in signoff-package.runtime_evidence_matrix: "
            + ", ".join(stale_refs)
        )
    assert_target_change_fresh_proof_contract(
        phase_dir, target_change, registry, invalidated_refs, signoff, load_json
    )


def assert_signoff_closure(
    feature_dir: Path,
    phase_dir: Path,
    load_json: LoadJson,
    version_from_ref: VersionFromRef,
    split_artifact_ref: SplitArtifactRef,
) -> None:
    brief = load_json(feature_dir / "brief.json")
    phase_prd = load_json(phase_dir / "phase-prd.json")
    signoff = load_json(phase_dir / "signoff-package.json")
    decision = load_json(phase_dir / "user-decision.json")
    anchor_index = signoff_ref_anchor_index(
        feature_dir, phase_dir, load_json, version_from_ref
    )

    closure = signoff.get("goal_closure")
    if not isinstance(closure, list) or not closure:
        raise ValueError("signoff-package goal_closure must be non-empty")
    source_refs = [
        str(item.get("goal_ref", "")) for item in closure if isinstance(item, dict)
    ]
    expected_refs = set(expected_signoff_goal_refs(brief, phase_prd))
    if len(source_refs) != len(expected_refs) or set(source_refs) != expected_refs:
        raise ValueError(
            "signoff-package goal_closure must exactly match upstream goal set: "
            f"missing={sorted(expected_refs - set(source_refs))} extra={sorted(set(source_refs) - expected_refs)}"
        )
    for goal_ref in sorted(expected_refs):
        if source_refs.count(goal_ref) != 1:
            raise ValueError(
                f"signoff-package goal_closure must cover each upstream goal exactly once: {goal_ref}"
            )
    if any(
        item.get("result") == "NOT_MET" for item in closure if isinstance(item, dict)
    ):
        raise ValueError("signoff-package goal_closure contains NOT_MET result")

    assert_partial_waivers(closure, signoff, expected_refs)
    assert_waiver_contract(signoff, decision)
    assert_goal_closure_refs(closure, anchor_index, split_artifact_ref)
    for index, ref in enumerate(signoff.get("decision_basis_refs", []), start=1):
        assert_ref_resolves(
            str(ref), anchor_index, f"decision_basis_refs[{index}]", split_artifact_ref
        )
    for index, ref in enumerate(decision.get("decision_basis_refs", []), start=1):
        assert_ref_resolves(
            str(ref),
            anchor_index,
            f"user-decision decision_basis_refs[{index}]",
            split_artifact_ref,
        )
    assert_waiver_refs(signoff.get("waiver_entries"), anchor_index, split_artifact_ref)

    decision_value = decision.get("decision")
    if decision_value == "APPROVE" and decision.get("sign_off_status") != "SIGNED_OFF":
        raise ValueError("APPROVE decision requires sign_off_status=SIGNED_OFF")
    if (
        decision_value == "ACCEPT_RISK"
        and decision.get("sign_off_status") != "SIGNED_OFF"
    ):
        raise ValueError("ACCEPT_RISK decision requires sign_off_status=SIGNED_OFF")
    if (
        decision_value == "ACCEPT_RISK"
        and decision.get("business_risk_acceptance_status") != "ACCEPTED"
    ):
        raise ValueError(
            "ACCEPT_RISK decision requires business_risk_acceptance_status=ACCEPTED"
        )
    if decision_value not in {"APPROVE", "ACCEPT_RISK"}:
        raise ValueError("readiness requires APPROVE or ACCEPT_RISK user decision")
    assert_signoff_release_route(signoff, decision)
    if signoff.get("current_stage") != "CLOSED":
        raise ValueError("signoff-package current_stage must be CLOSED at readiness")
    if signoff.get("sign_off_status") != "SIGNED_OFF":
        raise ValueError("signoff-package sign_off_status must be SIGNED_OFF")
    if signoff.get("sign_off_status") != decision.get("sign_off_status"):
        raise ValueError("signoff-package sign_off_status must match user-decision")
    if signoff.get("business_risk_acceptance_status") != decision.get(
        "business_risk_acceptance_status"
    ):
        raise ValueError(
            "signoff-package business_risk_acceptance_status must match user-decision"
        )
