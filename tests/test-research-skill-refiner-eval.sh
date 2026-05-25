#!/usr/bin/env bash
# File role: prove research has lightweight triage, adjacent routing, and eval evidence after refinement.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/research/SKILL.md"
REFERENCE_DIR="$ROOT/shared/skills/research/references"
PROJECTION_DIR="$ROOT/shared/skills/research/projections"
PROMPTS="$ROOT/shared/skills/research/test-prompts.json"
EVALS="$ROOT/shared/skills/research/evals/evals.json"
LIFECYCLE="$ROOT/shared/skills/research/evals/lifecycle-review.json"
RESULT="$ROOT/shared/skills/research/evals/skill-refiner-audit-2026-05-12/skill-refiner-result.json"
ESSENCE_RESULT="$ROOT/shared/skills/research/evals/brainstorming-parity-2026-05-25/reference-chain-evidence.json"
VALIDATOR="$ROOT/shared/skills/skill-refiner/scripts/validate_refinement_result.py"
REFERENCE_CHAIN_CHECKER="$ROOT/tools/community/check_research_reference_chain.py"

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

assert_research_instruction_quality_contract() {
  local file="$1"

  python3 - "$file" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")

legacy_noise = [
    "核心方法论：",
    "定位：深度调研 + 实证分析 + 决策支持",
    "拒绝通用结论",
]
present_noise = [term for term in legacy_noise if term in text]
if present_noise:
    raise SystemExit(
        "research instruction quality still contains legacy/noisy wording: "
        + ", ".join(present_noise)
    )

required_clauses = {
    "claude_code_thinking_keyword": "> ultrathink",
    "action_contract_heading": "研究判断动作合同",
    "candidate_mechanism": "每个候选必须写清：解决什么问题、核心机制、适用边界和失效边界",
    "unsourced_claim_boundary": "无源论断只能进入待验证项",
    "context_bound_recommendation": "缺少项目约束时只能标为通用观察，不得作为推荐",
    "decision_first_screen": "decision 输出首屏必须包含：当前判断、决定性理由、最大风险和下一步",
}
missing = [name for name, clause in required_clauses.items() if clause not in text]
if missing:
    raise SystemExit(
        "research instruction quality missing action clauses: "
        + ", ".join(missing)
    )

if "警示信号" not in text or "出现以下想法时立刻停下" not in text:
    raise SystemExit("research instruction quality must keep actionable warning trigger")

stop_lines = [line for line in text.splitlines() if "→ STOP." in line]
if len(stop_lines) < 8:
    raise SystemExit("research warning signals must retain at least 8 concrete STOP paths")

if any("→ STOP." in line and "。" not in line.split("→ STOP.", 1)[1] for line in stop_lines):
    raise SystemExit("each STOP path must include a positive next action after the stop")
PY
}

assert_research_real_use_contract() {
  local file="$1"

  python3 - "$file" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")

required = {
    "mission": "/research 用在团队可能基于外部信息行动之前",
    "two_stage_core": "先找准资料/对象，再判准团队判断",
    "source_targeting": "Source Targeting",
    "evidence_qualification": "Evidence Qualification",
    "judgment_calibration": "Judgment Calibration",
    "decision_package": "Decision Package",
    "when_to_use": "## When to Use",
    "when_not_to_use": "## When NOT to Use",
    "adoption_scene": "这个东西能不能用？",
    "selection_scene": "这几个选哪个？",
    "claim_scene": "这个说法靠谱吗？",
    "identity_scene": "这个到底是哪一个？",
    "review_scene": "我倾向 X，帮我把把关。",
    "scouting_scene": "做方案前先看看外面怎么做。",
}
missing = [name for name, term in required.items() if term not in text]
if missing:
    raise SystemExit("research real use contract missing: " + ", ".join(missing))

bad_framing = [
    "Run research as a gated investigation, not as a source list.",
    "Research must change what the user can safely decide, understand, or audit.",
]
present = [term for term in bad_framing if term in text]
if present:
    raise SystemExit(
        "research still uses generic investigation framing instead of source-first team judgment framing: "
        + ", ".join(present)
    )
PY
}

assert_research_source_targeting_contract() {
  local file="$1"

  python3 - "$file" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")

required_clauses = {
    "source_first_gate": "Do NOT calibrate judgment until source/object targeting is complete.",
    "wrong_object_gate": "Do NOT treat a similar name, mirror, directory page, or secondary summary as the target object.",
    "source_package": "Source Targeting Package",
    "source_variants": "name variants",
    "upstream_source": "upstream/official source",
    "mirror_dedup": "mirror/directory deduplication",
    "exclusion_proof": "excluded lookalikes",
    "freshness": "freshness / timestamp",
    "credibility_tiers": "Evidence Qualification",
    "evidence_package_guide": "references/evidence-package-guide.md",
}
missing = [name for name, term in required_clauses.items() if term not in text]
if missing:
    raise SystemExit("research source targeting contract missing: " + ", ".join(missing))

source_index = text.index("Source Targeting")
judgment_index = text.index("Judgment Calibration")
if source_index > judgment_index:
    raise SystemExit("Source Targeting must appear before Judgment Calibration")
PY
}

assert_research_brainstorming_parity_contract() {
  local file="$1"

  python3 - "$file" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")

required_markers = {
    "hard_gate_block_start": "<HARD-GATE>",
    "hard_gate_block_end": "</HARD-GATE>",
    "anti_pattern_section": '## Anti-Pattern: "The First Relevant Result Is The Right Source"',
    "checklist_section": "## Checklist",
    "process_flow_section": "## Process Flow",
    "process_section": "## The Process",
    "report_self_review": "## Report Self-Review",
    "user_confirmation_gate": "## User Confirmation Gate",
    "terminal_state": "## Terminal State",
    "terminal_state_phrase": "The terminal state is either a confirmed lightweight decision package, a user-confirmed research report, or an explicit route to an adjacent skill.",
}
missing = [name for name, marker in required_markers.items() if marker not in text]
if missing:
    raise SystemExit(
        "research brainstorming parity missing structural markers: "
        + ", ".join(missing)
    )

section_order = [
    "<HARD-GATE>",
    '## Anti-Pattern: "The First Relevant Result Is The Right Source"',
    "## When to Use",
    "## When NOT to Use",
    "## Checklist",
    "## Process Flow",
    "## The Process",
    "## Report Self-Review",
    "## User Confirmation Gate",
    "## Terminal State",
]
positions = [text.index(marker) for marker in section_order]
if positions != sorted(positions):
    raise SystemExit("research brainstorming parity sections are out of order")

checklist = re.findall(r"^\d+\. \*\*(.+?)\*\*", text, flags=re.MULTILINE)
expected = [
    "Route the request",
    "Define the target object",
    "Find the right sources",
    "Qualify evidence",
    "Calibrate judgment",
    "Create decision package",
    "Write report when required",
    "Report self-review",
    "User confirmation or route handoff",
]
if checklist[: len(expected)] != expected:
    raise SystemExit(
        "research checklist must mirror brainstorming-style ordered execution; got: "
        + ", ".join(checklist[: len(expected)])
    )

flow_required = [
    'digraph research',
    '"Route the request"',
    '"Research needed?"',
    '"Define the target object"',
    '"Target/source found?"',
    '"Qualify evidence"',
    '"Calibrate judgment"',
    '"Report required?"',
    '"Report self-review"',
    '"User confirms report?"',
    '"Terminal: confirmed decision/report/route"',
]
flow_missing = [term for term in flow_required if term not in text]
if flow_missing:
    raise SystemExit("research process flow missing nodes: " + ", ".join(flow_missing))

if "The ONLY allowed next action after a completed formal research report is the user-confirmed handoff target." not in text:
    raise SystemExit("research terminal state must block unconfirmed downstream handoff")
PY
}

for file in "$SKILL" "$PROMPTS" "$EVALS" "$LIFECYCLE" "$RESULT" "$ESSENCE_RESULT" "$VALIDATOR" "$REFERENCE_CHAIN_CHECKER"; do
  test -f "$file" || fail "missing research refinement file: ${file#"$ROOT"/}"
done

jq empty "$PROMPTS" "$EVALS" "$LIFECYCLE" "$RESULT" "$ESSENCE_RESULT" >/dev/null \
  || fail "invalid JSON in research refinement artifacts"
python3 "$VALIDATOR" "$RESULT" >/dev/null

assert_research_quick_triage_contract "$SKILL"
assert_research_instruction_quality_contract "$SKILL"
assert_research_real_use_contract "$SKILL"
assert_research_source_targeting_contract "$SKILL"
assert_research_brainstorming_parity_contract "$SKILL"
python3 "$REFERENCE_CHAIN_CHECKER" "$REFERENCE_DIR" "$PROJECTION_DIR" "$ESSENCE_RESULT"

jq -e '
  length >= 7
  and any(.[]; .id == "multi-agent-selection" and .mode == "selection" and .presentation_profile == "decision" and (.expected | test("TOP 3")))
  and any(.[]; .id == "skill-doc-detail-analysis" and .mode == "analysis" and .presentation_profile == "understanding" and (.expected | test("支持/反方/失效边界")))
  and any(.[]; .id == "agent-browser-discovery-audit" and .mode == "discovery" and .presentation_profile == "audit" and (.expected | test("名称归一化")))
  and any(.[]; .id == "quick-advisory-no-report" and .mode == "analysis" and .presentation_profile == "decision")
  and any(.[]; .id == "github-repo-radar-routing" and (.expected | test("github-repo-radar")))
  and any(.[]; .id == "deep-research-routing" and (.expected | test("deep-research")))
  and any(.[]; .id == "formal-report-completion-gate" and (.expected | test("research-report.md")))
' "$PROMPTS" >/dev/null || fail "research test prompts must cover core research outputs, quick advisory, adjacent routing, and formal report gate"

jq -e '
  .skill_name == "research"
  and .eval_type == "mixed"
  and (.preference_anchors | length) >= 8
  and (.evals | length) >= 7
  and any(.evals[]; .id == "multi-agent-selection" and (.expected_anchors | index("RA-05") != null) and (.expected_anchors | index("RA-08") != null))
  and any(.evals[]; .id == "skill-doc-detail-analysis" and (.expected_anchors | index("RA-06") != null) and (.expected_anchors | index("RA-08") != null))
  and any(.evals[]; .id == "agent-browser-discovery-audit" and (.expected_anchors | index("RA-07") != null) and (.expected_anchors | index("RA-08") != null))
  and any(.evals[]; .id == "quick-advisory-no-report" and .run_modes == ["with_skill", "without_skill"])
  and any(.evals[]; .id == "github-repo-radar-routing")
  and any(.evals[]; .id == "deep-research-routing")
  and any(.evals[]; .id == "formal-report-completion-gate")
' "$EVALS" >/dev/null || fail "research evals must cover core research outputs and refinement scenarios"

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
