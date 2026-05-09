from __future__ import annotations

from normalize_canonical_artifact import ROOT, load_json
from runtime_yaml import load_yaml

LEGACY_FIELD_DENYLIST = {
    "brief": {"non_functional_req"},
    "developer-report": {"deviation_triggers", "task_status"},
    "verify-result": {"acceptance_status", "issue_ledger", "task_status"},
    "tasks": {"coverage_matrix"},
    "signoff-package": {"kickoff_status", "release_alignment", "risk_acceptance_basis"},
}
PROCESS_LEAK_ARTIFACT_TYPES = {"tasks"}
PROCESS_LEAK_KEY_TOKENS = (
    "draft",
    "candidate",
    "unresolved",
    "intermediate",
    "recovered",
)
PROCESS_LEAK_VALUE_MARKERS = (
    "Draft Agent",
    "草稿 agent",
    "草稿agent",
    "候选字段",
    "未收敛多版本",
    "中间态痕迹",
    "RECOVERED",
)


def load_catalog() -> dict:
    return load_json(ROOT / "shared/runtime/standard-chain-catalog.json")


def load_stage_registry() -> dict:
    return load_yaml(ROOT / "contracts/canonical/stage-registry.yaml")


def load_compatibility_matrix() -> dict:
    return load_yaml(ROOT / "contracts/canonical/compatibility-matrix.yaml")


def build_transition_matrix(stage_registry: dict) -> dict[str, set[str]]:
    matrix: dict[str, set[str]] = {}
    for row in stage_registry.get("transitions", []):
        if not row.get("allowed"):
            continue
        matrix.setdefault(row["from"], set()).add(row["to"])
    return matrix


def assert_transition_allowed(
    current_stage: str,
    next_stage: str,
    matrix: dict[str, set[str]],
    stage_registry: dict,
) -> None:
    if current_stage in stage_registry.get("terminal_stages", []):
        raise ValueError(f"terminal stage cannot transition: {current_stage}")
    if next_stage == "BLOCKED":
        if "BLOCKED" not in matrix.get("NON_TERMINAL", set()):
            raise ValueError("BLOCKED transition not allowed by registry")
        return
    if next_stage == "REPLAN_PENDING":
        if "REPLAN_PENDING" not in matrix.get("NON_TERMINAL", set()):
            raise ValueError("REPLAN transition not allowed by registry")
        return
    if next_stage not in matrix.get(current_stage, set()):
        raise ValueError(f"illegal transition: {current_stage} -> {next_stage}")


def assert_producer_authority(artifact: dict, catalog: dict) -> None:
    entry = catalog.get("artifacts", {}).get(artifact.get("artifact_type"))
    if entry is None:
        raise ValueError(
            f"artifact type not registered: {artifact.get('artifact_type')}"
        )
    expected = entry.get("producer")
    if artifact.get("producer") != expected:
        raise ValueError(
            f"producer authority mismatch for {artifact['artifact_type']}: "
            f"{artifact.get('producer')} != {expected}"
        )


def assert_no_legacy_fields(artifact: dict) -> None:
    artifact_type = str(artifact.get("artifact_type", ""))
    denied = sorted(set(artifact) & LEGACY_FIELD_DENYLIST.get(artifact_type, set()))
    if denied:
        raise ValueError(f"{artifact_type} contains legacy fields: {denied}")


def assert_no_process_leakage(artifact: dict) -> None:
    artifact_type = str(artifact.get("artifact_type", ""))
    if artifact_type not in PROCESS_LEAK_ARTIFACT_TYPES:
        return

    leaks: list[str] = []

    def scan(value: object, path: str) -> None:
        if isinstance(value, dict):
            for key, child in value.items():
                key_path = f"{path}.{key}"
                normalized_key = str(key).replace("-", "_").lower()
                if any(token in normalized_key for token in PROCESS_LEAK_KEY_TOKENS):
                    leaks.append(key_path)
                scan(child, key_path)
            return
        if isinstance(value, list):
            for index, child in enumerate(value):
                scan(child, f"{path}[{index}]")
            return
        if isinstance(value, str) and any(
            marker in value for marker in PROCESS_LEAK_VALUE_MARKERS
        ):
            leaks.append(path)

    scan(artifact, "$")
    if leaks:
        raise ValueError(
            f"{artifact_type} contains draft/candidate process leakage: {sorted(set(leaks))}"
        )


def assert_chain_compatibility(artifacts: list[dict], compatibility: dict) -> None:
    pairs = {
        (artifact.get("chain_version"), artifact.get("chain_registry_digest"))
        for artifact in artifacts
    }
    if (
        compatibility.get("active_consumption", {}).get(
            "fail_close_on_multiple_digests"
        )
        and len(pairs) > 1
    ):
        raise ValueError(f"multiple active chain pairs: {sorted(pairs)}")


def assert_active_versions(artifact: dict, runtime_state: dict | None = None) -> None:
    artifact_type = artifact.get("artifact_type")
    if artifact_type in {
        "developer-report",
        "verify-result",
        "code-review-result",
        "qa-result",
        "delivery-state",
        "consistency-audit-result",
        "signoff-package",
        "user-decision",
    }:
        if not artifact.get("active_tasks_version_ref") or not artifact.get(
            "active_tasks_version_ref"
        ):
            raise ValueError(f"missing active refs for {artifact_type}")
    if artifact_type in {"signoff-package", "user-decision"}:
        if artifact.get("baseline_tasks_version_ref") != artifact.get(
            "active_tasks_version_ref"
        ):
            raise ValueError(f"baseline/active plan drift for {artifact_type}")
        if artifact.get("baseline_tasks_version_ref") != artifact.get(
            "active_tasks_version_ref"
        ):
            raise ValueError(f"baseline/active tasks drift for {artifact_type}")
    if artifact_type == "qa-result" and runtime_state is not None:
        if artifact.get("baseline_tasks_version_ref") != runtime_state.get(
            "active_tasks_version_ref"
        ):
            raise ValueError("qa-result baseline plan must match active runtime plan")
        if artifact.get("baseline_tasks_version_ref") != runtime_state.get(
            "active_tasks_version_ref"
        ):
            raise ValueError("qa-result baseline tasks must match active runtime tasks")


def is_superseded_verdict(artifact: dict) -> bool:
    return (
        artifact.get("sign_off_status") == "SUPERSEDED"
        or artifact.get("business_risk_acceptance_status") == "SUPERSEDED"
    )


def assert_signoff_baselines(payload: dict, runtime_state: dict | None) -> None:
    required = [
        "baseline_tasks_version_ref",
        "baseline_tasks_version_ref",
        "active_tasks_version_ref",
        "active_tasks_version_ref",
    ]
    for key in required:
        if not payload.get(key):
            raise ValueError(f"missing signoff field: {key}")
    if not is_superseded_verdict(payload):
        if payload["baseline_tasks_version_ref"] != payload["active_tasks_version_ref"]:
            raise ValueError("signoff baseline plan ref must equal active plan ref")
        if payload["baseline_tasks_version_ref"] != payload["active_tasks_version_ref"]:
            raise ValueError("signoff baseline tasks ref must equal active tasks ref")
    if runtime_state is not None and not is_superseded_verdict(payload):
        if (
            payload["active_tasks_version_ref"]
            != runtime_state["active_tasks_version_ref"]
        ):
            raise ValueError("signoff active plan baseline is stale")
        if (
            payload["active_tasks_version_ref"]
            != runtime_state["active_tasks_version_ref"]
        ):
            raise ValueError("signoff active tasks baseline is stale")


def assert_decision_baselines(payload: dict, runtime_state: dict | None) -> None:
    required = [
        "baseline_tasks_version_ref",
        "baseline_tasks_version_ref",
        "active_tasks_version_ref",
        "active_tasks_version_ref",
        "authority_proof_refs",
        "decision_basis_refs",
        "decision_payload_digest",
    ]
    for key in required:
        if not payload.get(key):
            raise ValueError(f"missing decision field: {key}")
    if payload.get("decision_source") == "SCRIPT":
        raise ValueError("SCRIPT cannot produce finalized user decision")
    if not is_superseded_verdict(payload):
        if payload["baseline_tasks_version_ref"] != payload["active_tasks_version_ref"]:
            raise ValueError("baseline plan ref must equal active plan ref")
        if payload["baseline_tasks_version_ref"] != payload["active_tasks_version_ref"]:
            raise ValueError("baseline tasks ref must equal active tasks ref")
    if runtime_state is not None and not is_superseded_verdict(payload):
        if (
            payload["active_tasks_version_ref"]
            != runtime_state["active_tasks_version_ref"]
        ):
            raise ValueError("decision active plan baseline is stale")
        if (
            payload["active_tasks_version_ref"]
            != runtime_state["active_tasks_version_ref"]
        ):
            raise ValueError("decision active tasks baseline is stale")


def assert_upstream_closure(closure: dict) -> None:
    if not closure:
        return

    def assert_exactly_once(
        required_refs: list[str], rows: list[dict], label: str
    ) -> None:
        seen = [row["source_ref"] for row in rows]
        if len(seen) != len(set(seen)):
            raise ValueError(f"duplicate {label} rows")
        missing = set(required_refs) - set(seen)
        extra = set(seen) - set(required_refs)
        if missing or extra:
            raise ValueError(
                f"{label} closure mismatch: missing={sorted(missing)} extra={sorted(extra)}"
            )

    goals = closure.get("goals", [])
    assert_exactly_once(goals, closure.get("goal_closure", []), "goal")

    constraints = closure.get("constraints", [])
    constraint_rows = set(closure.get("constraint_source_refs", []))
    constraint_na = {
        row["source_ref"]
        for row in closure.get("constraint_na", [])
        if row.get("reason_code")
    }
    if set(constraints) != constraint_rows | constraint_na:
        raise ValueError("constraint closure mismatch")

    obligations = set(closure.get("obligations", []))
    obligation_rows = set(closure.get("obligation_source_refs", []))
    if obligations != obligation_rows:
        raise ValueError("obligation closure mismatch")

    gates = set(closure.get("gate_rows", []))
    gate_consumption = set(closure.get("gate_consumption", []))
    if gates != gate_consumption:
        raise ValueError("gate closure mismatch")


def _require_non_empty_string(value: object, path: str) -> None:
    if not isinstance(value, str) or not value:
        raise ValueError(f"design contract missing non-empty string: {path}")


def _require_non_empty_list(value: object, path: str) -> list:
    if not isinstance(value, list) or not value:
        raise ValueError(f"design contract missing non-empty array: {path}")
    return value


def _require_string_list(value: object, path: str) -> list[str]:
    rows = _require_non_empty_list(value, path)
    if not all(isinstance(row, str) and row for row in rows):
        raise ValueError(f"contract requires non-empty string refs: {path}")
    return rows


def _require_non_empty_dict(value: object, path: str) -> dict:
    if not isinstance(value, dict) or not value:
        raise ValueError(f"design contract missing object: {path}")
    return value


def _first_artifact(artifacts: list[dict], artifact_type: str) -> dict:
    for artifact in artifacts:
        if artifact.get("artifact_type") == artifact_type:
            return artifact
    raise ValueError(f"design contract missing supporting artifact: {artifact_type}")


def _resolve_dotted_path(document: dict, anchor: str) -> object:
    import re

    current: object = document
    for raw_part in anchor.split("."):
        match = re.fullmatch(r"([A-Za-z_][A-Za-z0-9_]*)(?:\[(\d+)\])?", raw_part)
        if not match:
            raise ValueError(f"unsupported design source ref anchor: {anchor}")
        field, raw_index = match.groups()
        if not isinstance(current, dict) or field not in current:
            raise ValueError(f"design source ref does not resolve: {anchor}")
        current = current[field]
        if raw_index is not None:
            if not isinstance(current, list):
                raise ValueError(f"design source ref field is not an array: {anchor}")
            index = int(raw_index)
            if index >= len(current):
                raise ValueError(f"design source ref index out of range: {anchor}")
            current = current[index]
    return current
