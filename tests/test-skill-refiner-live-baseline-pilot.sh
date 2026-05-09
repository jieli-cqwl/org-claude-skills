#!/usr/bin/env bash
# File role: verify skill-refiner live with/without baseline pilot evidence remains usable.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EVALS="$ROOT/shared/skills/skill-refiner/evals/evals.json"
LIFECYCLE="$ROOT/shared/skills/skill-refiner/evals/lifecycle-review.json"
WITH_SUMMARY="$ROOT/tools/eval/results/skill-refiner-final-operation-create-gate-live-with/summary.json"
WITHOUT_SUMMARY="$ROOT/tools/eval/results/skill-refiner-final-operation-create-gate-live-without/summary.json"
WITH_RUN="$ROOT/tools/eval/results/skill-refiner-final-operation-create-gate-live-with/skill-refiner/final-operation-create-gate/with_skill/run-1"
WITHOUT_RUN="$ROOT/tools/eval/results/skill-refiner-final-operation-create-gate-live-without/skill-refiner/final-operation-create-gate/without_skill/run-1"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

for file in "$EVALS" "$LIFECYCLE" "$WITH_SUMMARY" "$WITHOUT_SUMMARY"; do
  test -f "$file" || fail "missing file: ${file#"$ROOT"/}"
  jq empty "$file" >/dev/null || fail "invalid JSON: ${file#"$ROOT"/}"
done

for file in \
  "$WITH_RUN/eval_metadata.json" \
  "$WITH_RUN/grading.json" \
  "$WITH_RUN/outputs/response.md" \
  "$WITH_RUN/timing.json" \
  "$WITHOUT_RUN/eval_metadata.json" \
  "$WITHOUT_RUN/grading.json" \
  "$WITHOUT_RUN/outputs/response.md" \
  "$WITHOUT_RUN/timing.json"; do
  test -f "$file" || fail "missing run artifact: ${file#"$ROOT"/}"
done

jq -e '
  any(.evals[]; .id == "final-operation-create-gate"
    and .run_modes == ["with_skill", "without_skill"]
    and (.expectations | length == 6)
    and (.expected_anchors | index("SA-12") != null))
' "$EVALS" >/dev/null || fail "evals.json missing final-operation-create-gate contract"

jq -e '
  .summary.infra_failures == 0
  and .runs[0].skill_name == "skill-refiner"
  and .runs[0].eval_id == "final-operation-create-gate"
  and .runs[0].run_mode == "with_skill"
  and .runs[0].pass_rate == 1
  and .runs[0].anchor_passed == 9
  and .runs[0].anchor_total == 9
  and .runs[0].anchor_fidelity == 1
  and (.runs[0].failed_expectations | length == 0)
' "$WITH_SUMMARY" >/dev/null || fail "with-skill live summary drift"

jq -e '
  .summary.infra_failures == 0
  and .runs[0].skill_name == "skill-refiner"
  and .runs[0].eval_id == "final-operation-create-gate"
  and .runs[0].run_mode == "without_skill"
  and .runs[0].pass_rate == 0.5
  and .runs[0].anchor_passed == 0
  and .runs[0].anchor_total == 9
  and .runs[0].anchor_fidelity == 0
  and (.runs[0].failed_expectations | index("把新建、优化、替换或拆分后置为 SR-F1 的最终操作判断") != null)
  and (.runs[0].failed_expectations | index("要求 SR-S2、SR-S3 和 SR-R1~SR-R10 先沉淀台账结论，关键假设闭合后再执行") != null)
  and (.runs[0].failed_expectations | index("要求结构化结果和 validator/scoped proof 作为完成证据") != null)
' "$WITHOUT_SUMMARY" >/dev/null || fail "without-skill live summary drift"

jq -e '
  .decision == "optimize"
  and .review_date == "2026-05-03"
  and .capability_uplift.measurement_status == "pilot_empirical_sample_recorded"
  and .capability_uplift.with_avg == 1
  and .capability_uplift.without_avg == 0.5
  and .capability_uplift.uplift == 0.5
  and .encoded_preference.fidelity == 1
  and .encoded_preference.eval_count == 6
  and .pilot_empirical.with_skill.summary_ref == "tools/eval/results/skill-refiner-final-operation-create-gate-live-with/summary.json"
  and .pilot_empirical.without_skill.summary_ref == "tools/eval/results/skill-refiner-final-operation-create-gate-live-without/summary.json"
' "$LIFECYCLE" >/dev/null || fail "lifecycle review missing live pilot metrics"

grep -Fq 'SR-F1' "$WITH_RUN/outputs/response.md" \
  || fail "with-skill response must mention SR-F1"
if grep -Fq 'SR-F1' "$WITHOUT_RUN/outputs/response.md"; then
  fail "without-skill response unexpectedly mentions SR-F1"
fi

printf '[PASS] skill-refiner live baseline pilot\n'
