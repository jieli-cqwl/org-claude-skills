#!/usr/bin/env bash
# File role: prove research keeps lightweight triage, adjacent routing, and eval evidence after skill-quality audit cleanup.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/shared/skills/research/SKILL.md"
REFERENCE_DIR="$ROOT/shared/skills/research/references"
PROJECTION_DIR="$ROOT/shared/skills/research/projections"
PROMPTS="$ROOT/shared/skills/research/test-prompts.json"
EVALS="$ROOT/shared/skills/research/evals/evals.json"
LIFECYCLE="$ROOT/shared/skills/research/evals/lifecycle-review.json"
ESSENCE_RESULT="$ROOT/shared/skills/research/evals/brainstorming-parity-2026-05-25/reference-chain-evidence.json"
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
    "github-repo-radar",
    "deep-research",
    "research-report.md",
    "Step 2/3/5",
]
missing = [term for term in required if term not in text]
if missing:
    raise SystemExit(f"research quick triage contract missing: {', '.join(missing)}")
PY
}

assert_research_instruction_quality_contract() {
  local file="$1"

  python3 - "$file" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")

required_clauses = {
    "claude_code_thinking_keyword": "> ultrathink",
    "action_contract_heading": "研究判断动作合同",
    "candidate_mechanism": ["每个候选", "核心机制", "失效边界"],
    "unsourced_claim_boundary": "无源论断只能进入待验证项",
    "context_bound_recommendation": ["项目约束", "通用观察", "不得作为推荐"],
    "decision_first_screen": ["decision", "当前判断", "决定性理由", "最大风险", "下一步"],
}
missing = [
    name
    for name, clause in required_clauses.items()
    if not all(term in text for term in (clause if isinstance(clause, list) else [clause]))
]
if missing:
    raise SystemExit(
        "research instruction quality missing action clauses: "
        + ", ".join(missing)
    )

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

headings = {line[3:].strip() for line in text.splitlines() if line.startswith("## ")}
required_headings = {
    "When to Use",
    "When NOT to Use",
    "Core Contracts",
}
missing = sorted(required_headings - headings)
if missing:
    raise SystemExit("research real use contract missing: " + ", ".join(missing))
core_contracts = text.split("## Core Contracts", 1)[1].split("\n## ", 1)[0]
try:
    source_index = core_contracts.index("Source Targeting Package")
    evidence_index = core_contracts.index("Evidence Qualification")
    judgment_index = core_contracts.index("Judgment Calibration")
    decision_index = core_contracts.index("Decision Package")
except ValueError as exc:
    raise SystemExit("research real use contract missing core contract marker") from exc
if not source_index < evidence_index < judgment_index < decision_index:
    raise SystemExit("research real use contract core markers are out of order")

bad_framing = [
    ("gated investigation", "source list"),
    ("safely decide", "understand", "audit"),
]
present = ["/".join(terms) for terms in bad_framing if all(term in text for term in terms)]
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
    "source_first_gate": ["Do NOT", "calibrate judgment", "source/object targeting"],
    "wrong_object_gate": ["Do NOT", "similar name", "secondary summary", "target object"],
    "source_package": "Source Targeting Package",
    "source_variants": "name variants",
    "upstream_source": "upstream/official source",
    "mirror_dedup": "mirror/directory deduplication",
    "exclusion_proof": "excluded lookalikes",
    "freshness": "freshness / timestamp",
    "credibility_tiers": "Evidence Qualification",
    "evidence_package_guide": "references/evidence-package-guide.md",
}
missing = [
    name
    for name, term in required_clauses.items()
    if not all(item in text for item in (term if isinstance(term, list) else [term]))
]
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
    "anti_pattern_section": 'Anti-Pattern: "The First Relevant Result Is The Right Source"',
    "checklist_section": "Workflow Checklist",
    "core_contracts_section": "Core Contracts",
    "report_self_review": "Report Self-Review",
    "user_confirmation_gate": "User Confirmation Gate",
    "terminal_state": "Terminal State",
    "terminal_state_phrase": [
        "confirmed lightweight decision package",
        "user-confirmed research report",
        "explicit route to an adjacent skill",
    ],
}
missing = [
    name
    for name, marker in required_markers.items()
    if not all(term in text for term in (marker if isinstance(marker, list) else [marker]))
]
if missing:
    raise SystemExit(
        "research brainstorming parity missing structural markers: "
        + ", ".join(missing)
    )

line_count = len(text.splitlines())
if line_count > 220:
    raise SystemExit(f"research SKILL.md must stay concise for team rollout; got {line_count} lines")

for noisy_structure in ["## Process Flow", "```dot", "digraph research"]:
    if noisy_structure in text:
        raise SystemExit("research SKILL.md still contains duplicate process-flow noise: " + noisy_structure)

section_order = [
    "<HARD-GATE>",
    '## Anti-Pattern: "The First Relevant Result Is The Right Source"',
    "## When to Use",
    "## When NOT to Use",
    "## Workflow Checklist",
    "## Core Contracts",
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
PY
}

for file in "$SKILL" "$PROMPTS" "$EVALS" "$LIFECYCLE" "$ESSENCE_RESULT" "$REFERENCE_CHAIN_CHECKER"; do
  test -f "$file" || fail "missing research refinement file: ${file#"$ROOT"/}"
done

jq empty "$PROMPTS" "$EVALS" "$LIFECYCLE" "$ESSENCE_RESULT" >/dev/null \
  || fail "invalid JSON in research refinement artifacts"

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
  and (.evidence_refs | index("tests/test-research-skill-quality-audit-eval.sh") != null)
  and (.evidence_refs | index("shared/skills/research/evals/retain-gate-2026-05-12/research-retain-evidence.json") != null)
' "$LIFECYCLE" >/dev/null || fail "research lifecycle must record retain decision and evidence"

run_all_list="$(bash "$ROOT/tests/run-all.sh" --quick --list)"
grep -Eq 'test-research-skill-quality-audit-eval\.sh' <<<"$run_all_list" \
  || fail "run-all quick plan must include research refinement eval"

printf '[PASS] research skill-quality-audit eval\n'
