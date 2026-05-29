#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BT='`'
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1" file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 \
    || fail "missing pattern in ${file#"$ROOT"/}: $pattern"
}

assert_absent() {
  local pattern="$1" file="$2"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    fail "unexpected pattern in ${file#"$ROOT"/}: $pattern"
  fi
}

python3 - "$ROOT" <<'PY' || fail "Task contract consumer alignment failed"
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools" / "community"))
from runtime_yaml import load_yaml

failures: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        failures.append(message)


schema = json.loads(
    (root / "shared/skills/tech-lead/contracts/tasks.schema.json").read_text(encoding="utf-8")
)
task_schema = schema["allOf"][1]["properties"]["tasks"]["items"]
required = set(task_schema["required"])
properties = task_schema["properties"]
require("file_range" not in required, "tasks.schema.json must not require file_range")
require("file_range" not in properties, "tasks.schema.json must not define file_range property")
for prose_field in ("real_dependency_note", "mock_boundary_note"):
    require(
        prose_field not in required,
        f"tasks.schema.json must not require prose field {prose_field}",
    )
    require(
        prose_field not in properties,
        f"tasks.schema.json must not define prose field {prose_field}",
    )
for structured_field in ("real_dependency_refs", "mock_boundary"):
    require(
        structured_field in required,
        f"tasks.schema.json must require structured field {structured_field}",
    )
    require(
        structured_field in properties,
        f"tasks.schema.json must define structured field {structured_field}",
    )
mock_boundary = properties.get("mock_boundary", {})
mock_required = set(mock_boundary.get("required", []))
require(
    {"mock_allowed", "allowed_for", "final_acceptance_requires_real_evidence"} <= mock_required,
    "mock_boundary must require mock_allowed, allowed_for, and final_acceptance_requires_real_evidence",
)
require(
    mock_boundary.get("properties", {}).get("final_acceptance_requires_real_evidence", {}).get("const") is True,
    "mock_boundary.final_acceptance_requires_real_evidence must be const true",
)
require(
    "not the writable implementation boundary" in properties["scope_item_refs"]["description"],
    "scope_item_refs description must deny writable-boundary semantics",
)

plan_schema = json.loads(
    (root / "shared/skills/tech-lead/contracts/plan.schema.json").read_text(encoding="utf-8")
)
implementation_path = plan_schema["allOf"][1]["properties"]["implementation_path"]
implementation_required = set(implementation_path["required"])
implementation_properties = implementation_path["properties"]
for prose_field in ("summary", "dependency_strategy"):
    require(
        prose_field not in implementation_required,
        f"plan.implementation_path must not require prose field {prose_field}",
    )
    require(
        prose_field not in implementation_properties,
        f"plan.implementation_path must not define prose field {prose_field}",
    )
parallel_batch_schema = implementation_properties["parallel_batches"]["items"]
require(
    "reason" not in set(parallel_batch_schema.get("required", [])),
    "plan.implementation_path.parallel_batches must not require prose reason",
)
require(
    "reason" not in parallel_batch_schema.get("properties", {}),
    "plan.implementation_path.parallel_batches must not define prose reason",
)
require(
    parallel_batch_schema.get("additionalProperties") is False,
    "plan.implementation_path.parallel_batches must reject undeclared prose fields",
)
risk_signal_schema = implementation_properties["investment_risk_signals"]["items"]
risk_signal_required = set(risk_signal_schema.get("required", []))
require(
    {"risk_id", "signal_type", "impact_level", "owner", "source_refs"} <= risk_signal_required,
    "plan.implementation_path.investment_risk_signals must require typed signal fields and source_refs",
)
for prose_field in ("signal", "impact"):
    require(
        prose_field not in risk_signal_required,
        f"plan.implementation_path.investment_risk_signals must not require prose field {prose_field}",
    )
    require(
        prose_field not in risk_signal_schema.get("properties", {}),
        f"plan.implementation_path.investment_risk_signals must not define prose field {prose_field}",
    )
require(
    risk_signal_schema.get("additionalProperties") is False,
    "plan.implementation_path.investment_risk_signals must reject undeclared prose fields",
)


field_contract = load_yaml(root / "contracts" / "standard-chain-field-consumption.yaml")
fields_by_path = {
    artifact["path"]: artifact.get("fields", {})
    for artifact in field_contract.get("artifacts", [])
}

standard_chain = load_yaml(root / "contracts" / "standard-chain.yaml")
delivery_owner = next(
    role for role in standard_chain["chain"] if role.get("name") == "delivery-owner"
)
qa_role = next(role for role in standard_chain["chain"] if role.get("name") == "qa")
product_director = next(
    role for role in standard_chain["chain"] if role.get("name") == "product-director"
)
product_manager = next(
    role for role in standard_chain["chain"] if role.get("name") == "product-manager"
)
require(
    "phase-{N}/code-review-result.json" not in set(qa_role["inputs"].get("required", [])),
    "qa required inputs must not include code-review-result; delivery-owner DO-S6 owns the review gate",
)
delivery_inputs = delivery_owner["inputs"]
future_runtime_inputs = {
    "phase-{N}/code-review-result.json",
    "phase-{N}/unit-{N}/tasks/{task_id}/developer-report.json",
    "phase-{N}/unit-{N}/tasks/{task_id}/verify-result.json",
    "phase-{N}/qa-result.json",
    "phase-{N}/consistency-audit-result.json",
}
require(
    not (set(delivery_inputs.get("required", [])) & future_runtime_inputs),
    "delivery-owner top-level required inputs must not include future runtime artifacts",
)
stage_inputs = delivery_inputs.get("stage_inputs", {})
for stage in ("DO-S1", "DO-S5", "DO-S6", "DO-S7", "DO-S8"):
    require(stage in stage_inputs, f"delivery-owner inputs must define {stage} stage inputs")
require(
    set(stage_inputs["DO-S1"].get("required", [])) == {
        "brief.json",
        "phase-{N}/phase-prd.json",
        "phase-{N}/artifact-registry.json",
        "phase-{N}/plan.json",
        "phase-{N}/tasks.json",
        "phase-{N}/design.json",
        "phase-{N}/unit-{N}/test-cases.json",
    },
    "delivery-owner DO-S1 required inputs must be kickoff baseline artifacts only",
)
require(
    {
        "phase-{N}/unit-{N}/tasks/{task_id}/developer-report.json",
        "phase-{N}/unit-{N}/tasks/{task_id}/verify-result.json",
    }.issubset(set(stage_inputs["DO-S5"].get("required", []))),
    "delivery-owner DO-S5 inputs must include developer and verify runtime evidence",
)
require(
    "phase-{N}/code-review-result.json" in set(stage_inputs["DO-S6"].get("required", [])),
    "delivery-owner DO-S6 inputs must include code-review-result",
)
require(
    "phase-{N}/qa-result.json" in set(stage_inputs["DO-S7"].get("required", [])),
    "delivery-owner DO-S7 inputs must include qa-result",
)
require(
    "phase-{N}/consistency-audit-result.json" in set(stage_inputs["DO-S8"].get("required", [])),
    "delivery-owner DO-S8 inputs must include consistency-audit-result",
)


def consumers_for(path: str, field: str) -> dict[str, str]:
    consumers = fields_by_path[path][field]["consumers"]
    return {entry["consumer"]: entry["consume_mode"] for entry in consumers}


def require_consumer(path: str, field: str, consumer: str, mode: str) -> None:
    consumers = consumers_for(path, field)
    require(
        consumers.get(consumer) == mode,
        f"{path}#{field} must be consumed by {consumer} as {mode}",
    )


brief_path = "docs/{feature}/brief.json"
phase_prd_path = "docs/{feature}/phase-{N}/phase-prd.json"
unit_path = "docs/{feature}/phase-{N}/units/UNIT-{N}.json"
design_path = "docs/{feature}/phase-{N}/design.json"
code_review_path = "docs/{feature}/phase-{N}/code-review-result.json"


def output_key_fields(role: dict, artifact: str) -> set[str]:
    for output in role.get("outputs", []):
        if output.get("artifact") == artifact:
            return set(output.get("key_fields", []))
    require(False, f"{role.get('name')} must output {artifact}")
    return set()


for role in (product_director, product_manager):
    for artifact in ("brief.json", "phase-{N}/phase-prd.json"):
        fields = output_key_fields(role, artifact)
        require(
            {"director_confirmation", "director_confirmation.locked_field_digest"}.issubset(fields),
            f"{role.get('name')} {artifact} key_fields must expose nested director lock fields",
        )

require_consumer(brief_path, "acceptance_criteria", "test-design", "transform")
require_consumer(unit_path, "verification_plan", "test-design", "transform")
for field in ("risk_ledger", "release_readiness"):
    require_consumer(phase_prd_path, field, "qa", "gate")
    require_consumer(phase_prd_path, field, "delivery-owner", "gate")
for field in ("design_decision_candidates", "technical_evidence_requirements"):
    require_consumer(phase_prd_path, field, "design", "handoff")
require_consumer(design_path, "verification_mapping", "test-design", "transform")
for field in ("planning_constraints", "migration_plan", "rollback_plan"):
    require_consumer(design_path, field, "tech-lead", "transform" if field != "planning_constraints" else "gate")
    require_consumer(design_path, field, "delivery-owner", "gate")
for path in (brief_path, phase_prd_path):
    require_consumer(path, "director_confirmation", "product-manager", "gate")
    require_consumer(path, "director_confirmation.locked_field_digest", "product-manager", "gate")
    require_consumer(path, "director_confirmation", "delivery-owner", "gate")
    require_consumer(path, "director_confirmation.locked_field_digest", "delivery-owner", "gate")
for field in ("gate_result", "dimension_verdicts", "findings", "excluded", "review_conclusion"):
    require(
        "qa" not in consumers_for(code_review_path, field),
        f"{code_review_path}#{field} must not be consumed by qa",
    )
require_consumer(code_review_path, "gate_result", "delivery-owner", "gate")
require_consumer(code_review_path, "dimension_verdicts", "delivery-owner", "reference")
require_consumer(code_review_path, "findings", "delivery-owner", "gate")
require_consumer(code_review_path, "excluded", "delivery-owner", "reference")
require_consumer(code_review_path, "review_conclusion", "delivery-owner", "gate")

developer_report_schema = json.loads(
    (root / "shared/skills/developer/contracts/developer-report.schema.json").read_text(
        encoding="utf-8"
    )
)
developer_report_properties = developer_report_schema["allOf"][1]["properties"]
require(
    "impact" in developer_report_properties["task_scope"]["description"].lower(),
    "developer-report.task_scope must reference impact analysis, not file_range",
)
require(
    "file_range" not in developer_report_properties["task_scope"]["description"],
    "developer-report.task_scope must not reference file_range",
)


def run(command: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


source = root / "tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature"
with tempfile.TemporaryDirectory(prefix="task-contract-consumer-") as tmp:
    feature = Path(tmp) / "sample-feature"
    shutil.copytree(source, feature)
    phase_dir = feature / "phase-1"

    delivery = run(
        [
            "python3",
            "shared/skills/delivery-owner/scripts/intake_preflight_check.py",
            "--phase-dir",
            str(phase_dir),
        ],
        root,
    )
    require(delivery.returncode == 0, "delivery-owner intake must pass without file_range")

    developer = run(
        [
            "python3",
            "shared/skills/developer/scripts/preflight_check.py",
            "--phase-dir",
            str(phase_dir),
            "--task-id",
            "T1",
        ],
        root,
    )
    require(developer.returncode == 0, "developer preflight must pass without file_range")

    verify = run(
        [
            "python3",
            "shared/skills/verify/scripts/preflight_check.py",
            "--phase-dir",
            str(phase_dir),
            "--task-id",
            "T1",
        ],
        root,
    )
    require(verify.returncode == 0, "verify preflight must pass without file_range")

if failures:
    raise SystemExit("\n".join(failures))
PY

assert_present "scope_item_refs.*范围来源" "$ROOT/shared/skills/tech-lead/SKILL.md"
assert_absent "file_range" "$ROOT/shared/skills/tech-lead/SKILL.md"
assert_absent "file_range" "$ROOT/shared/skills/developer/SKILL.md"
assert_absent "file_range" "$ROOT/shared/skills/verify/SKILL.md"
assert_present "QA ${BT}scope${BT} 只裁剪 QA_A-D 执行阶段" "$ROOT/shared/skills/qa/SKILL.md"
assert_absent "file_range" "$ROOT/shared/skills/qa/SKILL.md"
assert_absent "file_range" "$ROOT/shared/skills/delivery-owner/references/dispatch-packet.md"
assert_absent "file_range" "$ROOT/shared/skills/consistency-audit/references/check-matrix.md"

printf '[PASS] task contract consumer alignment\n'
