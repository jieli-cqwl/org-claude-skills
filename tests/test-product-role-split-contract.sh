#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=tests/lib/test-env.sh
. "$ROOT/tests/lib/test-env.sh"
ensure_test_rg

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    fail "unexpected pattern in $file: $pattern"
  fi
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in $file: $pattern"
}

assert_registry_codex_supported() {
  local registry_file="$1"
  local skill_name="$2"
  local expected="$3"
  local actual

  actual=$(jq -r --arg skill "$skill_name" '.skill_completion_gates[] | select(.skill == $skill) | .codex.supported' "$registry_file")
  [ "$actual" = "$expected" ] || fail "unexpected codex.supported for $skill_name: expected $expected, got ${actual:-<empty>}"
}

DIRECTOR_BRIEF_JSON_TEMPLATE="$ROOT/shared/skills/product-director/templates/brief.template.json"
DIRECTOR_PHASE_JSON_TEMPLATE="$ROOT/shared/skills/product-director/templates/phase-prd.template.json"
MANAGER_BRIEF_TEMPLATE="$ROOT/shared/skills/product-manager/templates/brief.template.json"
MANAGER_PHASE_TEMPLATE="$ROOT/shared/skills/product-manager/templates/phase-prd.template.json"
CHAIN_CONTRACT="$ROOT/contracts/standard-chain.yaml"
PRODUCT_ARTIFACT_CONTRACT="$ROOT/contracts/product-artifacts.yaml"
PRODUCT_ARTIFACT_TEST="$ROOT/tests/test-product-artifact-contract.sh"
HOOK_REGISTRY="$ROOT/shared/hooks/registry.json"
PRODUCT_MANAGER_MANIFEST="$ROOT/shared/skills/product-manager/scripts/manifest.json"
PRODUCT_MANAGER_CHECK="$ROOT/shared/skills/product-manager/scripts/completion_check.sh"
PRODUCT_DIRECTOR_ROOT="$ROOT/shared/skills/product-director"
PRODUCT_MANAGER_ROOT="$ROOT/shared/skills/product-manager"

for path in \
  "$DIRECTOR_BRIEF_JSON_TEMPLATE" \
  "$DIRECTOR_PHASE_JSON_TEMPLATE" \
  "$MANAGER_BRIEF_TEMPLATE" \
  "$MANAGER_PHASE_TEMPLATE" \
  "$CHAIN_CONTRACT" \
  "$PRODUCT_ARTIFACT_CONTRACT" \
  "$PRODUCT_ARTIFACT_TEST" \
  "$HOOK_REGISTRY" \
  "$PRODUCT_MANAGER_MANIFEST" \
  "$PRODUCT_MANAGER_CHECK"
do
  test -f "$path" || fail "missing contract file: $path"
done

test -d "$PRODUCT_DIRECTOR_ROOT" || fail "missing product-director root: $PRODUCT_DIRECTOR_ROOT"
test -d "$PRODUCT_MANAGER_ROOT" || fail "missing product-manager root: $PRODUCT_MANAGER_ROOT"
if [ -d "$PRODUCT_DIRECTOR_ROOT/references/templates" ]; then
  fail "product-director must not retain active references/templates"
fi

jq -e '
  .artifact_type == "brief"
  and .producer == "product-director"
  and (.authoritative_fields | index("$.director_confirmation"))
  and .director_confirmation.locked_fields
  and .director_confirmation.locked_field_digest
  and .root_problem
  and .user_profile
  and .business_goals
  and .appetite
  and .scope_boundaries
  and .non_goals
  and .feasibility_constraints
  and .risks_and_unknowns
  and .decision_rationale
  and .delivery_plan
  and (.review_conclusion? | not)
  and (.issue_ledger? | not)
  and (.delivery_confirmation? | not)
' "$DIRECTOR_BRIEF_JSON_TEMPLATE" >/dev/null || fail "director brief template must expose canonical Director handoff envelope"

jq -e '
  .artifact_type == "phase-prd"
  and .producer == "product-director"
  and (.authoritative_fields | index("$.director_confirmation"))
  and .director_confirmation.locked_fields
  and .director_confirmation.locked_field_digest
  and .phase_goal
  and .entry_conditions
  and .exit_conditions
  and (.unit_index? | not)
  and (.review_conclusion? | not)
  and (.issue_ledger? | not)
' "$DIRECTOR_PHASE_JSON_TEMPLATE" >/dev/null || fail "director phase template must expose canonical Director handoff envelope"

jq -e '
  .director_confirmation.locked_fields
  and .director_confirmation.locked_field_digest
  and (.issue_ledger | type == "array")
  and (.review_conclusion? | not)
  and (.delivery_confirmation? | not)
  and (.authoritative_fields | index("$.review_conclusion"))
  and (.authoritative_fields | index("$.delivery_confirmation"))
  and .acceptance_criteria
  and .design_decisions
  and (.non_functional_requirements | type == "array" and length > 0)
  and all(.non_functional_requirements[]; type == "object"
    and .requirement_id
    and .quality_attribute
    and .source_refs
    and .verification_owner
    and .verification_stage
    and (has("description") | not)
    and (has("summary") | not))
' "$MANAGER_BRIEF_TEMPLATE" >/dev/null || fail "manager brief template must expose PM-owned fields without fake review/delivery closure"

jq -e '
  .director_confirmation.locked_fields
  and .director_confirmation.locked_field_digest
  and (.issue_ledger | type == "array")
  and (.review_conclusion? | not)
  and (.authoritative_fields | index("$.review_conclusion"))
  and ((.unit_index // []) | type == "array" and length > 0)
  and .business_flows
  and .user_paths
  and .rule_mappings
  and .design_decision_candidates
' "$MANAGER_PHASE_TEMPLATE" >/dev/null || fail "manager phase template must expose PM-owned phase semantics without fake review closure"

python3 - "$CHAIN_CONTRACT" <<'PY'
import sys
from pathlib import Path

import yaml

chain = yaml.safe_load(Path(sys.argv[1]).read_text(encoding="utf-8"))["chain"]
entries = {entry["name"]: entry for entry in chain}
if "product" in entries:
    raise SystemExit("legacy product skill must not remain in standard-chain")
for name in ("product-director", "product-manager"):
    if name not in entries:
        raise SystemExit(f"standard-chain missing {name}")

manager = entries["product-manager"]
if manager["inputs"]["required"] != ["brief.json", "phase-{N}/phase-prd.json"]:
    raise SystemExit("product-manager required inputs drift")

outputs = {output["artifact"]: output for output in manager["outputs"]}
phase = outputs.get("phase-{N}/phase-prd.json")
unit = outputs.get("phase-{N}/units/UNIT-{N}.json")
if phase is None or unit is None:
    raise SystemExit("product-manager phase or UNIT output missing")
expected_phase_fields = [
    "phase_goal",
    "entry_conditions",
    "exit_conditions",
    "director_confirmation",
    "director_confirmation.locked_field_digest",
    "evidence_sources",
    "as_is_flows",
    "to_be_flows",
    "business_process_graphs",
    "feature_inventory",
    "module_capability_matrix",
    "entry_scene_inventory",
    "business_objects",
    "state_transitions",
    "role_permission_matrix",
    "risk_ledger",
    "coverage_matrix",
    "technical_evidence_requirements",
    "release_readiness",
    "business_flows",
    "user_paths",
    "rule_mappings",
    "unit_index",
    "unit_priority_order",
    "design_decision_candidates",
    "review_conclusion",
    "issue_ledger",
]
if phase.get("key_fields") != expected_phase_fields:
    raise SystemExit("product-manager phase key_fields drift")

legacy_refs = {"brief.md", "review.md", "product-manager-review.md"}
required_refs = set(manager.get("inputs", {}).get("required", []))
artifact_refs = set(outputs)
if legacy_refs & (required_refs | artifact_refs):
    raise SystemExit("legacy product markdown artifact remains in standard-chain")
PY

jq -e '
  [.skill_completion_gates[] | select(.skill == "product-director" or .skill == "product-manager")] as $entries
  | ($entries | length) == 2
  and all($entries[]; .owner == .skill and (.allowed_args | index("hook payload via stdin only")) and (.allowed_args | index("--help")) and (.allowed_args | index("-h")) and (.codex.supported == true))
' "$HOOK_REGISTRY" >/dev/null || fail "hook registry must expose product-director and product-manager completion gates"
assert_registry_codex_supported "$HOOK_REGISTRY" "product-director" "true"
assert_registry_codex_supported "$HOOK_REGISTRY" "product-manager" "true"

python3 - "$PRODUCT_MANAGER_MANIFEST" "$HOOK_REGISTRY" <<'PY'
import json
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
registry = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))

script = next(item for item in manifest["scripts"] if item.get("id") == "completion-check")
required_script = {
    "id",
    "path",
    "owner",
    "allowed_args",
    "timeout_seconds",
    "output_root",
    "allowed_input_roots",
    "failure_state",
}
missing_script = sorted(required_script - set(script))
if missing_script:
    raise SystemExit(f"product-manager manifest script missing keys: {missing_script}")
if script["owner"] != "product-manager":
    raise SystemExit("product-manager manifest owner mismatch")
if script["path"] != "scripts/completion_check.sh":
    raise SystemExit("product-manager manifest path mismatch")
if not isinstance(script["timeout_seconds"], int) or script["timeout_seconds"] <= 0:
    raise SystemExit("product-manager manifest timeout invalid")

entry = next(item for item in registry["skill_completion_gates"] if item.get("skill") == "product-manager")
required_registry = {"owner", "allowed_args", "output_root", "failure_state"}
missing_registry = sorted(required_registry - set(entry))
if missing_registry:
    raise SystemExit(f"product-manager registry missing keys: {missing_registry}")
for field in required_registry:
    if entry[field] != script[field]:
        raise SystemExit(f"product-manager registry and manifest {field} drift")
if entry.get("handler_rel") != f"skills/product-manager/{script['path']}":
    raise SystemExit("product-manager registry and manifest handler drift")
if entry.get("timeout_sec") != script["timeout_seconds"]:
    raise SystemExit("product-manager registry and manifest timeout drift")
PY

assert_present 'validate_canonical_schema\.py' "$PRODUCT_MANAGER_CHECK"
assert_present 'validate_product_closure\.py' "$PRODUCT_MANAGER_CHECK"
assert_absent 'shared/skills/product/scripts/completion_check\.sh' "$PRODUCT_MANAGER_CHECK"
assert_absent '^LEGACY_PRODUCT_CHECK=' "$PRODUCT_MANAGER_CHECK"
assert_absent 'REVIEW_FILE="\$FEATURE_DIR/product-manager-review\.md"' "$PRODUCT_MANAGER_CHECK"

assert_present 'test-product-artifact-contract\.sh' "$0"

echo "[PASS] product role split contract"
