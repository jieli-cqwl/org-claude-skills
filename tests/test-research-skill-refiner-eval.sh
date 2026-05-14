#!/usr/bin/env bash
# File role: prove research has lightweight triage, adjacent routing, and eval evidence after refinement.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/research/SKILL.md"
PROMPTS="$ROOT/shared/skills/research/test-prompts.json"
EVALS="$ROOT/shared/skills/research/evals/evals.json"
LIFECYCLE="$ROOT/shared/skills/research/evals/lifecycle-review.json"
RESULT="$ROOT/shared/skills/research/evals/skill-refiner-audit-2026-05-12/skill-refiner-result.json"
VALIDATOR="$ROOT/shared/skills/skill-refiner/scripts/validate_refinement_result.py"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local pattern="$1"
  local file="$2"
  rg -n "$pattern" "$file" >/dev/null 2>&1 || fail "missing pattern in ${file#"$ROOT"/}: $pattern"
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if rg -n "$pattern" "$file" >/dev/null 2>&1; then
    fail "unexpected pattern in ${file#"$ROOT"/}: $pattern"
  fi
}

assert_research_quick_triage_contract() {
  local file="$1"

  python3 - "$file" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
required = [
    "轻量预判断不是 /research 完成",
    "正式报告收口",
    "github-repo-radar",
    "deep-research",
    "不为轻量预判断强制落盘 research-report.md",
    "只输出最小决策包",
    "agent teams 只用于 Step 2/3/5",
]
missing = [term for term in required if term not in text]
if missing:
    raise SystemExit(f"research quick triage contract missing: {', '.join(missing)}")
legacy = "NO /research 完成 without `docs/{feature}/research-report.md` 落盘且用户确认"
if legacy in text:
    raise SystemExit("research quick triage contract still contains legacy hard-gate wording")
PY
}

for file in "$SKILL" "$PROMPTS" "$EVALS" "$LIFECYCLE" "$RESULT" "$VALIDATOR"; do
  test -f "$file" || fail "missing research refinement file: ${file#"$ROOT"/}"
done

jq empty "$PROMPTS" "$EVALS" "$LIFECYCLE" "$RESULT" >/dev/null \
  || fail "invalid JSON in research refinement artifacts"
python3 "$VALIDATOR" "$RESULT" >/dev/null

assert_research_quick_triage_contract "$SKILL"

jq -e '
  length >= 7
  and any(.[]; .id == "quick-advisory-no-report" and .mode == "analysis" and .presentation_profile == "decision")
  and any(.[]; .id == "github-repo-radar-routing" and (.expected | test("github-repo-radar")))
  and any(.[]; .id == "deep-research-routing" and (.expected | test("deep-research")))
  and any(.[]; .id == "formal-report-completion-gate" and (.expected | test("research-report.md")))
' "$PROMPTS" >/dev/null || fail "research test prompts must cover quick advisory, adjacent routing, and formal report gate"

jq -e '
  .skill_name == "research"
  and .eval_type == "mixed"
  and (.preference_anchors | length) >= 8
  and (.evals | length) >= 7
  and any(.evals[]; .id == "quick-advisory-no-report" and .run_modes == ["with_skill", "without_skill"])
  and any(.evals[]; .id == "github-repo-radar-routing")
  and any(.evals[]; .id == "deep-research-routing")
  and any(.evals[]; .id == "formal-report-completion-gate")
' "$EVALS" >/dev/null || fail "research evals must cover refinement scenarios"

jq -e '
  .skill_name == "research"
  and .eval_type == "mixed"
  and .decision == "retain"
  and .review_date == "2026-05-12"
  and .capability_uplift.measurement_status == "retain_gate_passed"
  and .encoded_preference.measurement_status == "retain_gate_passed"
  and (.evidence_refs | index("tests/test-research-skill-refiner-eval.sh") != null)
  and (.evidence_refs | index("shared/skills/research/evals/skill-refiner-audit-2026-05-12/skill-refiner-result.json") != null)
  and (.evidence_refs | index("shared/skills/research/evals/retain-gate-2026-05-12/research-retain-evidence.json") != null)
' "$LIFECYCLE" >/dev/null || fail "research lifecycle must record retain decision and evidence"

jq -e '
  .target.skill_name == "research"
  and .target.operation == "optimize"
  and .completion_assessment.overall_status == "pass"
  and (.verification_commands | map(select(.status == "pass")) | length >= 4)
' "$RESULT" >/dev/null || fail "research skill-refiner result must prove completed optimization"

run_all_list="$(bash "$ROOT/tests/run-all.sh" --quick --list)"
grep -Eq 'test-research-skill-refiner-eval\.sh' <<<"$run_all_list" \
  || fail "run-all quick plan must include research refinement eval"

printf '[PASS] research skill-refiner eval\n'
