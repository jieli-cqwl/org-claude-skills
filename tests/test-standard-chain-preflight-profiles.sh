#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATOR="$ROOT/tools/community/validate_failure_routing_contract.py"
FIXTURE="$ROOT/tests/fixtures/standard-chain-pilots/login-homepage-pilot"
PHASE_DIR="$FIXTURE/phase-1"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

roles=(
  product-director
  product-manager
  design
  test-design
  tech-lead
  delivery-owner
  developer
  verify
  review
  qa
)

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

validate_result_json() {
  local payload="$1"
  python3 "$VALIDATOR" --repo-root "$ROOT" --result-json "$payload" >/dev/null
}

json_field() {
  local payload="$1"
  local field="$2"
  python3 - "$payload" "$field" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
print(payload[sys.argv[2]])
PY
}

run_direct() {
  local out="$1"
  local err="$2"
  shift 2
  set +e
  "$@" >"$out" 2>"$err"
  printf '%s' "$?" >"$out.rc"
  set -e
  cat "$out"
}

assert_result() {
  local payload="$1"
  local expected_status="$2"
  local expected_code="$3"
  validate_result_json "$payload"
  [[ "$(json_field "$payload" status)" == "$expected_status" ]] || fail "expected status $expected_status, got $payload"
  [[ "$(json_field "$payload" failure_code)" == "$expected_code" ]] || fail "expected failure_code $expected_code, got $payload"
}

run_core() {
  local role="$1"
  shift
  local out="$TMP_DIR/core-${role}.json"
  local rc_file="$TMP_DIR/core-${role}.rc"
  set +e
  "$ROOT/shared/skills/$role/scripts/check_preflight.sh" "$@" >"$out"
  printf '%s' "$?" >"$rc_file"
  set -e
  cat "$out"
}

run_adapter() {
  local role="$1"
  local payload="$2"
  local out="$TMP_DIR/adapter-${role}.json"
  local rc_file="$TMP_DIR/adapter-${role}.rc"
  set +e
  "$ROOT/shared/skills/$role/scripts/preflight_check.sh" <<<"$payload" >"$out"
  printf '%s' "$?" >"$rc_file"
  set -e
  cat "$out"
}

core_args_for_role() {
  local role="$1"
  case "$role" in
    product-director)
      printf '%s\n' --feature "$FIXTURE"
      ;;
    product-manager|design|tech-lead|delivery-owner|review|qa)
      printf '%s\n' --feature "$FIXTURE" --phase-dir "$PHASE_DIR"
      ;;
    test-design)
      printf '%s\n' --feature "$FIXTURE" --phase-dir "$PHASE_DIR" --unit UNIT-1
      ;;
    developer|verify)
      printf '%s\n' --feature "$FIXTURE" --phase-dir "$PHASE_DIR" --unit UNIT-1 --task-id T1
      ;;
    *)
      fail "unknown role $role"
      ;;
  esac
}

adapter_payload_for_role() {
  local role="$1"
  python3 - "$role" "$FIXTURE" "$PHASE_DIR" <<'PY'
import json
import sys

role, feature, phase_dir = sys.argv[1:]
target = {"feature": feature}
if role != "product-director":
    target["phase_dir"] = phase_dir
if role == "test-design":
    target["unit"] = "UNIT-1"
if role in {"developer", "verify"}:
    target["unit"] = "UNIT-1"
    target["task_id"] = "T1"
print(json.dumps({"skill": role, "standard_chain": target}, sort_keys=True))
PY
}

copy_fixture() {
  local target="$1"
  cp -R "$FIXTURE" "$target"
}

snapshot_tree() {
  local tree="$1"
  local out="$2"
  python3 - "$tree" "$out" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
snapshot = {}
for path in sorted(p for p in root.rglob("*") if p.is_file()):
    rel = path.relative_to(root).as_posix()
    snapshot[rel] = hashlib.sha256(path.read_bytes()).hexdigest()
Path(sys.argv[2]).write_text(json.dumps(snapshot, sort_keys=True, indent=2) + "\n", encoding="utf-8")
PY
}

for role in "${roles[@]}"; do
  [[ -x "$ROOT/shared/skills/$role/scripts/check_preflight.sh" ]] || fail "$role missing executable scripts/check_preflight.sh"
  [[ -x "$ROOT/shared/skills/$role/scripts/preflight_check.sh" ]] || fail "$role missing executable scripts/preflight_check.sh"

  args=()
  while IFS= read -r arg; do
    args+=("$arg")
  done < <(core_args_for_role "$role")
  positive="$(run_core "$role" "${args[@]}")"
  assert_result "$positive" PASS NONE

  payload="$(adapter_payload_for_role "$role")"
  adapted="$(run_adapter "$role" "$payload")"
  assert_result "$adapted" PASS NONE

  python3 - "$positive" "$adapted" <<'PY'
import json
import sys

core = json.loads(sys.argv[1])
adapter = json.loads(sys.argv[2])
for key in ["schema_version", "status", "stage", "failure_code", "owner", "next_action", "safe_to_continue", "human_decision_required", "continuation_condition"]:
    if core[key] != adapter[key]:
        raise SystemExit(f"adapter/core routing drift on {key}: {core[key]!r} != {adapter[key]!r}")
PY
done

director_workspace="$TMP_DIR/director-entry-without-brief"
mkdir -p "$director_workspace"
director_payload="$(run_core product-director --feature "$director_workspace")"
assert_result "$director_payload" PASS NONE
[[ ! -e "$director_workspace/brief.json" ]] || fail "Director preflight created brief.json"

missing_fixture="$TMP_DIR/missing-artifact"
copy_fixture "$missing_fixture"
rm "$missing_fixture/phase-1/plan.json"
missing_payload="$(run_core delivery-owner --feature "$missing_fixture" --phase-dir "$missing_fixture/phase-1")"
assert_result "$missing_payload" BLOCKED MISSING_ARTIFACT

malformed_fixture="$TMP_DIR/malformed-artifact"
copy_fixture "$malformed_fixture"
printf '{not-json\n' >"$malformed_fixture/phase-1/design.json"
malformed_payload="$(run_core test-design --feature "$malformed_fixture" --phase-dir "$malformed_fixture/phase-1" --unit UNIT-1)"
assert_result "$malformed_payload" BLOCKED MALFORMED_ARTIFACT

malformed_shape_fixture="$TMP_DIR/malformed-shape-artifact"
copy_fixture "$malformed_shape_fixture"
python3 -c 'import json,sys; from pathlib import Path; p=Path(sys.argv[1]); d=json.loads(p.read_text(encoding="utf-8")); d["review_conclusion"]="PASS"; p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")' "$malformed_shape_fixture/phase-1/phase-prd.json"
malformed_shape_payload="$(run_core design --feature "$malformed_shape_fixture" --phase-dir "$malformed_shape_fixture/phase-1")"
assert_result "$malformed_shape_payload" BLOCKED MISSING_HUMAN_CONFIRMATION
malformed_shape_adapter_payload="$(run_adapter design "{\"standard_chain\":{\"feature\":\"$malformed_shape_fixture\",\"phase_dir\":\"$malformed_shape_fixture/phase-1\"}}")"
assert_result "$malformed_shape_adapter_payload" BLOCKED MISSING_HUMAN_CONFIRMATION

unreadable_fixture="$TMP_DIR/unreadable-artifact"
copy_fixture "$unreadable_fixture"
chmod 000 "$unreadable_fixture/phase-1/design.json"
unreadable_payload="$(run_core test-design --feature "$unreadable_fixture" --phase-dir "$unreadable_fixture/phase-1" --unit UNIT-1)"
assert_result "$unreadable_payload" BLOCKED MALFORMED_ARTIFACT
unreadable_adapter_payload="$(run_adapter test-design "{\"standard_chain\":{\"feature\":\"$unreadable_fixture\",\"phase_dir\":\"$unreadable_fixture/phase-1\",\"unit\":\"UNIT-1\"}}")"
assert_result "$unreadable_adapter_payload" BLOCKED MALFORMED_ARTIFACT
chmod 644 "$unreadable_fixture/phase-1/design.json"

readonly_parent="$TMP_DIR/readonly-parent"
mkdir -p "$readonly_parent"
chmod 555 "$readonly_parent"
readonly_workspace_payload="$(run_core product-director --feature "$readonly_parent/new-feature")"
assert_result "$readonly_workspace_payload" BLOCKED UNAUTHORIZED_SCOPE
chmod 755 "$readonly_parent"

workspace_file="$TMP_DIR/workspace-file"
touch "$workspace_file"
workspace_file_payload="$(run_core product-director --feature "$workspace_file")"
assert_result "$workspace_file_payload" BLOCKED UNAUTHORIZED_SCOPE
workspace_file_adapter_payload="$(run_adapter product-director "{\"standard_chain\":{\"feature\":\"$workspace_file\"}}")"
assert_result "$workspace_file_adapter_payload" BLOCKED UNAUTHORIZED_SCOPE

ambiguous_registry_fixture="$TMP_DIR/ambiguous-registry"
copy_fixture "$ambiguous_registry_fixture"
printf '{}\n' >"$ambiguous_registry_fixture/phase-1/artifact-registry.json"
ambiguous_registry_payload="$(run_core delivery-owner --feature "$ambiguous_registry_fixture" --phase-dir "$ambiguous_registry_fixture/phase-1")"
assert_result "$ambiguous_registry_payload" BLOCKED AMBIGUOUS_TARGET

malformed_registry_fixture="$TMP_DIR/malformed-registry"
copy_fixture "$malformed_registry_fixture"
printf '{"active_revision_id":"rev-bad","revisions":[{"revision_id":"rev-bad","entries":[{}]}]}\n' >"$malformed_registry_fixture/phase-1/artifact-registry.json"
malformed_registry_payload="$(run_core delivery-owner --feature "$malformed_registry_fixture" --phase-dir "$malformed_registry_fixture/phase-1")"
assert_result "$malformed_registry_payload" BLOCKED AMBIGUOUS_TARGET

inactive_registry_fixture="$TMP_DIR/inactive-registry"
copy_fixture "$inactive_registry_fixture"
python3 -c 'import json,sys; from pathlib import Path; p=Path(sys.argv[1]); d=json.loads(p.read_text(encoding="utf-8")); d["active_revision_id"]="rev-inactive"; d["revisions"]=[{"revision_id":"rev-inactive","entries":[{"scope_ref":"artifact://plan/example@v1#root","artifact_id":"example.plan","artifact_type":"plan","version":"v1","artifact_path":"plan.json","lifecycle_state":"SUPERSEDED","active_for_consumption":False,"produced_by":"delivery-owner"}]}]; p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")' "$inactive_registry_fixture/phase-1/artifact-registry.json"
inactive_registry_payload="$(run_core delivery-owner --feature "$inactive_registry_fixture" --phase-dir "$inactive_registry_fixture/phase-1")"
assert_result "$inactive_registry_payload" BLOCKED AMBIGUOUS_TARGET

partial_registry_fixture="$TMP_DIR/partial-registry"
copy_fixture "$partial_registry_fixture"
python3 -c 'import json,sys; from pathlib import Path; p=Path(sys.argv[1]); d=json.loads(p.read_text(encoding="utf-8")); rev=next(r for r in d["revisions"] if r["revision_id"]==d["active_revision_id"]); [e.update({"active_for_consumption":False,"lifecycle_state":"SUPERSEDED"}) for e in rev["entries"] if e.get("artifact_type") in {"plan","tasks","test-cases"}]; p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")' "$partial_registry_fixture/phase-1/artifact-registry.json"
partial_registry_payload="$(run_core delivery-owner --feature "$partial_registry_fixture" --phase-dir "$partial_registry_fixture/phase-1")"
assert_result "$partial_registry_payload" BLOCKED AMBIGUOUS_TARGET

missing_registry_target_fixture="$TMP_DIR/missing-registry-target"
copy_fixture "$missing_registry_target_fixture"
python3 -c 'import json,sys; from pathlib import Path; p=Path(sys.argv[1]); d=json.loads(p.read_text(encoding="utf-8")); rev=next(r for r in d["revisions"] if r["revision_id"]==d["active_revision_id"]); [e.pop("artifact_path",None) for e in rev["entries"] if e.get("artifact_type") in {"plan","tasks","test-cases"}]; p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")' "$missing_registry_target_fixture/phase-1/artifact-registry.json"
missing_registry_target_payload="$(run_core delivery-owner --feature "$missing_registry_target_fixture" --phase-dir "$missing_registry_target_fixture/phase-1")"
assert_result "$missing_registry_target_payload" BLOCKED MISSING_ARTIFACT

registry_dir_target_fixture="$TMP_DIR/registry-dir-target"
copy_fixture "$registry_dir_target_fixture"
python3 -c 'import json,sys; from pathlib import Path; p=Path(sys.argv[1]); d=json.loads(p.read_text(encoding="utf-8")); rev=next(r for r in d["revisions"] if r["revision_id"]==d["active_revision_id"]); next(e for e in rev["entries"] if e.get("artifact_type")=="plan").update({"artifact_path":"unit-1"}); p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")' "$registry_dir_target_fixture/phase-1/artifact-registry.json"
registry_dir_target_payload="$(run_core delivery-owner --feature "$registry_dir_target_fixture" --phase-dir "$registry_dir_target_fixture/phase-1")"
assert_result "$registry_dir_target_payload" BLOCKED MALFORMED_ARTIFACT

qa_registry_dir_fixture="$TMP_DIR/qa-registry-dir-target"
copy_fixture "$qa_registry_dir_fixture"
python3 -c 'import json,sys; from pathlib import Path; p=Path(sys.argv[1]); d=json.loads(p.read_text(encoding="utf-8")); rev=next(r for r in d["revisions"] if r["revision_id"]==d["active_revision_id"]); next(e for e in rev["entries"] if e.get("artifact_type")=="code-review-result").update({"artifact_path":"unit-1"}); p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")' "$qa_registry_dir_fixture/phase-1/artifact-registry.json"
qa_registry_dir_payload="$(run_core qa --feature "$qa_registry_dir_fixture" --phase-dir "$qa_registry_dir_fixture/phase-1")"
assert_result "$qa_registry_dir_payload" BLOCKED MALFORMED_ARTIFACT

registry_escape_fixture="$TMP_DIR/registry-escape"
copy_fixture "$registry_escape_fixture"
ln -s "$ROOT/shared/runtime/standard-chain-preflight-profiles.json" "$registry_escape_fixture/phase-1/plan-link.json"
python3 -c 'import json,sys; from pathlib import Path; p=Path(sys.argv[1]); d=json.loads(p.read_text(encoding="utf-8")); rev=next(r for r in d["revisions"] if r["revision_id"]==d["active_revision_id"]); next(e for e in rev["entries"] if e.get("artifact_type")=="plan").update({"artifact_path":"plan-link.json"}); p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")' "$registry_escape_fixture/phase-1/artifact-registry.json"
registry_escape_payload="$(run_core delivery-owner --feature "$registry_escape_fixture" --phase-dir "$registry_escape_fixture/phase-1")"
assert_result "$registry_escape_payload" BLOCKED UNAUTHORIZED_SCOPE

qa_registry_escape_fixture="$TMP_DIR/qa-registry-escape"
copy_fixture "$qa_registry_escape_fixture"
ln -s "$ROOT/shared/runtime/standard-chain-preflight-profiles.json" "$qa_registry_escape_fixture/phase-1/review-link.json"
python3 -c 'import json,sys; from pathlib import Path; p=Path(sys.argv[1]); d=json.loads(p.read_text(encoding="utf-8")); rev=next(r for r in d["revisions"] if r["revision_id"]==d["active_revision_id"]); next(e for e in rev["entries"] if e.get("artifact_type")=="code-review-result").update({"artifact_path":"review-link.json"}); p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")' "$qa_registry_escape_fixture/phase-1/artifact-registry.json"
qa_registry_escape_payload="$(run_core qa --feature "$qa_registry_escape_fixture" --phase-dir "$qa_registry_escape_fixture/phase-1")"
assert_result "$qa_registry_escape_payload" BLOCKED UNAUTHORIZED_SCOPE

missing_review_evidence_fixture="$TMP_DIR/missing-review-evidence"
copy_fixture "$missing_review_evidence_fixture"
rm "$missing_review_evidence_fixture/phase-1/unit-1/tasks/T2/developer-report.json" "$missing_review_evidence_fixture/phase-1/unit-1/tasks/T2/verify-result.json"
missing_review_evidence_payload="$(run_core review --feature "$missing_review_evidence_fixture" --phase-dir "$missing_review_evidence_fixture/phase-1")"
assert_result "$missing_review_evidence_payload" BLOCKED MISSING_ARTIFACT

malformed_review_evidence_fixture="$TMP_DIR/malformed-review-evidence"
copy_fixture "$malformed_review_evidence_fixture"
printf '{bad-json\n' >"$malformed_review_evidence_fixture/phase-1/unit-1/tasks/T2/developer-report.json"
malformed_review_evidence_payload="$(run_core review --feature "$malformed_review_evidence_fixture" --phase-dir "$malformed_review_evidence_fixture/phase-1")"
assert_result "$malformed_review_evidence_payload" BLOCKED MALFORMED_ARTIFACT

unit_mismatch_review_fixture="$TMP_DIR/unit-mismatch-review"
copy_fixture "$unit_mismatch_review_fixture"
python3 -c 'import json,sys; from pathlib import Path; p=Path(sys.argv[1]); d=json.loads(p.read_text(encoding="utf-8")); next(t for t in d["tasks"] if t["task_id"]=="T2")["unit_refs"]=["artifact://unit-definition/example.phase-1.unit-2@v1#unit"]; p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")' "$unit_mismatch_review_fixture/phase-1/tasks.json"
unit_mismatch_review_payload="$(run_core review --feature "$unit_mismatch_review_fixture" --phase-dir "$unit_mismatch_review_fixture/phase-1")"
assert_result "$unit_mismatch_review_payload" BLOCKED MISSING_ARTIFACT

stale_fixture="$TMP_DIR/stale-ref"
copy_fixture "$stale_fixture"
python3 -c 'import json,sys; from pathlib import Path; p=Path(sys.argv[1]); d=json.loads(p.read_text(encoding="utf-8")); d["baseline_plan_version_ref"]=d["baseline_plan_version_ref"].replace("@plan-v2","@plan-v1"); p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")' "$stale_fixture/phase-1/plan.json"
stale_payload="$(run_core delivery-owner --feature "$stale_fixture" --phase-dir "$stale_fixture/phase-1")"
assert_result "$stale_payload" BLOCKED STALE_EVIDENCE

ambiguous_payload='{"skill":"developer","standard_chain":{"feature":"login-homepage-pilot"},"active_targets":[{"phase_dir":"one"},{"phase_dir":"two"}]}'
ambiguous_result="$(run_adapter developer "$ambiguous_payload")"
assert_result "$ambiguous_result" BLOCKED AMBIGUOUS_TARGET

empty_payload_result="$(run_adapter product-manager '{}')"
assert_result "$empty_payload_result" BLOCKED AMBIGUOUS_TARGET

unauthorized_scope_payload="$(run_core developer --feature "$FIXTURE" --phase-dir "$PHASE_DIR" --unit UNIT-1 --task-id T1 --scope outside/repo)"
assert_result "$unauthorized_scope_payload" BLOCKED UNAUTHORIZED_SCOPE

unauthorized_artifact_payload="$(run_core developer --feature "$FIXTURE" --phase-dir "$PHASE_DIR" --unit UNIT-1 --task-id T1 --artifact evil.json)"
assert_result "$unauthorized_artifact_payload" BLOCKED UNAUTHORIZED_SCOPE

authorized_scope_payload="$(run_core developer --feature "$FIXTURE" --phase-dir "$PHASE_DIR" --unit UNIT-1 --task-id T1 --scope examples/login_homepage_app/app.py)"
assert_result "$authorized_scope_payload" PASS NONE

adapter_unauthorized_scope='{"skill":"developer","standard_chain":{"feature":"'"$FIXTURE"'","phase_dir":"'"$PHASE_DIR"'","unit":"UNIT-1","task_id":"T1","scope":"outside/repo"}}'
adapter_unauthorized_payload="$(run_adapter developer "$adapter_unauthorized_scope")"
assert_result "$adapter_unauthorized_payload" BLOCKED UNAUTHORIZED_SCOPE

shadow_parent="$TMP_DIR/cwd-shadow"
mkdir -p "$shadow_parent/rogue-feature"
copy_fixture "$shadow_parent/rogue-feature"
shadow_out="$TMP_DIR/cwd-shadow.json"
shadow_err="$TMP_DIR/cwd-shadow.err"
shadow_payload="$(
  cd "$shadow_parent"
  run_direct "$shadow_out" "$shadow_err" "$ROOT/shared/skills/product-manager/scripts/check_preflight.sh" --feature rogue-feature --phase-dir phase-1
)"
assert_result "$shadow_payload" BLOCKED MISSING_ARTIFACT

bad_profile_out="$TMP_DIR/bad-profile.json"
bad_profile_err="$TMP_DIR/bad-profile.err"
bad_profile_payload="$(run_direct "$bad_profile_out" "$bad_profile_err" env SC_PREFLIGHT_ROLE=nonexistent "$ROOT/shared/skills/product-director/scripts/check_preflight.sh" --feature "$FIXTURE")"
assert_result "$bad_profile_payload" BLOCKED MALFORMED_ARTIFACT
[[ ! -s "$bad_profile_err" ]] || fail "profile bootstrap wrote traceback to stderr"

bad_adapter_profile_out="$TMP_DIR/bad-adapter-profile.json"
bad_adapter_profile_err="$TMP_DIR/bad-adapter-profile.err"
bad_adapter_payload="$(run_direct "$bad_adapter_profile_out" "$bad_adapter_profile_err" env SC_PREFLIGHT_ROLE=nonexistent "$ROOT/shared/skills/product-director/scripts/preflight_check.sh" <<<"{}")"
assert_result "$bad_adapter_payload" BLOCKED MALFORMED_ARTIFACT
[[ ! -s "$bad_adapter_profile_err" ]] || fail "adapter profile bootstrap wrote traceback to stderr"

confirmation_fixture="$TMP_DIR/missing-human-confirmation"
copy_fixture "$confirmation_fixture"
python3 -c 'import json,sys; from pathlib import Path; p=Path(sys.argv[1]); d=json.loads(p.read_text(encoding="utf-8")); d.pop("review_conclusion",None); p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")' "$confirmation_fixture/phase-1/phase-prd.json"
confirmation_payload="$(run_core design --feature "$confirmation_fixture" --phase-dir "$confirmation_fixture/phase-1")"
assert_result "$confirmation_payload" BLOCKED MISSING_HUMAN_CONFIRMATION

timeout_payload="$(adapter_payload_for_role qa)"
timeout_result="$(
  SC_PREFLIGHT_DELAY_SECONDS=2 SC_PREFLIGHT_ADAPTER_TIMEOUT_SECONDS=1 \
    run_adapter qa "$timeout_payload"
)"
assert_result "$timeout_result" BLOCKED ADAPTER_TIMEOUT

overflow_result="$(
  SC_PREFLIGHT_ADAPTER_OUTPUT_LIMIT_BYTES=16 \
    run_adapter qa "$timeout_payload"
)"
assert_result "$overflow_result" BLOCKED ADAPTER_OUTPUT_OVERFLOW

readonly_fixture="$TMP_DIR/readonly-fixture"
copy_fixture "$readonly_fixture"
before="$TMP_DIR/readonly-before.json"
after="$TMP_DIR/readonly-after.json"
snapshot_tree "$readonly_fixture" "$before"
readonly_phase="$readonly_fixture/phase-1"
for role in "${roles[@]}"; do
  case "$role" in
    product-director)
      run_core "$role" --feature "$readonly_fixture" >/dev/null || true
      run_adapter "$role" "{\"standard_chain\":{\"feature\":\"$readonly_fixture\"}}" >/dev/null || true
      ;;
    product-manager|design|tech-lead|delivery-owner|review|qa)
      run_core "$role" --feature "$readonly_fixture" --phase-dir "$readonly_phase" >/dev/null || true
      run_adapter "$role" "{\"standard_chain\":{\"feature\":\"$readonly_fixture\",\"phase_dir\":\"$readonly_phase\"}}" >/dev/null || true
      ;;
    test-design)
      run_core "$role" --feature "$readonly_fixture" --phase-dir "$readonly_phase" --unit UNIT-1 >/dev/null || true
      run_adapter "$role" "{\"standard_chain\":{\"feature\":\"$readonly_fixture\",\"phase_dir\":\"$readonly_phase\",\"unit\":\"UNIT-1\"}}" >/dev/null || true
      ;;
    developer|verify)
      run_core "$role" --feature "$readonly_fixture" --phase-dir "$readonly_phase" --unit UNIT-1 --task-id T1 >/dev/null || true
      run_adapter "$role" "{\"standard_chain\":{\"feature\":\"$readonly_fixture\",\"phase_dir\":\"$readonly_phase\",\"unit\":\"UNIT-1\",\"task_id\":\"T1\"}}" >/dev/null || true
      ;;
  esac
done
snapshot_tree "$readonly_fixture" "$after"
cmp "$before" "$after" >/dev/null || fail "preflight checks modified fixture artifacts"

printf '[PASS] standard-chain preflight profiles\n'
