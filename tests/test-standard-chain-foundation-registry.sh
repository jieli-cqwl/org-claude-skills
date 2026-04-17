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
from jsonschema import Draft202012Validator, FormatChecker, ValidationError
from referencing import Registry, Resource

sys.path.insert(0, str(Path(sys.argv[1])))
from tools.community.simple_json_schema import SimpleSchemaValidator, SimpleValidationError


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
REQUIRED_SCHEMA_FIELDS = {
    "brief": {"root_problem", "business_goals", "scope_boundaries", "delivery_plan", "director_confirmation"},
    "phase-prd": {"director_confirmation"},
    "unit-definition": {"priority", "priority_basis", "dependencies"},
    "test-cases": {"qa_handoff_contract", "review_conclusion", "issue_ledger"},
    "plan": {"goal_source_refs", "constraint_source_refs", "obligation_source_refs", "execution_basis_refs"},
    "qa-result": {"uncovered_boundary", "conditional_release_basis", "not_executed_reason", "ruled_out_issues", "issue_ledger"},
    "signoff-package": {"current_stage"},
    "user-decision": {"current_stage", "director_lock_digests"},
}
EXPECTED_EXECUTION_MODES = ["browser_required", "non_browser_ok"]
GOLDEN_FIXTURES = {
    "brief": "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/brief.json",
    "phase-prd": "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/phase-prd.json",
    "design": "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/design.json",
    "test-cases": "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/test-cases.json",
    "plan": "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/plan.json",
    "tasks": "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/tasks.json",
    "qa-result": "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/qa-result.json",
    "delivery-state": "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/delivery-state.json",
    "artifact-registry": "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/artifact-registry.json",
    "signoff-package": "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/signoff-package.json",
    "user-decision": "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/user-decision.json",
}
TASK_GOLDEN_FIXTURES = {
    "developer-report": [
        "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T1/developer-report.json",
        "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T2/developer-report.json",
    ],
    "verify-result": [
        "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T1/verify-result.json",
        "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/tasks/T2/verify-result.json",
    ],
}
REQUIRED_SKILL_KEY_FIELDS_BY_ARTIFACT = {
    "qa-result": {"current_stage"},
    "signoff-package": {"current_stage"},
}


def load_yaml(rel_path: str) -> dict:
    return yaml.safe_load((ROOT / rel_path).read_text(encoding="utf-8"))


def load_json(rel_path: str) -> dict:
    return json.loads((ROOT / rel_path).read_text(encoding="utf-8"))


def ensure(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def schema_validator(schema: dict, registry: Registry) -> Draft202012Validator:
    return Draft202012Validator(schema, registry=registry, format_checker=FormatChecker())


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
ensure(
    shared_core_schema["$defs"]["fieldPathArray"].get("minItems") == 1,
    "shared-core fieldPathArray must reject empty authoritative_fields",
)
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
    schema_object = next(item for item in reversed(schema["allOf"]) if "properties" in item)
    required_fields = set(schema_object.get("required", []))
    for field_name in REQUIRED_SCHEMA_FIELDS.get(artifact_type, set()):
        ensure(field_name in required_fields, f"{artifact_type}: schema must require {field_name}")
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

    if artifact_type == "test-cases":
        execution_mode_schema = (
            schema_object["properties"]["qa_handoff_contract"]["items"]["properties"]["execution_mode"]
        )
        ensure(
            execution_mode_schema.get("enum") == EXPECTED_EXECUTION_MODES,
            f"test-cases: execution_mode enum mismatch: {execution_mode_schema.get('enum')}",
        )
    if artifact_type == "qa-result":
        ensure(
            schema_object["properties"]["release_recommendation"].get("enum") == REQUIRED_VOCAB["release_recommendation"],
            "qa-result: release_recommendation enum mismatch",
        )
        ensure(
            schema_object["properties"]["gate_result"].get("enum") == REQUIRED_VOCAB["gate_result"],
            "qa-result: gate_result enum mismatch",
        )

    template = load_json(entry["template_path"])
    schema_validator(schema, schema_registry).validate(template)
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

shared_properties = set(shared_core_schema["properties"].keys())
skill_chain = load_yaml("contracts/skill-chain.yaml")
delivery_outputs = {
    output["artifact"]
    for step in skill_chain["chain"]
    if step.get("name") == "delivery-owner"
    for output in step.get("outputs", [])
}
ensure(
    "phase-{N}/user-decision.json" in delivery_outputs,
    "delivery-owner skill-chain outputs must include user-decision.json",
)
artifact_contract = skill_chain.get("artifact_contract", {})
ensure(
    artifact_contract.get("user_decision_artifact") == "docs/{feature}/phase-{N}/user-decision.json",
    "skill-chain artifact_contract must declare user_decision_artifact",
)
schema_by_output = {
    "brief.json": "brief",
    "phase-{N}/phase-prd.json": "phase-prd",
    "phase-{N}/units/UNIT-{N}.json": "unit-definition",
    "phase-{N}/design.json": "design",
    "phase-{N}/unit-{N}/test-cases.json": "test-cases",
    "phase-{N}/plan.json": "plan",
    "phase-{N}/tasks.json": "tasks",
    "phase-{N}/unit-{N}/tasks/{task_id}/developer-report.json": "developer-report",
    "phase-{N}/code-review-result.json": "code-review-result",
    "phase-{N}/unit-{N}/tasks/{task_id}/verify-result.json": "verify-result",
    "phase-{N}/qa-result.json": "qa-result",
    "phase-{N}/delivery-state.json": "delivery-state",
    "phase-{N}/artifact-registry.json": "artifact-registry",
    "phase-{N}/signoff-package.json": "signoff-package",
    "phase-{N}/user-decision.json": "user-decision",
}
for step in skill_chain["chain"]:
    for output in step.get("outputs", []):
        artifact_path = output["artifact"]
        if artifact_path == "code":
            continue
        artifact_type = schema_by_output[artifact_path]
        schema = load_json(artifacts[artifact_type]["schema_path"])
        schema_properties = set(shared_properties)
        for part in schema.get("allOf", []):
            schema_properties.update(part.get("properties", {}).keys())
        missing_key_fields = [
            field for field in output.get("key_fields", [])
            if field not in schema_properties
        ]
        ensure(
            not missing_key_fields,
            f"skill-chain key_fields missing from {artifact_type} schema: {missing_key_fields}",
        )
        template = load_json(artifacts[artifact_type]["template_path"])
        authoritative_fields = {
            field.removeprefix("$.").split("[", 1)[0].split(".", 1)[0]
            for field in template.get("authoritative_fields", [])
            if isinstance(field, str) and field.startswith("$.")
        }
        missing_authoritative_fields = [
            field for field in output.get("key_fields", [])
            if field not in authoritative_fields
        ]
        ensure(
            not missing_authoritative_fields,
            f"skill-chain key_fields missing from {artifact_type} template authoritative_fields: {missing_authoritative_fields}",
        )
        missing_required_key_fields = sorted(
            REQUIRED_SKILL_KEY_FIELDS_BY_ARTIFACT.get(artifact_type, set()) - set(output.get("key_fields", []))
        )
        ensure(
            not missing_required_key_fields,
            f"skill-chain output for {artifact_type} missing required key_fields: {missing_required_key_fields}",
        )

for artifact_type, fixture_path in GOLDEN_FIXTURES.items():
    template = load_json(artifacts[artifact_type]["template_path"])
    fixture = load_json(fixture_path)
    missing_fixture_fields = [
        field
        for field in template.get("authoritative_fields", [])
        if field not in fixture.get("authoritative_fields", [])
    ]
    ensure(
        not missing_fixture_fields,
        f"golden {artifact_type} authoritative_fields missing template fields: {missing_fixture_fields}",
    )

for artifact_type, fixture_paths in TASK_GOLDEN_FIXTURES.items():
    template = load_json(artifacts[artifact_type]["template_path"])
    for fixture_path in fixture_paths:
        fixture = load_json(fixture_path)
        missing_fixture_fields = [
            field
            for field in template.get("authoritative_fields", [])
            if field not in fixture.get("authoritative_fields", [])
        ]
        ensure(
            not missing_fixture_fields,
            f"golden {fixture_path} authoritative_fields missing template fields: {missing_fixture_fields}",
        )

golden_registry = load_json(GOLDEN_FIXTURES["artifact-registry"])
golden_lock_digests = {
    load_json(GOLDEN_FIXTURES["brief"])["artifact_id"]: load_json(GOLDEN_FIXTURES["brief"])["director_confirmation"][
        "locked_field_digest"
    ],
    load_json(GOLDEN_FIXTURES["phase-prd"])["artifact_id"]: load_json(GOLDEN_FIXTURES["phase-prd"])["director_confirmation"][
        "locked_field_digest"
    ],
}
active_entries = [
    entry
    for revision in golden_registry["revisions"]
    if revision["revision_id"] == golden_registry["active_revision_id"]
    for entry in revision["entries"]
    if entry.get("active_for_consumption") is True
]
for artifact_id, expected_digest in golden_lock_digests.items():
    matches = [entry for entry in active_entries if entry.get("artifact_id") == artifact_id]
    ensure(len(matches) == 1, f"golden registry must bind Director lock artifact once: {artifact_id}")
    ensure(
        matches[0].get("director_lock_digest") == expected_digest,
        f"golden registry director_lock_digest drift: {artifact_id}",
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
    schema_validator(qa_schema, schema_registry).validate(broken_qa)
except ValidationError:
    pass
else:
    raise SystemExit("qa-result schema must reject unknown gate_result enum")

broken_qa_release = deepcopy(qa_template)
broken_qa_release["release_recommendation"] = "条件放行"
try:
    schema_validator(qa_schema, schema_registry).validate(broken_qa_release)
except ValidationError:
    pass
else:
    raise SystemExit("qa-result schema must reject legacy localized release_recommendation values")

missing_qa_ruled_out = deepcopy(qa_template)
missing_qa_ruled_out.pop("ruled_out_issues", None)
try:
    schema_validator(qa_schema, schema_registry).validate(missing_qa_ruled_out)
except ValidationError:
    pass
else:
    raise SystemExit("qa-result schema must require ruled_out_issues")

missing_qa_current_stage = deepcopy(qa_template)
missing_qa_current_stage.pop("current_stage", None)
try:
    schema_validator(qa_schema, schema_registry).validate(missing_qa_current_stage)
except ValidationError:
    pass
else:
    raise SystemExit("qa-result schema must require current_stage snapshot")

brief_entry = artifacts["brief"]
brief_schema = load_json(brief_entry["schema_path"])
brief_template = load_json(brief_entry["template_path"])
missing_brief_confirmation = deepcopy(brief_template)
missing_brief_confirmation.pop("root_problem", None)
try:
    schema_validator(brief_schema, schema_registry).validate(missing_brief_confirmation)
except ValidationError:
    pass
else:
    raise SystemExit("brief schema must require Director-owned root_problem")

pending_brief_director = deepcopy(brief_template)
pending_brief_director["director_confirmation"]["status"] = "pending"
try:
    schema_validator(brief_schema, schema_registry).validate(pending_brief_director)
except ValidationError:
    pass
else:
    raise SystemExit("brief schema must reject pending director_confirmation")

open_brief_issue = deepcopy(brief_template)
open_brief_issue["review_conclusion"]["verdict"] = "WARN"
open_brief_issue["issue_ledger"] = [{"issue_id": "P-1", "status": "OPEN"}]
try:
    schema_validator(brief_schema, schema_registry).validate(open_brief_issue)
except ValidationError:
    pass
else:
    raise SystemExit("brief schema must reject unresolved issue_ledger status")

phase_prd_entry = artifacts["phase-prd"]
phase_prd_schema = load_json(phase_prd_entry["schema_path"])
phase_prd_template = load_json(phase_prd_entry["template_path"])
missing_phase_review = deepcopy(phase_prd_template)
missing_phase_review.pop("director_confirmation", None)
try:
    schema_validator(phase_prd_schema, schema_registry).validate(missing_phase_review)
except ValidationError:
    pass
else:
    raise SystemExit("phase-prd schema must require director_confirmation")

unit_entry = artifacts["unit-definition"]
unit_schema = load_json(unit_entry["schema_path"])
unit_template = load_json(unit_entry["template_path"])
hollow_unit = deepcopy(unit_template)
hollow_unit["closure_definition"] = ""
hollow_unit["acceptance_criteria"] = []
hollow_unit["exclusions"] = []
hollow_unit.pop("dependencies", None)
hollow_unit.pop("priority", None)
hollow_unit.pop("priority_basis", None)
try:
    schema_validator(unit_schema, schema_registry).validate(hollow_unit)
except ValidationError:
    pass
else:
    raise SystemExit("unit-definition schema must reject hollow UNIT definitions")

test_cases_entry = artifacts["test-cases"]
test_cases_schema = load_json(test_cases_entry["schema_path"])
test_cases_template = load_json(test_cases_entry["template_path"])
broken_test_cases = deepcopy(test_cases_template)
broken_test_cases["test_cases"] = [{}]
try:
    schema_validator(test_cases_schema, schema_registry).validate(broken_test_cases)
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
    schema_validator(test_cases_schema, schema_registry).validate(extra_field_test_cases)
except ValidationError:
    pass
else:
    raise SystemExit("test-cases schema must reject extra item fields")

missing_test_handoff = deepcopy(test_cases_template)
missing_test_handoff.pop("qa_handoff_contract", None)
try:
    schema_validator(test_cases_schema, schema_registry).validate(missing_test_handoff)
except ValidationError:
    pass
else:
    raise SystemExit("test-cases schema must require qa_handoff_contract")

invalid_execution_mode = deepcopy(test_cases_template)
invalid_execution_mode["qa_handoff_contract"][0]["execution_mode"] = "browser_only"
try:
    schema_validator(test_cases_schema, schema_registry).validate(invalid_execution_mode)
except ValidationError:
    pass
else:
    raise SystemExit("test-cases schema must reject unknown execution_mode enum")

tasks_entry = artifacts["tasks"]
tasks_schema = load_json(tasks_entry["schema_path"])
tasks_template = load_json(tasks_entry["template_path"])
missing_task_design_refs = deepcopy(tasks_template)
missing_task_design_refs["tasks"][0]["design_refs"] = []
try:
    schema_validator(tasks_schema, schema_registry).validate(missing_task_design_refs)
except ValidationError:
    pass
else:
    raise SystemExit("tasks schema must require non-empty design_refs for each task")

missing_task_test_refs = deepcopy(tasks_template)
missing_task_test_refs["tasks"][0]["test_refs"] = []
try:
    schema_validator(tasks_schema, schema_registry).validate(missing_task_test_refs)
except ValidationError:
    pass
else:
    raise SystemExit("tasks schema must require non-empty test_refs for each task")

code_review_entry = artifacts["code-review-result"]
code_review_schema = load_json(code_review_entry["schema_path"])
code_review_template = load_json(code_review_entry["template_path"])
missing_review_dimension_verdicts = deepcopy(code_review_template)
missing_review_dimension_verdicts.pop("dimension_verdicts", None)
try:
    schema_validator(code_review_schema, schema_registry).validate(missing_review_dimension_verdicts)
except ValidationError:
    pass
else:
    raise SystemExit("code-review-result schema must require dimension_verdicts")

missing_review_excluded = deepcopy(code_review_template)
missing_review_excluded["excluded"] = []
try:
    schema_validator(code_review_schema, schema_registry).validate(missing_review_excluded)
except ValidationError:
    pass
else:
    raise SystemExit("code-review-result schema must require at least 2 excluded entries")

extra_field_review = deepcopy(code_review_template)
extra_field_review["findings"] = [
    {
        "finding_id": "REV-001",
        "severity": "S2",
        "summary": "unexpected field check",
        "file_path": "shared/hooks/managed/codex_stop_dispatch.py",
        "line_number": 42,
        "confidence": 90,
        "verification_status": "NOT_REQUIRED",
        "unexpected": "noise"
    }
]
try:
    schema_validator(code_review_schema, schema_registry).validate(extra_field_review)
except ValidationError:
    pass
else:
    raise SystemExit("code-review-result schema must reject extra finding fields")

additional_schema = {
    "type": "object",
    "properties": {"known": {"type": "string"}},
    "additionalProperties": {"type": "string"},
}
try:
    SimpleSchemaValidator({}).validate({"known": "ok", "extra": 1}, additional_schema)
except SimpleValidationError:
    pass
else:
    raise SystemExit("fallback schema validator must validate additionalProperties subschemas")

developer_report_entry = artifacts["developer-report"]
developer_report_schema = load_json(developer_report_entry["schema_path"])
developer_report_template = load_json(developer_report_entry["template_path"])
missing_tdd_index = deepcopy(developer_report_template)
missing_tdd_index.pop("tdd_evidence_index", None)
try:
    schema_validator(developer_report_schema, schema_registry).validate(missing_tdd_index)
except ValidationError:
    pass
else:
    raise SystemExit("developer-report schema must require tdd_evidence_index")

verify_entry = artifacts["verify-result"]
verify_schema = load_json(verify_entry["schema_path"])
verify_template = load_json(verify_entry["template_path"])
missing_phase_verdicts = deepcopy(verify_template)
missing_phase_verdicts.pop("phase_verdicts", None)
try:
    schema_validator(verify_schema, schema_registry).validate(missing_phase_verdicts)
except ValidationError:
    pass
else:
    raise SystemExit("verify-result schema must require phase_verdicts")

missing_ac_verification = deepcopy(verify_template)
missing_ac_verification["ac_verification"] = []
try:
    schema_validator(verify_schema, schema_registry).validate(missing_ac_verification)
except ValidationError:
    pass
else:
    raise SystemExit("verify-result schema must require non-empty ac_verification")

signoff_entry = artifacts["signoff-package"]
signoff_schema = load_json(signoff_entry["schema_path"])
signoff_template = load_json(signoff_entry["template_path"])
missing_signoff_stage = deepcopy(signoff_template)
missing_signoff_stage.pop("current_stage", None)
try:
    schema_validator(signoff_schema, schema_registry).validate(missing_signoff_stage)
except ValidationError:
    pass
else:
    raise SystemExit("signoff-package schema must require current_stage snapshot")

user_decision_entry = artifacts["user-decision"]
user_decision_schema = load_json(user_decision_entry["schema_path"])
user_decision_template = load_json(user_decision_entry["template_path"])
missing_user_stage = deepcopy(user_decision_template)
missing_user_stage.pop("current_stage", None)
try:
    schema_validator(user_decision_schema, schema_registry).validate(missing_user_stage)
except ValidationError:
    pass
else:
    raise SystemExit("user-decision schema must require current_stage snapshot")

missing_user_director_locks = deepcopy(user_decision_template)
missing_user_director_locks.pop("director_lock_digests", None)
try:
    schema_validator(user_decision_schema, schema_registry).validate(missing_user_director_locks)
except ValidationError:
    pass
else:
    raise SystemExit("user-decision schema must require director_lock_digests anchor")
PY

echo "[PASS] standard chain foundation registry"
