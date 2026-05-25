#!/usr/bin/env bash
# File responsibility: dogfood /product-manager on a representative Product Phase.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFLIGHT="$ROOT/shared/skills/product-manager/scripts/preflight_check.sh"
COMPLETION="$ROOT/shared/skills/product-manager/scripts/completion_check.sh"
DESIGN_PREFLIGHT="$ROOT/shared/skills/design/scripts/preflight_check.sh"
PHASE_VALIDATOR="$ROOT/tools/community/validate_standard_chain_phase.py"
PACKAGE_AUDIT="$ROOT/tools/skill_quality/check_skill_package_quality.py"
RESULT="$ROOT/shared/skills/product-manager/evals/dogfood/request-review-flow/with_skill/dogfood-result.json"
ANCHOR_FIDELITY="$ROOT/shared/skills/product-manager/evals/dogfood/request-review-flow/with_skill/anchor-fidelity.json"
LIFECYCLE="$ROOT/shared/skills/product-manager/evals/lifecycle-review.json"
SOURCE_FEATURE="$ROOT/shared/skills/product-manager/evals/dogfood/request-review-flow/with_skill/outputs/docs/request-review-flow"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/product-manager-dogfood.XXXXXX")"

trap 'rm -rf "$TMP_ROOT"' EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "missing file: $1"
}

assert_present() {
  local pattern="$1" file="$2" label="${3:-$2}"
  grep -Eq "$pattern" "$file" || fail "missing pattern in ${label#"$ROOT"/}: $pattern"
}

prepare_workspace() {
  local workspace="$1"
  mkdir -p "$workspace/docs"
  cp -R "$SOURCE_FEATURE" "$workspace/docs/request-review-flow"
}

run_manager_hook() {
  local workspace="$1"
  local transcript="$workspace/transcript.log"
  local payload

  printf '%s\n' "docs/request-review-flow/brief.json" >"$transcript"
  payload="$(jq -nc \
    --arg cwd "$workspace" \
    --arg sid "product-manager-dogfood" \
    --arg tp "$transcript" \
    --arg fp "docs/request-review-flow/brief.json" \
    '{cwd:$cwd, session_id:$sid, transcript_path:$tp, tool_name:"Write", tool_input:{file_path:$fp}}')"

  if (cd "$workspace" && bash "$COMPLETION" <<<"$payload") >"$workspace/hook.stdout" 2>"$workspace/hook.stderr"; then
    printf '0\n' >"$workspace/hook.status"
  else
    printf '%s\n' "$?" >"$workspace/hook.status"
  fi
}

assert_dogfood_result_contract() {
  python3 - "$RESULT" "$ANCHOR_FIDELITY" "$LIFECYCLE" <<'PY'
import json
import sys
from pathlib import Path

result_path = Path(sys.argv[1])
fidelity_path = Path(sys.argv[2])
review_path = Path(sys.argv[3])
result = json.loads(result_path.read_text(encoding="utf-8"))
fidelity = json.loads(fidelity_path.read_text(encoding="utf-8"))
review = json.loads(review_path.read_text(encoding="utf-8"))

for artifact_name, artifact in (("dogfood", result), ("lifecycle", review)):
    stack = [((), artifact)]
    while stack:
        path, value = stack.pop()
        if isinstance(value, dict):
            stack.extend((path + (key,), child) for key, child in value.items())
            continue
        if isinstance(value, list):
            stack.extend((path + (str(index),), child) for index, child in enumerate(value))
            continue
        if not isinstance(value, str):
            continue
        key_path = ".".join(path)
        if path and path[-1] in {"eval_id", "with_skill_ref", "without_skill_ref"}:
            continue
        if any(term in value for term in ("standard-chain", "canonical", "真源", "accepted_warning")):
            raise SystemExit(f"{artifact_name} evidence keeps old wording at {key_path}: {value}")

if result.get("artifact_type") != "product-manager-dogfood-result":
    raise SystemExit("dogfood result artifact_type drift")
if result.get("eval_id") != "request-review-flow-pm-flow":
    raise SystemExit("dogfood eval_id drift")
if result.get("run_mode") != "with_skill":
    raise SystemExit("dogfood run_mode must be with_skill")
if result.get("skill_under_test") != "shared/skills/product-manager":
    raise SystemExit("dogfood skill_under_test drift")

quality = result.get("quality_standard", {})
if quality.get("decision_layer") != "Production evidence":
    raise SystemExit("dogfood must record Production evidence decision layer")
required_dimensions = {"S3", "S4", "S7", "S8", "E2", "E4"}
if not required_dimensions.issubset(set(quality.get("dimensions", []))):
    raise SystemExit(f"dogfood missing dimensions: {sorted(required_dimensions - set(quality.get('dimensions', [])))}")

baseline = result.get("co_created_baseline", {})
for field in (
    "real_scenario",
    "business_constraint",
    "success_standard",
    "known_pain",
    "non_loss_capability",
    "priority_ring",
):
    if not str(baseline.get(field, "")).strip():
        raise SystemExit(f"dogfood baseline missing {field}")

expected_steps = [
    "Handoff gate",
    "Evidence and AS-IS",
    "TO-BE product model",
    "Feature inventory and risk",
    "Pre-UNIT gate",
    "UNIT split",
    "AC",
    "Verification Plan",
    "Design handoff",
    "Self-check",
    "Review digest",
    "Agent review",
    "PM handoff gate",
    "Delivery",
]
steps = result.get("dogfood_execution", {}).get("step_results", [])
actual_steps = [step.get("step_id") for step in steps]
if actual_steps != expected_steps:
    raise SystemExit(f"dogfood step order drift: {actual_steps}")
for step in steps:
    if step.get("status") != "PASS":
        raise SystemExit(f"dogfood step not PASS: {step}")
    if not step.get("evidence_refs"):
        raise SystemExit(f"dogfood step missing evidence_refs: {step}")

downstream = result.get("downstream_consumption", {})
if downstream.get("design_preflight", {}).get("status") != "PASS":
    raise SystemExit("design preflight evidence must be PASS")
if downstream.get("design_preflight", {}).get("unit_count") != 1:
    raise SystemExit("design preflight evidence must expose exactly one UNIT")

proof_text = "\n".join(item.get("command", "") for item in result.get("proof_commands", []))
for needle in (
    "product-manager/scripts/preflight_check.sh",
    "product-manager/scripts/completion_check.sh",
    "design/scripts/preflight_check.sh",
    "validate_standard_chain_phase.py",
    "check_skill_package_quality.py shared/skills/product-manager",
):
    if needle not in proof_text:
        raise SystemExit(f"dogfood proof command missing {needle}")
for proof in result.get("proof_commands", []):
    if proof.get("status") != "pass":
        raise SystemExit(f"dogfood proof command not pass: {proof}")

target_review = result.get("target_review", {})
for field in (
    "returned_to_practice_flow",
    "downstream_consumable",
    "deterministic_checks_are_fresh",
    "open_risks_recorded",
):
    if target_review.get(field) is not True:
        raise SystemExit(f"target_review.{field} must be true")

if fidelity.get("artifact_type") != "product-manager-anchor-fidelity":
    raise SystemExit("anchor fidelity artifact_type drift")
if fidelity.get("result_ref") != "shared/skills/product-manager/evals/dogfood/request-review-flow/with_skill/dogfood-result.json":
    raise SystemExit("anchor fidelity result_ref drift")
if fidelity.get("expected_anchor_count") != 7 or fidelity.get("passed_anchor_count") != 7:
    raise SystemExit("anchor fidelity count drift")
if float(fidelity.get("fidelity")) != 1.0:
    raise SystemExit("anchor fidelity must be 1.0")
expected_anchors = {
    "handoff-director-baseline",
    "unit-closed-loop",
    "ac-traceable",
    "review-fail-warn-closure",
    "director-lock-no-drift",
    "delivery-confirmation",
    "pm-recommendation-first",
}
anchors = {item.get("anchor_id") for item in fidelity.get("anchors", []) if item.get("passed") is True}
if anchors != expected_anchors:
    raise SystemExit(f"anchor fidelity missing anchors: {sorted(expected_anchors - anchors)}")
for item in fidelity.get("anchors", []):
    if not str(item.get("evidence", "")).strip():
        raise SystemExit(f"anchor missing evidence: {item}")

evidence_refs = set(review.get("evidence_refs", []))
required_refs = {
    "shared/skills/product-manager/evals/dogfood/request-review-flow/with_skill/dogfood-result.json",
    "shared/skills/product-manager/evals/dogfood/request-review-flow/with_skill/anchor-fidelity.json",
}
if not required_refs.issubset(evidence_refs):
    raise SystemExit(f"lifecycle review missing dogfood evidence refs: {sorted(required_refs - evidence_refs)}")
production = review.get("production_evidence", {})
if production.get("measurement_status") != "fixture_dogfood_recorded":
    raise SystemExit("lifecycle review must record fixture_dogfood_recorded")
if production.get("dogfood_ref") != "shared/skills/product-manager/evals/dogfood/request-review-flow/with_skill/dogfood-result.json":
    raise SystemExit("lifecycle review dogfood_ref drift")
if production.get("anchor_fidelity_ref") != "shared/skills/product-manager/evals/dogfood/request-review-flow/with_skill/anchor-fidelity.json":
    raise SystemExit("lifecycle review anchor_fidelity_ref drift")
if production.get("downstream_design_preflight") != "PASS":
    raise SystemExit("lifecycle review must record downstream design preflight PASS")
PY
}

assert_file "$PREFLIGHT"
assert_file "$COMPLETION"
assert_file "$DESIGN_PREFLIGHT"
assert_file "$PHASE_VALIDATOR"
assert_file "$PACKAGE_AUDIT"
assert_file "$RESULT"
assert_file "$ANCHOR_FIDELITY"
assert_file "$LIFECYCLE"
assert_file "$SOURCE_FEATURE/brief.json"
assert_file "$SOURCE_FEATURE/phase-1/phase-prd.json"
assert_file "$SOURCE_FEATURE/phase-1/units/UNIT-1.json"
assert_dogfood_result_contract

WORKSPACE="$TMP_ROOT/positive"
prepare_workspace "$WORKSPACE"
PHASE_DIR="$WORKSPACE/docs/request-review-flow/phase-1"

bash "$PREFLIGHT" --phase-dir "$PHASE_DIR" >"$TMP_ROOT/preflight.json"
jq -e '
  .status == "PASS"
  and .phase_id == "phase-1"
  and (.brief | endswith("docs/request-review-flow/brief.json"))
  and (.phase_prd | endswith("docs/request-review-flow/phase-1/phase-prd.json"))
' "$TMP_ROOT/preflight.json" >/dev/null || fail "product-manager preflight did not pass on dogfood workspace"

python3 "$PHASE_VALIDATOR" --phase-dir "$PHASE_DIR" >"$TMP_ROOT/phase-validator.out"

run_manager_hook "$WORKSPACE"
[ "$(cat "$WORKSPACE/hook.status")" = "0" ] || {
  cat "$WORKSPACE/hook.stderr" >&2
  fail "product-manager completion gate rejected dogfood workspace"
}
assert_present '"decision":"allow"|\"decision\": \"allow\"' "$WORKSPACE/hook.stdout" "product-manager dogfood hook stdout"

bash "$DESIGN_PREFLIGHT" --phase-dir "$PHASE_DIR" >"$TMP_ROOT/design-preflight.json"
jq -e '.status == "PASS" and .unit_count == 1' "$TMP_ROOT/design-preflight.json" >/dev/null || fail "design preflight could not consume PM dogfood artifacts"

python3 "$PACKAGE_AUDIT" "$ROOT/shared/skills/product-manager" >"$TMP_ROOT/package-audit.json"
jq -e '
  .status == "static_pass"
  and .finding_count == 0
' "$TMP_ROOT/package-audit.json" >/dev/null || fail "product-manager package audit did not pass"

NO_DELIVERY="$TMP_ROOT/no-delivery"
prepare_workspace "$NO_DELIVERY"
jq 'del(.delivery_confirmation)' \
  "$NO_DELIVERY/docs/request-review-flow/brief.json" \
  >"$NO_DELIVERY/docs/request-review-flow/brief.tmp.json"
mv "$NO_DELIVERY/docs/request-review-flow/brief.tmp.json" "$NO_DELIVERY/docs/request-review-flow/brief.json"
if bash "$DESIGN_PREFLIGHT" --phase-dir "$NO_DELIVERY/docs/request-review-flow/phase-1" >"$TMP_ROOT/no-delivery.out" 2>"$TMP_ROOT/no-delivery.err"; then
  fail "design preflight accepted PM artifacts without delivery_confirmation"
fi
assert_present 'UPSTREAM_NOT_READY|delivery_confirmation' "$TMP_ROOT/no-delivery.out" "no-delivery design preflight output"

printf '[PASS] product-manager dogfood e2e\n'
