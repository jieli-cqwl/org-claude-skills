#!/usr/bin/env bash
# File role: prove research retain has a real current-vs-old benchmark artifact,
# not only static contract evidence.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE="$ROOT/shared/skills/research-workspace/iteration-1"
BENCHMARK="$WORKSPACE/benchmark.json"
BENCHMARK_MD="$WORKSPACE/benchmark.md"
REVIEW_HTML="$WORKSPACE/review.html"
EVIDENCE="$ROOT/shared/skills/research/evals/benchmark-grade-retain-2026-05-12/benchmark-grade-retain.json"
LIFECYCLE="$ROOT/shared/skills/research/evals/lifecycle-review.json"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

for file in "$BENCHMARK" "$BENCHMARK_MD" "$REVIEW_HTML" "$EVIDENCE" "$LIFECYCLE"; do
  test -f "$file" || fail "missing benchmark-grade research artifact: ${file#"$ROOT"/}"
done

jq empty "$BENCHMARK" "$EVIDENCE" "$LIFECYCLE" >/dev/null \
  || fail "invalid JSON in benchmark-grade research artifacts"
rg -q 'Benchmark Results' "$REVIEW_HTML" || fail "review HTML must contain benchmark view"

jq -e '
  .metadata.skill_name == "research"
  and .metadata.comparison == "current_skill_vs_old_skill"
  and .metadata.runs_per_configuration == 1
  and (.metadata.evals_run | length) >= 7
  and (.runs | length) >= 14
  and (.run_summary.current_skill.pass_rate.mean >= 0.95)
  and (.run_summary.old_skill.pass_rate.mean <= 0.85)
  and ((.run_summary.current_skill.pass_rate.mean - .run_summary.old_skill.pass_rate.mean) >= 0.15)
' "$BENCHMARK" >/dev/null || fail "benchmark summary does not satisfy benchmark-grade retain thresholds"

for eval_id in \
  quick-advisory-no-report \
  github-repo-radar-routing \
  deep-research-routing \
  formal-report-completion-gate \
  multi-agent-selection \
  skill-doc-detail-analysis \
  agent-browser-discovery-audit; do
  jq -e --arg eval_id "$eval_id" '
    any(.runs[]; .eval_name == $eval_id and .configuration == "current_skill")
    and any(.runs[]; .eval_name == $eval_id and .configuration == "old_skill")
  ' "$BENCHMARK" >/dev/null || fail "benchmark missing current/old run for $eval_id"
done

jq -e '
  .artifact_type == "research-benchmark-grade-retain"
  and .schema_version == 1
  and .decision == "benchmark_grade_retain"
  and .claim_boundary == "current-vs-old local LLM sample benchmark plus static contracts; not multi-run statistical proof"
  and .summary.current_pass_rate >= 0.95
  and .summary.old_pass_rate <= 0.85
  and .summary.pass_rate_delta >= 0.15
  and .summary.current_wins >= 2
  and .summary.regressions == 0
  and (.evidence_refs | index("shared/skills/research-workspace/iteration-1/benchmark.json") != null)
  and (.evidence_refs | index("shared/skills/research-workspace/iteration-1/review.html") != null)
' "$EVIDENCE" >/dev/null || fail "benchmark-grade retain evidence is below threshold"

jq -e '
  .decision == "retain"
  and .benchmark_grade_retain.measurement_status == "benchmark_grade_retain_passed"
  and (.evidence_refs | index("shared/skills/research/evals/benchmark-grade-retain-2026-05-12/benchmark-grade-retain.json") != null)
' "$LIFECYCLE" >/dev/null || fail "research lifecycle must reference benchmark-grade retain evidence"

run_all_list="$(bash "$ROOT/tests/run-all.sh" --quick --list)"
rg -q 'test-research-benchmark-grade-retain\.sh' <<<"$run_all_list" \
  || fail "run-all quick plan must include research benchmark-grade retain gate"

printf '[PASS] research benchmark-grade retain\n'
