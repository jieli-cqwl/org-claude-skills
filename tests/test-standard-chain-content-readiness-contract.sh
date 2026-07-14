#!/usr/bin/env bash
# File role: prove the evaluation-only content-readiness contract fails closed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATOR="$ROOT/tools/eval/scripts/validate_standard_chain_content_readiness.py"
FIXTURE="$ROOT/tests/fixtures/standard-chain-content-readiness/product-director-blocked-isolation"
BUILDER="$FIXTURE/fixture_builder.py"
TEMPLATE="$FIXTURE/fixture-template.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

should_run() {
  [[ -z "${SCCR_ONLY:-}" || "${SCCR_ONLY}" == "$1" ]]
}

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/standard-chain-content-readiness.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT

descriptor="$tmpdir/source-descriptor.json"
python3 "$BUILDER" init-sources \
  --output-root "$tmpdir/sources" \
  --descriptor "$descriptor"

read_descriptor() {
  python3 - "$descriptor" "$1" "$2" <<'PY'
import json
import sys
from pathlib import Path

value = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
print(value[sys.argv[2]][sys.argv[3]])
PY
}

app_root="$(read_descriptor synthetic-app root)"
app_baseline="$(read_descriptor synthetic-app baseline)"
app_result="$(read_descriptor synthetic-app result)"
backend_root="$(read_descriptor synthetic-backend root)"
backend_baseline="$(read_descriptor synthetic-backend baseline)"
backend_result="$(read_descriptor synthetic-backend result)"

# The first RED reaches this boundary after creating portable source histories.
# Before implementation it must fail only because the validator is absent.
python3 "$VALIDATOR" \
  --emit-source-denominator \
  --source-id synthetic-app \
  --source-root "synthetic-app=$app_root" \
  --baseline "$app_baseline" \
  --result "$app_result" >"$tmpdir/app-denominator.json"
python3 "$VALIDATOR" \
  --emit-source-denominator \
  --source-id synthetic-backend \
  --source-root "synthetic-backend=$backend_root" \
  --baseline "$backend_baseline" \
  --result "$backend_result" >"$tmpdir/backend-denominator.json"

run_root="$tmpdir/valid-run"
runtime_root="$tmpdir/inherited-runtime"
source_roots="$tmpdir/source-roots.json"
python3 "$BUILDER" build \
  --repo-root "$ROOT" \
  --template "$TEMPLATE" \
  --run-root "$run_root" \
  --runtime-root "$runtime_root" \
  --descriptor "$descriptor" \
  --denominator "$tmpdir/app-denominator.json" \
  --denominator "$tmpdir/backend-denominator.json" \
  --source-roots-output "$source_roots"

validator_args=(
  "$VALIDATOR"
  "$run_root"
  --require-role product-director
  --require-stage role-verdict
  --source-root "synthetic-app=$app_root"
  --source-root "synthetic-backend=$backend_root"
  --source-root "synthetic-runtime=$runtime_root"
)

positive_output="$tmpdir/positive.json"
python3 "${validator_args[@]}" >"$positive_output"
python3 - "$positive_output" <<'PY'
import json
import sys
from pathlib import Path

value = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if value.get("status") != "PASS":
    raise SystemExit(f"positive fixture did not pass: {value}")
if value.get("checked_stage") != "role-verdict":
    raise SystemExit(f"wrong checked stage: {value.get('checked_stage')}")
if value.get("failures") != []:
    raise SystemExit(f"positive fixture has failures: {value.get('failures')}")
PY

refresh_case() {
  local case_root="$1"
  python3 "$BUILDER" refresh \
    --repo-root "$ROOT" \
    --run-root "$case_root" \
    --source-roots "$source_roots"
}

expect_failure() {
  local mutation="$1" expected="$2" refresh="${3:-yes}" stage="${4:-role-verdict}"
  if ! should_run "$mutation"; then
    return
  fi
  local case_root="$tmpdir/negative-$mutation" output="$tmpdir/negative-$mutation.json"
  local error="$tmpdir/negative-$mutation.stderr"
  cp -R "$run_root" "$case_root"
  python3 "$BUILDER" mutate --run-root "$case_root" --name "$mutation"
  if [[ "$refresh" == "yes" ]]; then
    refresh_case "$case_root"
  fi
  if python3 "$VALIDATOR" "$case_root" \
    --require-role product-director \
    --require-stage "$stage" \
    --source-root "synthetic-app=$app_root" \
    --source-root "synthetic-backend=$backend_root" \
    --source-root "synthetic-runtime=$runtime_root" >"$output" 2>"$error"; then
    fail "$mutation unexpectedly passed"
  fi
  if [[ -s "$error" ]]; then
    fail "$mutation leaked non-JSON stderr: $(<"$error")"
  fi
  python3 - "$output" "$expected" "$mutation" <<'PY'
import json
import sys
from pathlib import Path

value = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
expected = sys.argv[2]
haystack = json.dumps(
    {
        "failures": value.get("failures", []),
        "invoked_validators": value.get("invoked_validators", []),
    },
    ensure_ascii=False,
)
if value.get("status") != "FAIL" or expected not in haystack:
    raise SystemExit(
        f"{sys.argv[3]}: expected rejection {expected!r}, observed {value}"
    )
PY
}

expect_success_variant() {
  local mutation="$1" stage="${2:-role-verdict}"
  if ! should_run "$mutation"; then
    return
  fi
  local case_root="$tmpdir/positive-$mutation" output="$tmpdir/positive-$mutation.json"
  local error="$tmpdir/positive-$mutation.stderr"
  cp -R "$run_root" "$case_root"
  python3 "$BUILDER" mutate --run-root "$case_root" --name "$mutation"
  refresh_case "$case_root"
  if ! python3 "$VALIDATOR" "$case_root" \
    --require-role product-director \
    --require-stage "$stage" \
    --source-root "synthetic-app=$app_root" \
    --source-root "synthetic-backend=$backend_root" \
    --source-root "synthetic-runtime=$runtime_root" >"$output" 2>"$error"; then
    fail "$mutation legal variant failed: $(<"$output") $(<"$error")"
  fi
  python3 - "$output" "$stage" "$mutation" <<'PY'
import json
import sys
from pathlib import Path

value = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if value.get("status") != "PASS" or value.get("checked_stage") != sys.argv[2]:
    raise SystemExit(f"{sys.argv[3]}: legal variant did not pass: {value}")
PY
}

expect_divergent_source_failure() {
  if ! should_run "source_divergent_history"; then
    return
  fi
  local tree divergent output error
  tree="$(git -C "$app_root" rev-parse "$app_baseline^{tree}")"
  divergent="$(printf 'divergent fixture root\n' | git -C "$app_root" commit-tree "$tree")"
  output="$tmpdir/source-divergent-history.json"
  error="$tmpdir/source-divergent-history.stderr"
  if python3 "$VALIDATOR" \
    --emit-source-denominator \
    --source-id synthetic-app \
    --source-root "synthetic-app=$app_root" \
    --baseline "$divergent" \
    --result "$app_result" >"$output" 2>"$error"; then
    fail "source_divergent_history unexpectedly passed"
  fi
  if [[ -s "$error" ]]; then
    fail "source_divergent_history leaked non-JSON stderr: $(<"$error")"
  fi
  python3 - "$output" <<'PY'
import json
import sys
from pathlib import Path

value = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if value.get("status") != "FAIL" or "source classification denominator mismatch" not in json.dumps(value):
    raise SystemExit(f"divergent source history was not rejected structurally: {value}")
PY
}

expect_failure absolute_path "artifact path must be relative"
expect_failure parent_escape "artifact path must not escape its scope"
expect_failure wrong_scope "schema validation failed"
expect_failure missing_source_root "missing external_repo source-root mapping"
expect_failure stale_file_sha "stale file SHA-256" no
expect_failure stale_approval "stale approval reference"
expect_failure stale_proxy_digest "stale business proxy baseline digest"
expect_failure stale_runtime_digest "stale inherited runtime digest"
expect_failure stale_starting_input "stale starting input digest"

expect_failure source_missing_commit "source classification denominator mismatch"
expect_failure source_wrong_parent "source classification denominator mismatch"
expect_failure source_missing_rename_previous "source classification denominator mismatch"
expect_failure source_duplicate_atom "source classification denominator mismatch"
expect_divergent_source_failure

expect_failure lane_starting_input "lane starting input mismatch"
expect_failure business_answer_drift "business proxy answer drift"
expect_failure business_message_drift "business proxy answer drift"
expect_failure unresolved_runtime "unresolved runtime input cannot claim complete digest"
expect_failure unauthorized_read "unauthorized executor read"
expect_failure contaminated_decisive "contaminated attempt cannot be decisive"
expect_failure attempt_limit "attempt limit exceeded"
expect_failure attempt_history_gap "attempt history must be immutable and contiguous"
expect_failure completed_after_completed "attempt terminality violation"
expect_failure completed_after_stopped "attempt terminality violation"
expect_failure infra_decisive "infrastructure failure cannot be decisive"
expect_failure infra_nondecisive_outputs "infrastructure failure cannot have outputs"
expect_failure content_pass_declared "CONTENT_PASS requires ENFORCED or OBSERVED"
expect_failure isolation_spoof_pass "effective isolation requires BLOCKED_ISOLATION"
expect_failure missing_baseline "missing baseline digest is not legally blocked"
expect_failure partial_baseline "missing baseline digest is not legally blocked"
expect_failure bridge_pass "authentic role pass cannot depend on oracle bridge"
expect_failure canonical_metadata "canonical artifact contains evaluation metadata"
expect_failure child_report_failure "skill audit report validator failed"
expect_failure child_alignment_failure "skill audit alignment validator failed"
expect_failure early_chain_verdict "chain verdict requires all primary roles"
expect_failure replay_pass_state_only "CASE_REPLAY_PASS requires six CONTENT_PASS roles, chain verdict, ENFORCED/OBSERVED and no bridge"
expect_failure unsupported_role_verdict "unsupported verdict"
expect_failure unsupported_chain_verdict "unsupported verdict"
expect_failure ghost_staged_file "staged manifest entry does not match real bytes"
expect_failure relative_staging_root "attempt environment roots are inconsistent"
expect_failure cross_case_identity "artifact identity mismatch"
expect_failure cross_role_identity "artifact identity mismatch"
expect_failure wrong_lane_identity "artifact identity mismatch"
expect_failure wrong_attempt_identity "artifact identity mismatch"
expect_failure input_oracle_version_drift "oracle version mismatch"
expect_failure attempt_oracle_version_drift "oracle version mismatch"
expect_failure schema_invalid_case_refs "schema validation failed"
expect_failure not_run_placeholder "schema validation failed"
expect_failure role_global_mismatch "DECLARED_ONLY run requires BLOCKED_ISOLATION global state"
expect_failure branch_a_one_contaminated "Branch A requires exactly three contaminated attempts in one lane" yes terminal-run
expect_failure branch_a_two_contaminated "Branch A requires exactly three contaminated attempts in one lane" yes terminal-run
expect_failure branch_a_missing_contamination_evidence "Branch A contamination evidence is incomplete" yes terminal-run
expect_failure branch_b_missing_verdict "Branch B requires blocked role verdict and primary outcome" yes terminal-run
expect_failure branch_b_missing_outcome "Branch B requires blocked role verdict and primary outcome" yes terminal-run
expect_failure branch_b_missing_typed_evidence "Branch B blocker evidence is incomplete" yes terminal-run
expect_failure branch_b_diagnostic_missing_blocker "Branch B blocker evidence is incomplete" yes terminal-run
expect_failure branch_b_admission_isolation_unknown "Branch B admission requires derivable isolation" yes terminal-run
expect_failure branch_b_admission_unproven_baseline_spoof "Branch B admission cannot claim unproven baseline digests" yes terminal-run
expect_failure branch_b_admission_observed_spoof "effective isolation evidence mismatch" yes terminal-run
expect_failure open_static_future_artifacts "OPEN stage artifact set mismatch" yes static-audit
expect_failure open_diagnostic_missing_review "OPEN stage artifact set mismatch" yes diagnostic-replay
expect_failure open_diagnostic_one_lane "OPEN diagnostic requires two decisive lanes and three reviews" yes diagnostic-replay
expect_failure branch_d_missing_reviews "Branch D requires two decisive lanes and three reviews"
expect_failure unindexed_present_artifact "run.role_refs does not match present stage artifacts"
expect_failure duplicate_role_ref "run.role_refs does not match present stage artifacts"
expect_failure duplicate_decisive_attempt_ref "role verdict contains duplicate refs"
expect_failure duplicate_verdict_evidence_ref "role verdict contains duplicate refs"
expect_failure invalid_next_authorized_action "schema validation failed"
expect_failure branch_b_admission_legacy_tokens "schema validation failed" yes terminal-run
expect_failure verdict_evidence_incomplete "role verdict evidence graph is incomplete"
expect_failure stopped_canonical_residue "stopped attempt cannot retain canonical files"
expect_failure terminal_empty "terminal-run requires explicit terminal evidence" yes terminal-run
expect_failure branch_c_no_p0_p1 "Branch C requires blocking P0/P1 evidence"

expect_success_variant direct_static_content_fail
expect_success_variant branch_d_content_fail
expect_success_variant branch_d_blocked_oracle
expect_success_variant branch_d_blocked_evidence
expect_success_variant branch_d_blocked_isolation
expect_success_variant branch_b_admission terminal-run
expect_success_variant branch_b_admission_approved_tokens terminal-run
expect_success_variant branch_b_static terminal-run
expect_success_variant branch_b_diagnostic terminal-run
expect_success_variant branch_a_single_lane_triple terminal-run
expect_success_variant open_static static-audit
expect_success_variant open_diagnostic diagnostic-replay
expect_success_variant immutable_retry_history

stopped_root="$tmpdir/stopped-run"
stopped_output="$tmpdir/stopped-output.json"
cp -R "$run_root" "$stopped_root"
python3 "$BUILDER" mutate --run-root "$stopped_root" --name stopped_attempts
refresh_case "$stopped_root"
python3 "$VALIDATOR" "$stopped_root" \
  --require-role product-director \
  --require-stage role-verdict \
  --source-root "synthetic-app=$app_root" \
  --source-root "synthetic-backend=$backend_root" \
  --source-root "synthetic-runtime=$runtime_root" >"$stopped_output"
python3 - "$stopped_output" <<'PY'
import json
import sys
from pathlib import Path

value = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if value.get("status") != "PASS":
    raise SystemExit(f"correctly stopped attempts must pass: {value}")
names = [item.get("name", "") for item in value.get("invoked_validators", [])]
if any(name.startswith("product-director-canonical-") for name in names):
    raise SystemExit(f"stopped attempt invoked canonical gates: {names}")
PY

duplicate_output="$tmpdir/duplicate-source-root.json"
if python3 "$VALIDATOR" "$run_root" \
  --source-root "synthetic-app=$app_root" \
  --source-root "synthetic-app=$app_root" >"$duplicate_output"; then
  fail "duplicate source-root IDs unexpectedly passed"
fi
python3 - "$duplicate_output" <<'PY'
import json
import sys
from pathlib import Path

value = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if "duplicate --source-root ID" not in json.dumps(value.get("failures", [])):
    raise SystemExit(f"duplicate source-root error not surfaced: {value}")
PY

printf '[PASS] standard-chain content-readiness evaluation contract\n'
