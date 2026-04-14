#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

BUNDLE="$ROOT/contracts/canonical/registry-bundle.yaml"
CATALOG="$ROOT/shared/runtime/standard-chain-catalog.json"
BUILDER="$ROOT/tools/community/build_standard_chain_catalog.py"
SHARED_CORE="$ROOT/contracts/canonical/schemas/shared-core.schema.json"

for path in "$BUNDLE" "$CATALOG" "$BUILDER" "$SHARED_CORE"; do
  [ -f "$path" ] || fail "missing required foundation file: ${path#"$ROOT"/}"
done

python3 "$BUILDER" --check || fail "standard chain catalog drift"
python3 "$BUILDER" --bundle-drift-probe contracts/canonical/registry-bundle.yaml \
  || fail "bundle drift must invalidate digest"

python3 - "$ROOT" <<'PY' || fail "standard chain foundation registry invalid"
import json
import sys
import tempfile
from copy import deepcopy
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator, ValidationError
from referencing import Registry, Resource


ROOT = Path(sys.argv[1])
REQUIRED_ARTIFACTS = {
    "brief",
    "phase-prd",
    "unit-definition",
    "design",
    "test-cases",
    "plan",
    "tasks",
    "developer-report",
    "verify-result",
    "code-review-result",
    "qa-result",
    "delivery-state",
    "signoff-package",
    "user-decision",
    "artifact-registry",
    "projection-manifest",
}
REQUIRED_BUNDLE = {
    "chain_version": "standard-chain/v1",
    "vocabulary_registry": "contracts/canonical/vocabulary-registry.yaml",
    "authority_registry": "contracts/canonical/authority-registry.yaml",
    "stage_registry": "contracts/canonical/stage-registry.yaml",
    "compatibility_matrix": "contracts/canonical/compatibility-matrix.yaml",
}
REQUIRED_VOCAB = {
    "status": ["PENDING", "IN_PROGRESS", "PASS", "FAIL", "BLOCKED", "N_A", "CLOSED"],
    "gate_result": ["PASS", "FAIL", "CONDITIONAL", "NOT_RUN", "N_A"],
    "release_recommendation": ["ALLOW", "CONDITIONAL_ALLOW", "BLOCK", "DEFER"],
    "control_action": ["CONTINUE", "ESCALATE", "REPLAN", "BLOCK", "REQUEST_DECISION", "CLOSE"],
    "decision": ["APPROVE", "REJECT", "ACCEPT_RISK", "REQUEST_CHANGES", "ACKNOWLEDGED"],
    "severity": ["S0", "S1", "S2", "S3"],
    "priority": ["P0", "P1", "P2", "P3"],
    "runtime_status": ["PENDING", "READY", "IN_PROGRESS", "BLOCKED", "VERIFIED", "FAILED", "CLOSED"],
    "sign_off_status": ["PENDING", "SIGNED_OFF", "REJECTED", "SUPERSEDED"],
    "business_risk_acceptance_status": ["NOT_REQUIRED", "PENDING", "ACCEPTED", "REJECTED", "SUPERSEDED"],
    "goal_closure_result": ["MET", "PARTIAL", "NOT_MET", "N_A"],
}
REQUIRED_STAGES = [
    "PLANNING",
    "TASK_DISPATCH",
    "TASK_EXECUTION",
    "TASK_VERIFICATION",
    "PHASE_REVIEW",
    "PHASE_QA",
    "SIGNOFF_PENDING",
    "SIGNOFF_RECORDED",
    "CLOSED",
    "BLOCKED",
    "REPLAN_PENDING",
]
REQUIRED_TRANSITIONS = {
    ("PLANNING", "TASK_DISPATCH"),
    ("TASK_DISPATCH", "TASK_EXECUTION"),
    ("TASK_EXECUTION", "TASK_VERIFICATION"),
    ("TASK_VERIFICATION", "TASK_EXECUTION"),
    ("TASK_VERIFICATION", "PHASE_REVIEW"),
    ("PHASE_REVIEW", "TASK_EXECUTION"),
    ("PHASE_REVIEW", "PHASE_QA"),
    ("PHASE_QA", "TASK_EXECUTION"),
    ("PHASE_QA", "SIGNOFF_PENDING"),
    ("SIGNOFF_PENDING", "SIGNOFF_RECORDED"),
    ("SIGNOFF_RECORDED", "CLOSED"),
    ("BLOCKED", "RESUME_STAGE"),
    ("REPLAN_PENDING", "PLANNING"),
    ("NON_TERMINAL", "BLOCKED"),
    ("NON_TERMINAL", "REPLAN_PENDING"),
}
TASK_SCOPE_PATHS = {
    "developer-report": "docs/{feature}/phase-{N}/unit-{N}/tasks/{task_id}/developer-report.json",
    "verify-result": "docs/{feature}/phase-{N}/unit-{N}/tasks/{task_id}/verify-result.json",
}


def load_yaml(rel_path: str) -> dict:
    return yaml.safe_load((ROOT / rel_path).read_text(encoding="utf-8"))


def load_json(rel_path: str) -> dict:
    return json.loads((ROOT / rel_path).read_text(encoding="utf-8"))


def ensure(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


bundle = load_yaml("contracts/canonical/registry-bundle.yaml")
ensure(bundle == REQUIRED_BUNDLE, f"unexpected registry bundle: {bundle}")

vocab = load_yaml(bundle["vocabulary_registry"])
for name, expected_values in REQUIRED_VOCAB.items():
    ensure(vocab.get(name) == expected_values, f"vocabulary mismatch for {name}: {vocab.get(name)}")

authority = load_yaml(bundle["authority_registry"])
ensure(authority.get("authority_scope") == ["artifact", "field", "phase", "signoff"], "authority_scope registry mismatch")
ensure(authority.get("actor_type") == ["USER", "AGENT", "SYSTEM", "TOOLING"], "actor_type registry mismatch")
ensure(authority.get("decision_source") == ["CLI", "SCRIPT", "HTML_FORM", "API", "MANUAL_IMPORT"], "decision_source registry mismatch")
ensure(
    authority.get("proof_type") == ["AUTHENTICATED_CLI_SESSION", "SIGNED_RECEIPT", "HUMAN_CONFIRMED_IMPORT"],
    "proof_type registry mismatch",
)
field_path_grammar = authority.get("field_path_grammar", {})
ensure(field_path_grammar.get("root") == "$", "field path grammar root mismatch")
ensure(
    field_path_grammar.get("pattern") == r"^\$(?:\.[A-Za-z_][A-Za-z0-9_-]*|\[\*\])*$",
    "field path grammar pattern mismatch",
)
policy = authority.get("v1_user_decision_policy", {})
ensure(policy.get("allowed_final_sources") == ["CLI", "MANUAL_IMPORT"], "v1 final decision sources mismatch")
ensure(policy.get("internal_only_sources") == ["SCRIPT"], "v1 internal-only decision sources mismatch")

stage_registry = load_yaml(bundle["stage_registry"])
ensure(stage_registry.get("stages") == REQUIRED_STAGES, "stage registry mismatch")
ensure(stage_registry.get("terminal_stages") == ["CLOSED"], "terminal stages mismatch")
ensure(stage_registry.get("externally_resumable_stages") == ["BLOCKED"], "externally resumable stages mismatch")
transition_pairs = {
    (entry.get("from"), entry.get("to"))
    for entry in stage_registry.get("transitions", [])
    if entry.get("allowed") is True
}
ensure(transition_pairs == REQUIRED_TRANSITIONS, f"transition matrix mismatch: {sorted(transition_pairs)}")

compatibility = load_yaml(bundle["compatibility_matrix"])
ensure(compatibility.get("chain_version") == bundle["chain_version"], "compatibility matrix chain version mismatch")
ensure(
    compatibility.get("active_consumption", {}).get("required_pair") == ["chain_version", "chain_registry_digest"],
    "compatibility matrix must require chain_version + chain_registry_digest",
)
ensure(
    compatibility.get("active_consumption", {}).get("fail_close_on_multiple_digests") is True,
    "compatibility matrix must fail-close on multiple digests",
)
ensure(
    compatibility.get("user_decision_finalization", {}).get("allowed_sources") == ["CLI", "MANUAL_IMPORT"],
    "compatibility matrix final decision sources mismatch",
)

with tempfile.TemporaryDirectory() as temp_dir:
    temp_root = Path(temp_dir) / "repo"
    temp_root.mkdir(parents=True, exist_ok=True)
    reordered_bundle = {
        "compatibility_matrix": bundle["compatibility_matrix"],
        "stage_registry": bundle["stage_registry"],
        "authority_registry": bundle["authority_registry"],
        "vocabulary_registry": bundle["vocabulary_registry"],
        "chain_version": bundle["chain_version"],
    }
    (temp_root / "contracts/canonical").mkdir(parents=True, exist_ok=True)
    temp_bundle_path = temp_root / "contracts/canonical/registry-bundle.yaml"
    temp_bundle_path.write_text(yaml.safe_dump(reordered_bundle, sort_keys=False), encoding="utf-8")
    from tools.community.build_standard_chain_catalog import load_registry_bundle
    loaded = load_registry_bundle(temp_root)
    ensure(loaded["bundle"] == REQUIRED_BUNDLE, "bundle loader should ignore YAML key order")

catalog = load_json("shared/runtime/standard-chain-catalog.json")
ensure(catalog.get("chain_version") == bundle["chain_version"], "catalog chain version mismatch")
ensure(isinstance(catalog.get("chain_registry_digest"), str) and catalog["chain_registry_digest"], "missing catalog digest")

artifacts = catalog.get("artifacts")
ensure(set(artifacts) == REQUIRED_ARTIFACTS, f"catalog artifacts mismatch: {sorted(artifacts)}")

shared_core_schema = load_json("contracts/canonical/schemas/shared-core.schema.json")
schema_registry = Registry().with_resource(
    shared_core_schema["$id"],
    Resource.from_contents(shared_core_schema),
)

digests = {catalog["chain_registry_digest"]}
for artifact_type, entry in artifacts.items():
    for key in ("schema_path", "template_path", "scope", "default_path", "chain_version", "chain_registry_digest"):
        ensure(entry.get(key), f"{artifact_type}: missing {key}")

    ensure(entry["chain_version"] == bundle["chain_version"], f"{artifact_type}: chain version drift")
    digests.add(entry["chain_registry_digest"])

    schema_path = ROOT / entry["schema_path"]
    template_path = ROOT / entry["template_path"]
    ensure(schema_path.is_file(), f"{artifact_type}: missing schema {entry['schema_path']}")
    ensure(template_path.is_file(), f"{artifact_type}: missing template {entry['template_path']}")

    schema = load_json(entry["schema_path"])
    schema_registry = schema_registry.with_resource(schema["$id"], Resource.from_contents(schema))
    refs = []

    def collect_refs(value: object) -> None:
        if isinstance(value, dict):
            ref = value.get("$ref")
            if isinstance(ref, str):
                refs.append(ref)
            for nested in value.values():
                collect_refs(nested)
        elif isinstance(value, list):
            for nested in value:
                collect_refs(nested)

    collect_refs(schema)
    ensure(any("shared-core.schema.json" in ref for ref in refs), f"{artifact_type}: schema must inherit shared core")

    template = load_json(entry["template_path"])
    Draft202012Validator(schema, registry=schema_registry).validate(template)
    ensure(template.get("artifact_type") == artifact_type, f"{artifact_type}: template artifact_type mismatch")
    ensure(template.get("chain_version") == bundle["chain_version"], f"{artifact_type}: template chain version drift")
    ensure(
        template.get("chain_registry_digest") == catalog["chain_registry_digest"],
        f"{artifact_type}: template chain_registry_digest drift",
    )
    ensure(
        template.get("authority_scope") in authority["authority_scope"],
        f"{artifact_type}: template authority_scope is not registered",
    )

    for field_name, registered_values in (
        ("status", vocab["status"]),
        ("gate_result", vocab["gate_result"]),
        ("release_recommendation", vocab["release_recommendation"]),
        ("control_action", vocab["control_action"]),
        ("decision", vocab["decision"]),
        ("severity", vocab["severity"]),
        ("priority", vocab["priority"]),
        ("runtime_status", vocab["runtime_status"]),
        ("sign_off_status", vocab["sign_off_status"]),
        ("business_risk_acceptance_status", vocab["business_risk_acceptance_status"]),
        ("current_stage", stage_registry["stages"]),
        ("blocked_from_stage", stage_registry["stages"]),
        ("resume_stage", stage_registry["stages"]),
        ("decision_source", authority["decision_source"]),
        ("actor_type", authority["actor_type"]),
        ("proof_type", authority["proof_type"]),
    ):
        if field_name in template:
            ensure(
                template[field_name] in registered_values,
                f"{artifact_type}: template {field_name} uses unknown enum {template[field_name]}",
            )

for artifact_type, expected_path in TASK_SCOPE_PATHS.items():
    ensure(
        artifacts[artifact_type]["default_path"] == expected_path,
        f"{artifact_type}: task scope path mismatch: {artifacts[artifact_type]['default_path']}",
    )

ensure(len(digests) == 1, f"catalog must expose a single digest, got {sorted(digests)}")

qa_entry = artifacts["qa-result"]
qa_schema = load_json(qa_entry["schema_path"])
qa_template = load_json(qa_entry["template_path"])
broken_qa = deepcopy(qa_template)
broken_qa["gate_result"] = "BROKEN_ENUM"
try:
    Draft202012Validator(qa_schema, registry=schema_registry).validate(broken_qa)
except ValidationError:
    pass
else:
    raise SystemExit("qa-result schema must reject unknown gate_result enum")

test_cases_entry = artifacts["test-cases"]
test_cases_schema = load_json(test_cases_entry["schema_path"])
test_cases_template = load_json(test_cases_entry["template_path"])
broken_test_cases = deepcopy(test_cases_template)
broken_test_cases["test_cases"] = [{}]
try:
    Draft202012Validator(test_cases_schema, registry=schema_registry).validate(broken_test_cases)
except ValidationError:
    pass
else:
    raise SystemExit("test-cases schema must reject missing item shape fields")

extra_field_test_cases = deepcopy(test_cases_template)
extra_field_test_cases["test_cases"] = [
    {
        "case_id": "TC-1",
        "title": "broken item",
        "unexpected": "noise"
    }
]
try:
    Draft202012Validator(test_cases_schema, registry=schema_registry).validate(extra_field_test_cases)
except ValidationError:
    pass
else:
    raise SystemExit("test-cases schema must reject extra item fields")

code_review_entry = artifacts["code-review-result"]
code_review_schema = load_json(code_review_entry["schema_path"])
code_review_template = load_json(code_review_entry["template_path"])
extra_field_review = deepcopy(code_review_template)
extra_field_review["findings"] = [
    {
        "finding_id": "REV-001",
        "severity": "S2",
        "summary": "unexpected field check",
        "unexpected": "noise"
    }
]
try:
    Draft202012Validator(code_review_schema, registry=schema_registry).validate(extra_field_review)
except ValidationError:
    pass
else:
    raise SystemExit("code-review-result schema must reject extra finding fields")
PY

echo "[PASS] standard chain foundation registry"
