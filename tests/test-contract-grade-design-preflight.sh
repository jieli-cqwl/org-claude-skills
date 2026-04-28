#!/usr/bin/env bash
# 文件职责：守住契约级设计前置门禁，避免 source-of-truth / schema / hook 类设计再次靠后置 review 补洞。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local needle="$1"
  local file="$2"
  grep -Fq "$needle" "$file" || fail "missing required content in ${file#"$ROOT"/}: $needle"
}

BRAINSTORMING="$ROOT/community/superpowers/skills/brainstorming/SKILL.md"
CHECKLIST="$ROOT/community/superpowers/skills/brainstorming/references/design-completeness-checklist.md"
TEMPLATE="$ROOT/community/superpowers/skills/brainstorming/references/design-template.md"
WRITING_PLANS="$ROOT/community/superpowers/skills/writing-plans/SKILL.md"
VERIFY_CHANGE="$ROOT/community/superpowers/skills/verify-change/SKILL.md"
SKILL_QUALITY="$ROOT/shared/reference/Skill质量标准.md"
SMALL_CHAIN="$ROOT/contracts/small-chain.yaml"
OVERLAY_RULES="$ROOT/tools/community/superpowers_overlay_rules.py"

assert_present 'contract_grade_preflight' "$SMALL_CHAIN"

assert_present 'Contract-Grade Preflight' "$TEMPLATE"
assert_present 'Current vs Target' "$TEMPLATE"
assert_present 'Source of Truth Matrix' "$TEMPLATE"
assert_present 'Closed Vocabulary / Grammar' "$TEMPLATE"
assert_present 'Ownership / Waiver' "$TEMPLATE"
assert_present 'Failure Contract' "$TEMPLATE"
assert_present 'Implementation Surface' "$TEMPLATE"
assert_present 'Proving Categories' "$TEMPLATE"
assert_present 'Existing Contract Diff' "$TEMPLATE"

assert_present '| D9 | Contract-grade preflight | contract_grade_preflight | Contract-grade design trigger exists | Clear / Partial / Missing / N/A |' "$CHECKLIST"
assert_present 'Ownership: this checklist is the producer-side contract for `brainstorming` when it writes `design.md`.' "$CHECKLIST"
assert_present 'Skill quality standards audit whether producer and consumer Skills define, consume, and verify their artifact contracts.' "$CHECKLIST"
assert_present '## Contract-Grade Design Trigger' "$CHECKLIST"
assert_present '## D9 Contract-Grade Preflight' "$CHECKLIST"
assert_present '| C1 | Current vs Target |' "$CHECKLIST"
assert_present '| C2 | Source of Truth Matrix |' "$CHECKLIST"
assert_present '| C3 | Closed Vocabulary / Grammar |' "$CHECKLIST"
assert_present '| C4 | Ownership / Waiver |' "$CHECKLIST"
assert_present '| C5 | Failure Contract |' "$CHECKLIST"
assert_present '| C6 | Implementation Surface |' "$CHECKLIST"
assert_present '| C7 | Proving Categories |' "$CHECKLIST"
assert_present '| C8 | Existing Contract Diff |' "$CHECKLIST"
assert_present "If any C-check is Partial or Missing, fix \`design.md\` before asking for user approval or entering writing-plans." "$CHECKLIST"

assert_present '6. Contract-grade preflight' "$BRAINSTORMING"
assert_present 'answer all C1-C8 checks' "$BRAINSTORMING"
assert_present "freeze C1-C8 decisions here before user review and writing-plans" "$BRAINSTORMING"

assert_present '## Contract-Grade Intake Gate' "$WRITING_PLANS"
assert_present 'Carry forward the approved source-of-truth rules, ref grammar, owner/waiver rules, cutover order, and proving categories from `design.md`' "$WRITING_PLANS"
assert_present 'read the approved `Contract-Grade Preflight`, then route missing or ambiguous C-checks back to brainstorming/design revision.' "$WRITING_PLANS"
assert_present '8. Contract-grade carryover' "$WRITING_PLANS"
assert_present 'No task introduces a new source-of-truth rule, ref grammar, owner/waiver rule, or migration phase not present in design.md.' "$WRITING_PLANS"
assert_present 'name="contract-grade-intake-gate"' "$OVERLAY_RULES"
assert_present 'name="contract-grade-self-review"' "$OVERLAY_RULES"

assert_present '7. Contract-grade proof carryover' "$VERIFY_CHANGE"
assert_present 'Any implementation that changes source-of-truth, ref grammar, owner/waiver rules, or migration phases outside the approved design is a CRITICAL finding.' "$VERIFY_CHANGE"

if grep -Fq 'Contract-Grade 设计文档门禁' "$SKILL_QUALITY"; then
  fail "keep C1-C8 design-document policy anchored in the brainstorming producer contract"
fi

python3 - <<'PY' >/dev/null || fail "contract-grade writing-plans overlays should replay against upstream text"
from pathlib import Path
import tempfile

from tools.community import superpowers_overlay_rules as rules

names = {
    "contract-grade-intake-gate",
    "process-flow",
    "contract-grade-self-review",
}
selected = [
    rule
    for rule in rules.SUPERPOWERS_OVERLAY_RULES
    if rule.path == "skills/writing-plans/SKILL.md" and rule.name in names
]
assert {rule.name for rule in selected} == names

local_text = """# Writing Plans

## Scope Check

Upstream scope check.

## Contract-Grade Intake Gate

Local contract gate.

## Process Flow

Local process flow.

## File Structure

Upstream file structure.

## Self-Review

**1. Spec coverage:** Upstream coverage.

For contract-grade designs, each C1-C8 preflight answer must map to at least one task, test, fixture, hook, validator, docs update, or explicit N/A reason.

**2. Placeholder scan:** Upstream placeholder scan.
"""

upstream_text = """# Writing Plans

## Scope Check

Upstream scope check.

## File Structure

Upstream file structure.

## Self-Review

**1. Spec coverage:** Upstream coverage.

**2. Placeholder scan:** Upstream placeholder scan.
"""

with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    community = root / "community"
    target = community / "superpowers" / "skills" / "writing-plans" / "SKILL.md"
    target.parent.mkdir(parents=True)
    target.write_text(local_text, encoding="utf-8")

    original_rules = rules.SUPERPOWERS_OVERLAY_RULES
    original_frontmatter = rules.SUPERPOWERS_FRONTMATTER_LINES
    original_full_files = rules.SUPERPOWERS_FULL_FILE_OVERLAYS
    try:
        rules.SUPERPOWERS_OVERLAY_RULES = selected
        rules.SUPERPOWERS_FRONTMATTER_LINES = {}
        rules.SUPERPOWERS_FULL_FILE_OVERLAYS = []
        overlays = rules.capture_superpowers_local_overlays(
            community,
            root,
            lambda _cmd, cwd=None: "",
            require_all=True,
        )
        target.write_text(upstream_text, encoding="utf-8")
        rules.apply_superpowers_local_overlays(community, overlays)
    finally:
        rules.SUPERPOWERS_OVERLAY_RULES = original_rules
        rules.SUPERPOWERS_FRONTMATTER_LINES = original_frontmatter
        rules.SUPERPOWERS_FULL_FILE_OVERLAYS = original_full_files

    result = target.read_text(encoding="utf-8")
    gate = result.index("## Contract-Grade Intake Gate")
    flow = result.index("## Process Flow")
    files = result.index("## File Structure")
    carryover = result.index("For contract-grade designs")
    placeholder = result.index("**2. Placeholder scan:**")
    assert gate < flow < files
    assert carryover < placeholder
PY

printf '[PASS] contract-grade design preflight\n'
