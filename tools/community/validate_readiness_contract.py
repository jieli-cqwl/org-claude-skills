#!/usr/bin/env python3
"""Semantic readiness checks that bind registry, task artifacts, and signoff."""

from __future__ import annotations

import re
from pathlib import Path

from authority_proof import load_yaml, verify_authority_proof
from manage_artifact_registry import get_active_revision
from normalize_canonical_artifact import ROOT, load_json
from write_user_decision import canonical_digest

CANONICAL_REF_RE = re.compile(r"^artifact://([^/]+)/([^@]+)@([^#]+)#(.+)$")
DIRECTOR_LOCK_ARTIFACTS = ("brief", "phase-prd")


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


def expected_registry_version(phase_dir: Path, artifact_type: str, payload: dict) -> str:
    if artifact_type == "plan":
        return str(payload.get("plan_version", ""))
    if artifact_type == "tasks":
        delivery_state = load_json(phase_dir / "delivery-state.json")
        return version_from_ref(str(delivery_state.get("active_tasks_version_ref", "")))
    return "v1"


def expected_registry_scope_ref(phase_dir: Path, artifact_type: str, payload: dict) -> str:
    if artifact_type in {"developer-report", "verify-result"}:
        delivery_state = load_json(phase_dir / "delivery-state.json")
        tasks_ref = str(delivery_state.get("active_tasks_version_ref", ""))
        task_id = str(payload.get("task_id", ""))
        artifact_type_ref, artifact_id, version, _anchor = split_artifact_ref(tasks_ref)
        if artifact_type_ref != "tasks" or not task_id:
            raise ValueError(f"cannot derive task scope_ref for {artifact_type}:{payload.get('artifact_id')}")
        return f"artifact://tasks/{artifact_id}@{version}#task-{task_id}"
    return phase_goal_ref(phase_dir)


def expected_active_artifact_keys(artifact_paths: list[Path]) -> set[tuple[str, str, Path]]:
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
            if entry.get("artifact_type") != artifact_type or entry.get("artifact_id") != artifact_id:
                continue
            if entry.get("lifecycle_state") != "FINALIZED":
                raise ValueError(f"readiness active artifact must be FINALIZED: {artifact_type}:{artifact_id}")
            expected_version = expected_registry_version(phase_dir, str(artifact_type), payload)
            if entry.get("version") != expected_version:
                raise ValueError(f"active registry entry version drift: {artifact_type}:{artifact_id}")
            expected_scope = expected_registry_scope_ref(phase_dir, str(artifact_type), payload)
            if entry.get("scope_ref") != expected_scope:
                raise ValueError(f"active registry entry scope_ref drift: {artifact_type}:{artifact_id}")
            resolved_path = resolve_registry_path(phase_dir, str(entry.get("artifact_path", "")))
            if resolved_path == artifact_path.resolve():
                matches.append(entry)
        if len(matches) != 1:
            raise ValueError(f"missing active registry binding: {artifact_type}:{artifact_id}")
        assert_registry_director_lock_digest(str(artifact_type), payload, matches[0])

        entry_payload = load_json(resolve_registry_path(phase_dir, matches[0]["artifact_path"]))
        if entry_payload.get("artifact_type") != artifact_type or entry_payload.get("artifact_id") != artifact_id:
            raise ValueError(f"active registry entry identity drift: {artifact_type}:{artifact_id}")

    for entry in entries:
        if entry.get("lifecycle_state") != "FINALIZED":
            raise ValueError(f"readiness active artifact must be FINALIZED: {entry.get('artifact_type')}:{entry.get('artifact_id')}")
        resolved_path = resolve_registry_path(phase_dir, str(entry.get("artifact_path", "")))
        if not resolved_path.is_file():
            raise FileNotFoundError(f"active registry artifact_path is not present: {entry.get('artifact_path')}")
        payload = load_json(resolved_path)
        entry_key = (str(entry.get("artifact_type", "")), str(entry.get("artifact_id", "")), resolved_path)
        if artifact_key(resolved_path, payload) != entry_key:
            raise ValueError(f"active registry entry identity drift: {entry.get('artifact_type')}:{entry.get('artifact_id')}")
        if entry.get("version") != expected_registry_version(phase_dir, str(entry.get("artifact_type", "")), payload):
            raise ValueError(f"active registry entry version drift: {entry.get('artifact_type')}:{entry.get('artifact_id')}")
        if entry.get("scope_ref") != expected_registry_scope_ref(phase_dir, str(entry.get("artifact_type", "")), payload):
            raise ValueError(f"active registry entry scope_ref drift: {entry.get('artifact_type')}:{entry.get('artifact_id')}")
        assert_registry_director_lock_digest(str(entry.get("artifact_type", "")), payload, entry)
        if entry_key not in expected_keys:
            raise ValueError(f"unexpected active registry entry outside readiness artifact set: {entry.get('artifact_type')}:{entry.get('artifact_id')}")


def assert_registry_director_lock_digest(artifact_type: str, payload: dict, entry: dict) -> None:
    if artifact_type not in DIRECTOR_LOCK_ARTIFACTS:
        return
    expected = director_lock_digest(payload, artifact_type)
    actual = str(entry.get("director_lock_digest", "")).strip()
    if not actual:
        raise ValueError(f"active registry entry missing director_lock_digest: {artifact_type}:{payload.get('artifact_id')}")
    if actual != expected:
        raise ValueError(f"active registry director_lock_digest drift: {artifact_type}:{payload.get('artifact_id')}")


def director_lock_digest(payload: dict, artifact_type: str) -> str:
    confirmation = payload.get("director_confirmation")
    if not isinstance(confirmation, dict):
        raise ValueError(f"director lock artifact missing director_confirmation: {artifact_type}:{payload.get('artifact_id')}")
    digest = str(confirmation.get("locked_field_digest", "")).strip()
    if not digest:
        raise ValueError(f"director lock artifact missing locked_field_digest: {artifact_type}:{payload.get('artifact_id')}")
    return digest


def assert_user_decision_director_lock_digests(phase_dir: Path, decision: dict) -> None:
    """Require user-approved signoff to anchor the Director lock digests."""

    actual = decision.get("director_lock_digests")
    if not isinstance(actual, dict):
        raise ValueError("user-decision director_lock_digests must be an object")
    expected = {
        "brief": director_lock_digest(load_json(phase_dir.parent / "brief.json"), "brief"),
        "phase-prd": director_lock_digest(load_json(phase_dir / "phase-prd.json"), "phase-prd"),
    }
    if set(actual.keys()) != set(expected.keys()):
        raise ValueError("user-decision director_lock_digests must exactly cover brief and phase-prd")
    for artifact_type, expected_digest in expected.items():
        actual_digest = str(actual.get(artifact_type, "")).strip()
        if actual_digest != expected_digest:
            raise ValueError(f"user-decision director_lock_digests drift: {artifact_type}")


def assert_task_runtime_identity(task_runtime_entries: list[tuple[str, str, Path]], phase_dir: Path) -> None:
    feature_dir = phase_dir.parent
    runtime_state = load_json(phase_dir / "delivery-state.json")
    tasks_registry = load_json(phase_dir / "tasks.json")
    brief = load_json(feature_dir / "brief.json")
    phase_prd = load_json(phase_dir / "phase-prd.json")
    tasks = tasks_registry.get("tasks", [])
    if not isinstance(tasks, list):
        raise ValueError("tasks.json tasks must be an array")
    expected_task_ids = [
        str(item.get("task_id"))
        for item in tasks
        if isinstance(item, dict) and item.get("task_id")
    ]
    if len(expected_task_ids) != len(set(expected_task_ids)):
        raise ValueError("tasks.json task_id entries must be unique")
    state_tasks = runtime_state.get("tasks", [])
    if not isinstance(state_tasks, list):
        raise ValueError("delivery-state tasks must be an array")
    state_task_ids = [
        str(item.get("task_id"))
        for item in state_tasks
        if isinstance(item, dict) and item.get("task_id")
    ]
    if len(state_task_ids) != len(set(state_task_ids)):
        raise ValueError("delivery-state task_id entries must be unique")
    task_statuses = {
        str(item.get("task_id")): str(item.get("runtime_status", ""))
        for item in state_tasks
        if isinstance(item, dict) and item.get("task_id")
    }
    if set(state_task_ids) != set(expected_task_ids):
        raise ValueError(
            "delivery-state tasks must exactly cover tasks.json task ids: "
            f"missing={sorted(set(expected_task_ids) - set(state_task_ids))} "
            f"extra={sorted(set(state_task_ids) - set(expected_task_ids))}"
        )
    expected_goal_refs = set(expected_signoff_goal_refs(brief, phase_prd))
    developer_report_refs: dict[str, str] = {}
    for artifact_type, task_id, runtime_path in task_runtime_entries:
        if artifact_type != "developer-report":
            continue
        payload = load_json(runtime_path)
        developer_report_refs[task_id] = (
            f"artifact://developer-report/{payload.get('artifact_id')}@v1#tdd-evidence-index"
        )

    for artifact_type, task_id, runtime_path in task_runtime_entries:
        payload = load_json(runtime_path)
        if payload.get("artifact_type") != artifact_type:
            raise ValueError(f"task runtime artifact_type drift: {runtime_path}")
        if payload.get("task_id") != task_id:
            raise ValueError(f"task runtime task_id drift: {runtime_path}")
        expected = f".task-{task_id}."
        if expected not in str(payload.get("artifact_id", "")):
            raise ValueError(f"task runtime artifact_id drift: {runtime_path}")
        if artifact_type == "developer-report":
            status = str(payload.get("runtime_status", ""))
            if status != "VERIFIED":
                raise ValueError(f"developer-report runtime_status must be VERIFIED at readiness: {runtime_path}")
            if task_statuses[task_id] != status:
                raise ValueError(f"developer-report runtime_status drift from delivery-state: {runtime_path}")
        if artifact_type == "verify-result":
            expected_report_ref = developer_report_refs.get(task_id)
            if not expected_report_ref:
                raise ValueError(f"verify-result missing matching developer-report for task: {task_id}")
            if payload.get("developer_report_ref") != expected_report_ref:
                raise ValueError(f"verify-result developer_report_ref drift from matching task developer-report: {runtime_path}")
            if payload.get("baseline_plan_version_ref") != runtime_state.get("active_plan_version_ref"):
                raise ValueError(f"verify-result baseline_plan_version_ref drift from active delivery-state: {runtime_path}")
            if payload.get("baseline_tasks_version_ref") != runtime_state.get("active_tasks_version_ref"):
                raise ValueError(f"verify-result baseline_tasks_version_ref drift from active delivery-state: {runtime_path}")
            if payload.get("gate_result") != "PASS":
                raise ValueError(f"verify-result gate_result must be PASS at readiness: {runtime_path}")
            verdicts = payload.get("phase_verdicts", {})
            expected_verdicts = {
                "spec_review": "SPEC_OK",
                "phase2a": "2A_OK",
                "phase2b": "2B_OK",
                "phase2c": "2C_OK",
            }
            for phase_name, expected_status in expected_verdicts.items():
                if verdicts.get(phase_name, {}).get("status") != expected_status:
                    raise ValueError(f"verify-result {phase_name}.status must be {expected_status}: {runtime_path}")
            for index, row in enumerate(payload.get("ac_verification", []), start=1):
                if row.get("status") != "PASS":
                    raise ValueError(f"verify-result ac_verification[{index}].status must be PASS: {runtime_path}")
            goal_closure = payload.get("goal_closure", [])
            if not isinstance(goal_closure, list) or not goal_closure:
                raise ValueError(f"verify-result goal_closure must be non-empty at readiness: {runtime_path}")
            has_met_goal = False
            for index, row in enumerate(goal_closure, start=1):
                if not isinstance(row, dict):
                    raise ValueError(f"verify-result goal_closure[{index}] must be an object: {runtime_path}")
                goal_ref = str(row.get("goal_ref", ""))
                if goal_ref not in expected_goal_refs:
                    raise ValueError(
                        f"verify-result goal_closure[{index}].goal_ref does not resolve to an upstream goal: {runtime_path}"
                    )
                if row.get("result") not in {"MET", "N_A"}:
                    raise ValueError(f"verify-result goal_closure[{index}].result must be MET or N_A: {runtime_path}")
                has_met_goal = has_met_goal or row.get("result") == "MET"
            if not has_met_goal:
                raise ValueError(f"verify-result goal_closure must contain at least one MET row at readiness: {runtime_path}")


def assert_code_review_pass(phase_dir: Path) -> None:
    review = load_json(phase_dir / "code-review-result.json")
    if review.get("gate_result") != "PASS":
        raise ValueError("code-review-result gate_result must be PASS at readiness")
    if review.get("review_conclusion") != "APPROVE":
        raise ValueError("code-review-result review_conclusion must be APPROVE at readiness")
    verdicts = review.get("dimension_verdicts")
    if not isinstance(verdicts, dict):
        raise ValueError("code-review-result dimension_verdicts must be an object")
    expected = {
        "review_a": "REVIEW_A_OK",
        "review_b": "REVIEW_B_OK",
        "review_c": "REVIEW_C_OK",
        "correctness": "OK",
        "safety": "OK",
        "error_handling": "OK",
        "concurrency_state": "OK",
        "design": "OK",
        "test_coverage": "OK",
        "backward_compatibility": "OK",
        "comment_accuracy": "OK",
        "performance": "OK",
        "observability": "OK",
    }
    for field, expected_value in expected.items():
        if verdicts.get(field) != expected_value:
            raise ValueError(f"code-review-result {field} must be {expected_value} at readiness")
    findings = review.get("findings", [])
    if not isinstance(findings, list):
        raise ValueError("code-review-result findings must be an array")
    blocking_severities = {"S0", "S1", "S2"}
    unresolved_statuses = {"Verified", "Inconclusive"}
    for index, finding in enumerate(findings, start=1):
        if not isinstance(finding, dict):
            raise ValueError(f"code-review-result findings[{index}] must be an object")
        if (
            finding.get("severity") in blocking_severities
            and finding.get("verification_status") in unresolved_statuses
        ):
            raise ValueError(
                "code-review-result contains unresolved blocking finding at readiness: "
                f"{finding.get('finding_id', index)}"
            )


def find_authority_proof(phase_dir: Path, proof_ref: str) -> dict:
    for proof_path in sorted((phase_dir / "evidence").glob("*.json")):
        proof = load_json(proof_path)
        if proof_ref in proof.get("proof_basis_refs", []):
            return proof
    raise FileNotFoundError(f"authority proof not found for {proof_ref}")


def assert_authority_proof(phase_dir: Path) -> None:
    decision = load_json(phase_dir / "user-decision.json")
    refs = decision.get("authority_proof_refs")
    if not isinstance(refs, list) or not refs:
        raise ValueError("user-decision authority_proof_refs must be non-empty")
    registry = load_yaml(ROOT / "contracts/canonical/authority-registry.yaml")
    runtime_state = load_json(phase_dir / "delivery-state.json")
    digest = canonical_digest(decision)
    if decision.get("decision_payload_digest") != digest:
        raise ValueError("user-decision decision_payload_digest must match canonical payload digest")
    assert_user_decision_director_lock_digests(phase_dir, decision)
    for index, proof_ref in enumerate(refs, start=1):
        proof = find_authority_proof(phase_dir, str(proof_ref))
        try:
            verify_authority_proof(proof, decision, digest, registry, runtime_state)
        except ValueError as exc:
            raise ValueError(f"user-decision authority_proof_refs[{index}] failed verification: {proof_ref}") from exc


def expected_signoff_goal_refs(brief: dict, phase_prd: dict) -> list[str]:
    """Map brief business_goals to their canonical signoff goal refs."""

    goals = brief.get("business_goals")
    if not isinstance(goals, list):
        raise ValueError("brief business_goals must be an array")
    artifact_id = str(brief.get("artifact_id", "")).strip()
    refs = [
        f"artifact://brief/{artifact_id}@v1#goal-{index:03d}"
        for index, _goal in enumerate(goals, start=1)
    ]
    acceptance_criteria = brief.get("acceptance_criteria", [])
    if isinstance(acceptance_criteria, list):
        refs.extend(
            f"artifact://brief/{artifact_id}@v1#ac-{index:03d}"
            for index, _criterion in enumerate(acceptance_criteria, start=1)
        )
    delivery_plan = brief.get("delivery_plan", [])
    if isinstance(delivery_plan, list):
        for item in delivery_plan:
            if isinstance(item, dict) and item.get("phase_id"):
                refs.append(f"artifact://brief/{artifact_id}@v1#delivery-plan-{item['phase_id']}")
    phase_artifact_id = str(phase_prd.get("artifact_id", "")).strip()
    if not phase_artifact_id:
        raise ValueError("phase-prd artifact_id must be non-empty")
    refs.append(f"artifact://phase-prd/{phase_artifact_id}@v1#phase-goal")
    return refs


def signoff_ref_anchor_index(feature_dir: Path, phase_dir: Path) -> dict[tuple[str, str, str], set[str]]:
    brief = load_json(feature_dir / "brief.json")
    phase_prd = load_json(phase_dir / "phase-prd.json")
    plan = load_json(phase_dir / "plan.json")
    tasks = load_json(phase_dir / "tasks.json")
    qa_result = load_json(phase_dir / "qa-result.json")
    code_review = load_json(phase_dir / "code-review-result.json")
    consistency_audit = load_json(phase_dir / "consistency-audit-result.json")
    signoff = load_json(phase_dir / "signoff-package.json")
    user_decision = load_json(phase_dir / "user-decision.json")
    index: dict[tuple[str, str, str], set[str]] = {
        ("brief", brief["artifact_id"], "v1"): {
            *[
                f"goal-{idx:03d}"
                for idx, _goal in enumerate(brief.get("business_goals", []), start=1)
            ],
            *[
                f"ac-{idx:03d}"
                for idx, _criterion in enumerate(brief.get("acceptance_criteria", []), start=1)
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
        ("tasks", tasks["artifact_id"], version_from_ref(load_json(phase_dir / "delivery-state.json")["active_tasks_version_ref"])): {
            "task-registry",
            *[f"task-{task['task_id']}" for task in tasks.get("tasks", []) if isinstance(task, dict) and task.get("task_id")],
        },
        ("qa-result", qa_result["artifact_id"], "v1"): {"release", "ac-trace", "gate-result", "issue-ledger"},
        ("code-review-result", code_review["artifact_id"], "v1"): {"round-1", "review-conclusion"},
        ("consistency-audit-result", consistency_audit["artifact_id"], "v1"): {"audit-root"},
        ("signoff-package", signoff["artifact_id"], "v1"): {
            "goal-closure",
            "release-recommendation",
            "waiver-risk",
        },
        ("user-decision", user_decision["artifact_id"], "v1"): {"accept-risk", "approve", "signoff-status"},
    }
    return index


def assert_ref_resolves(ref: str, anchor_index: dict[tuple[str, str, str], set[str]], label: str) -> None:
    artifact_type, artifact_id, version, anchor = split_artifact_ref(ref)
    anchors = anchor_index.get((artifact_type, artifact_id, version))
    if anchors is None or anchor not in anchors:
        raise ValueError(f"{label} does not resolve to a known canonical artifact anchor: {ref}")


def assert_signoff_closure(feature_dir: Path, phase_dir: Path) -> None:
    brief = load_json(feature_dir / "brief.json")
    phase_prd = load_json(phase_dir / "phase-prd.json")
    signoff = load_json(phase_dir / "signoff-package.json")
    decision = load_json(phase_dir / "user-decision.json")
    anchor_index = signoff_ref_anchor_index(feature_dir, phase_dir)

    closure = signoff.get("goal_closure")
    if not isinstance(closure, list) or not closure:
        raise ValueError("signoff-package goal_closure must be non-empty")
    source_refs = [
        str(item.get("goal_source_ref", ""))
        for item in closure
        if isinstance(item, dict)
    ]
    expected_refs = set(expected_signoff_goal_refs(brief, phase_prd))
    if len(source_refs) != len(expected_refs) or set(source_refs) != expected_refs:
        raise ValueError(
            "signoff-package goal_closure must exactly match upstream goal set: "
            f"missing={sorted(expected_refs - set(source_refs))} extra={sorted(set(source_refs) - expected_refs)}"
        )
    for goal_ref in sorted(expected_refs):
        if source_refs.count(goal_ref) != 1:
            raise ValueError(f"signoff-package goal_closure must cover each upstream goal exactly once: {goal_ref}")
    if any(item.get("result") == "NOT_MET" for item in closure if isinstance(item, dict)):
        raise ValueError("signoff-package goal_closure contains NOT_MET result")

    partial = [item for item in closure if isinstance(item, dict) and item.get("result") == "PARTIAL"]
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
        raise ValueError(f"signoff-package waiver scope_refs must target closed upstream goals: {sorted(unexpected_waiver_refs)}")
    for item in partial:
        source_ref = str(item.get("goal_source_ref", ""))
        if source_ref not in waiver_scope_refs:
            raise ValueError(f"PARTIAL goal closure requires waiver scope_ref for {source_ref}")
        if not str(item.get("remaining_gap_text", "")).strip():
            raise ValueError(f"PARTIAL goal closure requires remaining_gap_text for {source_ref}")
    for index, item in enumerate(closure, start=1):
        if not isinstance(item, dict):
            continue
        if item.get("goal_ref") != item.get("goal_source_ref"):
            raise ValueError(f"goal_closure[{index}].goal_ref must match goal_source_ref")
        assert_ref_resolves(str(item.get("goal_source_ref", "")), anchor_index, f"goal_closure[{index}].goal_source_ref")
        assert_ref_resolves(str(item.get("execution_basis_ref", "")), anchor_index, f"goal_closure[{index}].execution_basis_ref")
        assert_ref_resolves(str(item.get("evidence_ref", "")), anchor_index, f"goal_closure[{index}].evidence_ref")
    for index, ref in enumerate(signoff.get("decision_basis_refs", []), start=1):
        assert_ref_resolves(str(ref), anchor_index, f"decision_basis_refs[{index}]")
    for index, ref in enumerate(decision.get("decision_basis_refs", []), start=1):
        assert_ref_resolves(str(ref), anchor_index, f"user-decision decision_basis_refs[{index}]")
    for waiver_index, waiver in enumerate(waiver_entries or [], start=1):
        if not isinstance(waiver, dict):
            continue
        assert_ref_resolves(str(waiver.get("approved_by_ref", "")), anchor_index, f"waiver_entries[{waiver_index}].approved_by_ref")
        for ref_index, ref in enumerate(waiver.get("decision_basis_refs", []), start=1):
            assert_ref_resolves(str(ref), anchor_index, f"waiver_entries[{waiver_index}].decision_basis_refs[{ref_index}]")

    decision_value = decision.get("decision")
    if decision_value == "APPROVE" and decision.get("sign_off_status") != "SIGNED_OFF":
        raise ValueError("APPROVE decision requires sign_off_status=SIGNED_OFF")
    if decision_value == "ACCEPT_RISK" and decision.get("business_risk_acceptance_status") != "ACCEPTED":
        raise ValueError("ACCEPT_RISK decision requires business_risk_acceptance_status=ACCEPTED")
    if decision_value not in {"APPROVE", "ACCEPT_RISK"}:
        raise ValueError("readiness requires APPROVE or ACCEPT_RISK user decision")
    if signoff.get("current_stage") != "CLOSED":
        raise ValueError("signoff-package current_stage must be CLOSED at readiness")
    if signoff.get("sign_off_status") != decision.get("sign_off_status"):
        raise ValueError("signoff-package sign_off_status must match user-decision")
    if signoff.get("business_risk_acceptance_status") != decision.get("business_risk_acceptance_status"):
        raise ValueError("signoff-package business_risk_acceptance_status must match user-decision")
