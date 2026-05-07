#!/usr/bin/env bash
# File role: prove the updated skill-refiner SOP can run a complete tech-lead optimization shadow demand.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN_DIR="$ROOT/shared/skills/skill-refiner/evals/dogfood/tech-lead-planning-owner-shadow"
TRACE="$RUN_DIR/flow-transcript.md"
ASSESSMENT="$RUN_DIR/shadow-assessment.json"
TECH_LEAD="$ROOT/shared/skills/tech-lead/SKILL.md"
RUN_ALL="$ROOT/tests/run-all.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local needle="$1"
  local file="$2"
  grep -Fq "$needle" "$file" || fail "missing required content in ${file#"$ROOT"/}: $needle"
}

assert_absent_in_sr_s2() {
  local needle="$1"
  if python3 - "$TRACE" "$needle" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
needle = sys.argv[2]
lines = path.read_text(encoding="utf-8").splitlines()
inside = False
for line in lines:
    if line.startswith("### SR-S2"):
        inside = True
        continue
    if inside and line.startswith("### "):
        break
    if inside and needle in line:
        sys.exit(0)
sys.exit(1)
PY
  then
    fail "SR-S2 contains forbidden content in ${TRACE#"$ROOT"/}: $needle"
  fi
}

for file in "$TRACE" "$ASSESSMENT" "$TECH_LEAD" "$RUN_ALL"; do
  test -f "$file" || fail "missing tech-lead shadow file: ${file#"$ROOT"/}"
done

for step in SR-S1 SR-S2 SR-S3 SR-S4 SR-R1 SR-R2 SR-R3 SR-R4 SR-R5 SR-R6 SR-R7 SR-R8 SR-R9 SR-R10 SR-F1 SR-E1 SR-V1; do
  assert_present "### ${step}" "$TRACE"
done

for field in \
  "场景：" \
  "约束：" \
  "想看到的变化：" \
  "观察到的不适：" \
  "要保留的能力：" \
  "候选切入点：" \
  "承载：" \
  "待确认："; do
  assert_present "$field" "$TRACE"
done

for forbidden in "Current judgment:" "Best-practice target:" "当前判断" "最佳实践目标" "候选策略" "验证方式"; do
  assert_absent_in_sr_s2 "$forbidden"
done

assert_present 'No shared/skills/tech-lead production file was modified in this shadow run.' "$TRACE"
assert_present '整体策略确认: final_operation_candidate=optimize; execution_scope=shadow evidence only.' "$TRACE"

jq -e '
  .artifact_type == "skill-refiner-shadow-dogfood"
  and .schema_version == "1.0.0"
  and .target.skill_name == "tech-lead"
  and .target.path == "shared/skills/tech-lead"
  and .target.operation_candidate == "optimize"
  and .sr_s2_quality.fielded_baseline == true
  and .sr_s2_quality.no_premature_root_cause == true
  and .sr_s2_quality.no_success_standard == true
  and .sr_s2_quality.no_ring_strategy == true
  and .flow_result.all_steps_exercised == true
  and .flow_result.production_files_modified_by_shadow == false
  and .flow_result.worktree_target_dirty_at_final_check == true
  and .flow_result.release_decision == "hold_until_clean_install_window"
  and (.sr_s2_baseline | has("real_scenario") and has("business_constraint") and has("expected_outcome_signal") and has("observed_pain") and has("protected_capability_candidate") and has("entry_point_candidate") and has("located_carrier") and has("open_questions"))
  and (.verification_commands | index("bash tests/test-skill-refiner-tech-lead-shadow-flow.sh") != null)
  and (.verification_commands | index("bash tests/test-skill-refiner-sr-s2-fielded-dogfood.sh") != null)
' "$ASSESSMENT" >/dev/null || fail "tech-lead shadow assessment does not prove the full demand flow"

run_all_list="$(bash "$RUN_ALL" --list)"
grep -Fq 'test-skill-refiner-tech-lead-shadow-flow.sh' <<<"$run_all_list" \
  || fail "tech-lead shadow flow test is not registered in tests/run-all.sh"

printf '[PASS] skill-refiner tech-lead shadow flow\n'
