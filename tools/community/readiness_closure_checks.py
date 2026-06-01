from __future__ import annotations

from pathlib import Path
from typing import Callable

LoadJson = Callable[[Path], dict]
SplitArtifactRef = Callable[[str], tuple[str, str, str, str]]
VersionFromRef = Callable[[str], str]


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
        if (
            delivery_state.get("commit_state") != "HANDOFF_PREPARED"
            or not delivery_state.get("commit_handoff_ref")
        ):
            raise ValueError(
                "READY_FOR_COMMIT requires commit_state=HANDOFF_PREPARED and commit_handoff_ref"
            )


def assert_target_change_signoff_freshness(phase_dir: Path, load_json: LoadJson) -> None:
    target_change_path = phase_dir / "target-change.json"
    if not target_change_path.is_file():
        return
    target_change = load_json(target_change_path)
    signoff = load_json(phase_dir / "signoff-package.json")
    invalidated_refs = {
        str(ref)
        for field in ("invalidates_refs", "superseded_evidence_refs")
        for ref in target_change.get(field, [])
        if str(ref).strip()
    }
    if not invalidated_refs:
        return
    matrix_refs = {
        str(row.get("artifact_ref", ""))
        for row in signoff.get("runtime_evidence_matrix", [])
        if isinstance(row, dict)
    }
    stale_refs = sorted(invalidated_refs & matrix_refs)
    if stale_refs:
        raise ValueError(
            "target-change superseded evidence remains in signoff-package.runtime_evidence_matrix: "
            + ", ".join(stale_refs)
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
        str(item.get("goal_ref", ""))
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
            raise ValueError(
                f"signoff-package goal_closure must cover each upstream goal exactly once: {goal_ref}"
            )
    if any(
        item.get("result") == "NOT_MET" for item in closure if isinstance(item, dict)
    ):
        raise ValueError("signoff-package goal_closure contains NOT_MET result")

    assert_partial_waivers(closure, signoff, expected_refs)
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
        and decision.get("business_risk_acceptance_status") != "ACCEPTED"
    ):
        raise ValueError(
            "ACCEPT_RISK decision requires business_risk_acceptance_status=ACCEPTED"
        )
    if decision_value not in {"APPROVE", "ACCEPT_RISK"}:
        raise ValueError("readiness requires APPROVE or ACCEPT_RISK user decision")
    if signoff.get("current_stage") != "CLOSED":
        raise ValueError("signoff-package current_stage must be CLOSED at readiness")
    if signoff.get("sign_off_status") != decision.get("sign_off_status"):
        raise ValueError("signoff-package sign_off_status must match user-decision")
    if signoff.get("business_risk_acceptance_status") != decision.get(
        "business_risk_acceptance_status"
    ):
        raise ValueError(
            "signoff-package business_risk_acceptance_status must match user-decision"
        )
