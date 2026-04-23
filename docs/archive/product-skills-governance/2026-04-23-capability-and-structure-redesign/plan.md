# Product Skills Capability and Structure Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Update `product-director` and `product-manager` so their capabilities and Skill structure match `design.md`, with tests proving the new contracts.

**Architecture:** Keep the split skill architecture unchanged. Strengthen each skill's own contract and nearby references/templates, and verify with shell-based contract tests that inspect the Markdown artifacts directly.

**Tech Stack:** Bash contract tests, Markdown skill/reference/template files, existing `tools/community/check_task_plan_consistency.py`.

---

## Current Workspace Notes

The active branch is `codex/skill-lifecycle-eval-framework`. The current workspace already contains uncommitted changes in related skill files, so implementation stays in this feature branch and avoids reset, checkout, or stash operations. The baseline product test run on 2026-04-23 showed failures in `tests/test-product-artifact-contract.sh`, `tests/test-product-inherited-capability-parity.sh`, `tests/test-product-role-split-contract.sh`, and `tests/test-product-template-purity-contract.sh`; these are inside the redesign surface and are included in T4.

## File Boundary Map

- Create: `tests/test-product-capability-structure-redesign.sh`
- Modify: `shared/skills/product-director/SKILL.md`
- Modify: `shared/skills/product-director/references/conversation-guide.md`
- Modify: `shared/skills/product-director/references/product-thinking-contract.md`
- Modify: `shared/skills/product-director/references/output-contract.md`
- Modify: `shared/skills/product-director/references/templates/brief-template.md`
- Modify: `shared/skills/product-director/references/templates/phase-prd-template.md`
- Modify: `shared/skills/product-manager/SKILL.md`
- Modify: `shared/skills/product-manager/references/closed-loop-unit-spec.md`
- Modify: `shared/skills/product-manager/references/completeness-checklist.md`
- Modify: `shared/skills/product-manager/references/conversation-guide.md`
- Modify: `shared/skills/product-manager/references/output-contract.md`
- Modify: `shared/skills/product-manager/references/prd-reviewer-prompt.md`
- Modify: `shared/skills/product-manager/references/tester-reviewer-prompt.md`
- Modify: `shared/skills/product-manager/references/architect-reviewer-prompt.md`
- Modify: `shared/skills/product-manager/references/review-orchestration-contract.md`
- Modify: `shared/skills/product-manager/references/templates/phase-prd-template.md`
- Modify: `shared/skills/product-manager/references/templates/product-manager-review-template.md`
- Modify: `tests/test-product-artifact-contract.sh`
- Modify: `tests/test-product-role-split-contract.sh`
- Modify: `tests/test-product-inherited-capability-parity.sh`
- Modify: `tests/test-product-template-purity-contract.sh`
- Modify as needed: `contracts/product-artifacts.yaml`

### Task 1: Add capability-redesign regression coverage [T1]

Context: This task creates the RED test that proves the current skill artifacts do not yet satisfy the redesign. The test must fail before implementation and pass only after T2-T4 are implemented.

Files:
- Create: `tests/test-product-capability-structure-redesign.sh`

1. [T1] Write the failing test

Create `tests/test-product-capability-structure-redesign.sh` with this content:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DIRECTOR_SKILL="$ROOT/shared/skills/product-director/SKILL.md"
DIRECTOR_OUTPUT="$ROOT/shared/skills/product-director/references/output-contract.md"
DIRECTOR_GUIDE="$ROOT/shared/skills/product-director/references/conversation-guide.md"
DIRECTOR_THINKING="$ROOT/shared/skills/product-director/references/product-thinking-contract.md"
DIRECTOR_BRIEF_TEMPLATE="$ROOT/shared/skills/product-director/references/templates/brief-template.md"
DIRECTOR_PHASE_TEMPLATE="$ROOT/shared/skills/product-director/references/templates/phase-prd-template.md"
MANAGER_SKILL="$ROOT/shared/skills/product-manager/SKILL.md"
MANAGER_OUTPUT="$ROOT/shared/skills/product-manager/references/output-contract.md"
MANAGER_UNIT_SPEC="$ROOT/shared/skills/product-manager/references/closed-loop-unit-spec.md"
MANAGER_CHECKLIST="$ROOT/shared/skills/product-manager/references/completeness-checklist.md"
MANAGER_GUIDE="$ROOT/shared/skills/product-manager/references/conversation-guide.md"
MANAGER_REVIEW_CONTRACT="$ROOT/shared/skills/product-manager/references/review-orchestration-contract.md"
MANAGER_PRD_REVIEWER="$ROOT/shared/skills/product-manager/references/prd-reviewer-prompt.md"
MANAGER_TEST_REVIEWER="$ROOT/shared/skills/product-manager/references/tester-reviewer-prompt.md"
MANAGER_ARCH_REVIEWER="$ROOT/shared/skills/product-manager/references/architect-reviewer-prompt.md"
MANAGER_PHASE_TEMPLATE="$ROOT/shared/skills/product-manager/references/templates/phase-prd-template.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "missing file: $1"
}

assert_present() {
  local pattern="$1" file="$2"
  grep -Eq "$pattern" "$file" || fail "missing pattern in $file: $pattern"
}

assert_absent() {
  local pattern="$1" file="$2"
  if grep -Eq "$pattern" "$file"; then
    fail "unexpected pattern in $file: $pattern"
  fi
}

for file in \
  "$DIRECTOR_SKILL" "$DIRECTOR_OUTPUT" "$DIRECTOR_GUIDE" "$DIRECTOR_THINKING" \
  "$DIRECTOR_BRIEF_TEMPLATE" "$DIRECTOR_PHASE_TEMPLATE" "$MANAGER_SKILL" \
  "$MANAGER_OUTPUT" "$MANAGER_UNIT_SPEC" "$MANAGER_CHECKLIST" "$MANAGER_GUIDE" \
  "$MANAGER_REVIEW_CONTRACT" "$MANAGER_PRD_REVIEWER" "$MANAGER_TEST_REVIEWER" \
  "$MANAGER_ARCH_REVIEWER" "$MANAGER_PHASE_TEMPLATE"; do
  assert_file "$file"
done

assert_present '^## 流程总览$' "$DIRECTOR_SKILL"
assert_present '^## 流程图$' "$DIRECTOR_SKILL"
assert_present '^## 流程细节$' "$DIRECTOR_SKILL"
assert_absent '^## 流程使用点引用$' "$DIRECTOR_SKILL"
assert_present 'D-S2.*用户画像|用户画像.*D-S2' "$DIRECTOR_SKILL"
assert_present 'D-S3.*Appetite|Appetite.*D-S3' "$DIRECTOR_SKILL"
assert_present 'D-S5.*Non-goals|Non-goals.*D-S5' "$DIRECTOR_SKILL"
assert_present 'D-S5.*可行性约束|可行性约束.*D-S5' "$DIRECTOR_SKILL"
assert_present 'D-S5.*决策理由|决策理由.*D-S5' "$DIRECTOR_SKILL"
assert_present 'D-S5\.5.*风险与未知项|风险与未知项.*D-S5\.5' "$DIRECTOR_SKILL"
assert_present 'Why:' "$DIRECTOR_SKILL"

assert_present '用户画像|user_profile' "$DIRECTOR_OUTPUT"
assert_present 'appetite|Appetite' "$DIRECTOR_OUTPUT"
assert_present 'Non-goals|non_goals' "$DIRECTOR_OUTPUT"
assert_present '可行性约束|feasibility_constraints' "$DIRECTOR_OUTPUT"
assert_present '风险与未知项|risks_and_unknowns' "$DIRECTOR_OUTPUT"
assert_present '决策理由|decision_rationale' "$DIRECTOR_OUTPUT"
assert_present '用户画像|当前绕行方式' "$DIRECTOR_BRIEF_TEMPLATE"
assert_present 'Appetite' "$DIRECTOR_BRIEF_TEMPLATE"
assert_present 'Non-goals|本期不交付' "$DIRECTOR_BRIEF_TEMPLATE"
assert_present '可行性约束' "$DIRECTOR_BRIEF_TEMPLATE"
assert_present '风险与未知项' "$DIRECTOR_BRIEF_TEMPLATE"
assert_present '决策理由' "$DIRECTOR_BRIEF_TEMPLATE"
assert_present 'Appetite' "$DIRECTOR_THINKING"
assert_present 'Rabbit Holes|风险与未知项' "$DIRECTOR_THINKING"
assert_present '用户画像|当前绕行方式' "$DIRECTOR_GUIDE"

assert_present '^## 流程总览$' "$MANAGER_SKILL"
assert_present '^## 流程图$' "$MANAGER_SKILL"
assert_present '^## 流程细节$' "$MANAGER_SKILL"
assert_absent '^## 流程使用点引用$' "$MANAGER_SKILL"
assert_present 'M-S0.*内容完整性|内容完整性.*M-S0' "$MANAGER_SKILL"
assert_present 'M-S4.*Integration Context|Integration Context.*M-S4' "$MANAGER_SKILL"
assert_present 'M-S5.*示例驱动|示例驱动.*M-S5' "$MANAGER_SKILL"
assert_present 'M-S5.*失败模式|失败模式.*M-S5' "$MANAGER_SKILL"
assert_present 'M-S5\.5.*Verification Plan|Verification Plan.*M-S5\.5' "$MANAGER_SKILL"
assert_present 'M-S6.*结构化|结构化.*M-S6' "$MANAGER_SKILL"
assert_present 'M-S7.*AI 可执行性|AI 可执行性.*M-S7' "$MANAGER_SKILL"
assert_present 'Why:' "$MANAGER_SKILL"

assert_present '示例输入' "$MANAGER_UNIT_SPEC"
assert_present '预期结果' "$MANAGER_UNIT_SPEC"
assert_present '边界情况' "$MANAGER_UNIT_SPEC"
assert_present '失败模式' "$MANAGER_UNIT_SPEC"
assert_present 'Verification Plan|验证计划' "$MANAGER_UNIT_SPEC"
assert_present 'Integration Context|集成上下文' "$MANAGER_UNIT_SPEC"
assert_present 'AI 可执行性' "$MANAGER_CHECKLIST"
assert_present '示例驱动|示例输入' "$MANAGER_PRD_REVIEWER"
assert_present 'AI 可执行性' "$MANAGER_PRD_REVIEWER"
assert_present 'Verification Plan|验证计划' "$MANAGER_TEST_REVIEWER"
assert_present 'Integration Context|集成上下文' "$MANAGER_ARCH_REVIEWER"
assert_present 'Verification Plan|验证计划' "$MANAGER_PHASE_TEMPLATE"
assert_present 'Integration Context|集成上下文' "$MANAGER_PHASE_TEMPLATE"

echo "[PASS] product capability and structure redesign"
```

2. [T1] Make it executable

Run: `chmod +x tests/test-product-capability-structure-redesign.sh`

Expected: exit 0.

3. [T1] Verify RED

Run: `bash tests/test-product-capability-structure-redesign.sh`

Expected: FAIL mentioning the first missing redesigned structure or capability pattern.

### Task 2: Redesign product-director capability contract [T2]

Context: Director remains pure WHY. It gains thicker problem framing fields and a cleaner Skill structure without taking UNIT/AC ownership.

Files:
- Modify: `shared/skills/product-director/SKILL.md`
- Modify: `shared/skills/product-director/references/conversation-guide.md`
- Modify: `shared/skills/product-director/references/product-thinking-contract.md`
- Modify: `shared/skills/product-director/references/output-contract.md`
- Modify: `shared/skills/product-director/references/templates/brief-template.md`
- Modify: `shared/skills/product-director/references/templates/phase-prd-template.md`

1. [T2] Rewrite the Director HARD-GATE entries with Why notes

Keep the existing gate IDs and add a `Why:` line under each gate. Preserve the existing canonical JSON and confirmation semantics. Include D-S5.5 in the no-skip gate text.

2. [T2] Replace the standalone flow-reference section

Remove `## 流程使用点引用`. Add `## 流程总览`, `## 流程图`, and `## 流程细节`. Inline reference reads inside the relevant step descriptions:

```markdown
## 流程总览

- D-S1 静默信息收集
- D-S2 问题与用户澄清，补齐用户画像
- D-S3 目标、成功标准与 Appetite
- D-S4 业务语义收口
- D-S5 范围、Non-goals、可行性约束与决策理由
- D-S5.5 风险与未知项
- D-S6 Phase 规划
- D-G1 总监确认门
```

3. [T2] Add Director flow diagram

Add a Graphviz dot block showing `D-S5.5 风险与未知项` before `D-S6 Phase 规划`, and a pause edge for every co-creation step.

4. [T2] Add Director step details

For each D-S step, include `交互模式`, `做什么`, `约束`, and `暂停条件`. D-S2 must mention `谁 / 场景 / 当前绕行方式`; D-S3 must mention `Appetite`; D-S5 must mention `Non-goals`, `可行性约束`, and `决策理由`; D-S5.5 must mention `风险与未知项`.

5. [T2] Update Director output contract and templates

Add output fields or headings for user profile, appetite, non-goals, feasibility constraints, risks and unknowns, and decision rationale. Keep UNIT/AC/review exclusions explicit. Keep template line count at or below the updated test limit in T4.

6. [T2] Run focused RED-to-GREEN checks for Director

Run: `bash tests/test-product-capability-structure-redesign.sh`

Expected after T2 alone: still FAIL on Manager assertions, while Director assertions no longer fail.

### Task 3: Redesign product-manager capability contract [T3]

Context: Manager remains WHAT-layer owner. It gains example-driven AC, explicit verification planning, integration context, structured design decision handoff, and AI executability review.

Files:
- Modify: `shared/skills/product-manager/SKILL.md`
- Modify: `shared/skills/product-manager/references/closed-loop-unit-spec.md`
- Modify: `shared/skills/product-manager/references/completeness-checklist.md`
- Modify: `shared/skills/product-manager/references/conversation-guide.md`
- Modify: `shared/skills/product-manager/references/output-contract.md`
- Modify: `shared/skills/product-manager/references/prd-reviewer-prompt.md`
- Modify: `shared/skills/product-manager/references/tester-reviewer-prompt.md`
- Modify: `shared/skills/product-manager/references/architect-reviewer-prompt.md`
- Modify: `shared/skills/product-manager/references/review-orchestration-contract.md`
- Modify: `shared/skills/product-manager/references/templates/phase-prd-template.md`
- Modify: `shared/skills/product-manager/references/templates/product-manager-review-template.md`

1. [T3] Rewrite the Manager HARD-GATE entries with Why notes

Keep existing gate IDs and semantics. Add `Why:` under each gate. Do not relax M-HG-0, M-HG-5, M-HG-7, M-HG-9, or M-HG-10.

2. [T3] Replace the standalone flow-reference section

Remove `## 流程使用点引用`. Add `## 流程总览`, `## 流程图`, and `## 流程细节`, with M-S5.5 between M-S5 and M-S6.

3. [T3] Add Manager step details

M-S0 must include the Director output completeness checks. M-S4 must require Integration Context for each UNIT. M-S5 must require example-driven AC with example input, expected result, boundary case, and failure mode. M-S5.5 must define Verification Plan as business operations plus observable results. M-S6 must define structured design decisions with options, constraints, affected UNITs, and design handoff. M-S7/M-S8 must include AI executability.

4. [T3] Update Manager reference contracts

Update `closed-loop-unit-spec.md`, `completeness-checklist.md`, reviewer prompts, and templates so downstream agents see the same fields the main Skill requires.

5. [T3] Run focused Manager check

Run: `bash tests/test-product-capability-structure-redesign.sh`

Expected after T3: PASS unless T4 contract alignment is still blocking through old product tests.

### Task 4: Align existing product contract tests with canonical redesign [T4]

Context: Several existing product tests currently assert retired markdown-lock details or an older human projection heading. This task keeps them meaningful while aligning them to the canonical JSON direction and redesigned structure.

Files:
- Modify: `tests/test-product-artifact-contract.sh`
- Modify: `tests/test-product-role-split-contract.sh`
- Modify: `tests/test-product-inherited-capability-parity.sh`
- Modify: `tests/test-product-template-purity-contract.sh`
- Modify as needed: `contracts/product-artifacts.yaml`
- Modify as needed: `shared/skills/product-manager/references/review-orchestration-contract.md`

1. [T4] Align artifact-contract assertions

Keep assertions that `contracts/product-artifacts.yaml` exists and contains product artifact sections. Replace script assertions that require `load_product_artifact_contract` in runtime gates with assertions that runtime gates validate canonical JSON artifacts through `validate_canonical_schema.py` and `validate_product_closure.py`.

2. [T4] Align role-split assertions

Replace the `brief.md#前置约束-con-001` expectation with canonical `brief.json#/constraints` or `artifact://brief/{feature}.brief@vX#constraint-CON-001`. Keep assertions that Director templates do not include Manager-owned UNIT tables or delivery confirmation.

3. [T4] Align inherited-capability review contract assertions

Use the current `## 人类投影视图收口规则` heading as the review projection contract, while still asserting issue ledger, `HIS-*`, confirmation round, max 10 rounds, and product/architecture/test reviewer responsibilities.

4. [T4] Align template line-count limits after adding required fields

Update the Director brief line-count limit only if the template must carry the new Director fields. Keep rule-like line-count checks, and keep Manager/Review template size checks.

5. [T4] Run existing product contract checks

Run:

```bash
bash tests/test-product-artifact-contract.sh
bash tests/test-product-role-split-contract.sh
bash tests/test-product-inherited-capability-parity.sh
bash tests/test-product-template-purity-contract.sh
```

Expected: each command prints `[PASS] ...`.

### Task 5: Verify and close the small-chain package [T5]

Context: This task proves the plan and implementation match and records any residual risk from long-running benchmark checks.

Files:
- Modify: `docs/product-skills-governance/2026-04-23-capability-and-structure-redesign/tasks.md`

1. [T5] Run task-plan consistency

Run:

```bash
python3 tools/community/check_task_plan_consistency.py docs/product-skills-governance/2026-04-23-capability-and-structure-redesign/tasks.md docs/product-skills-governance/2026-04-23-capability-and-structure-redesign/plan.md
```

Expected: `[PASS] tasks-plan consistency (5 tasks, ... plan steps)`.

2. [T5] Run targeted product verification

Run:

```bash
bash tests/test-product-capability-structure-redesign.sh
bash tests/test-product-artifact-contract.sh
bash tests/test-product-role-split-contract.sh
bash tests/test-product-inherited-capability-parity.sh
bash tests/test-product-output-contract-reference.sh
bash tests/test-product-template-purity-contract.sh
```

Expected: each command prints `[PASS] ...`.

3. [T5] Mark tasks complete after evidence exists

Use `apply_patch` to change each completed task line in `tasks.md` from `[ ]` to `[x]` only after its evidence has been produced.

4. [T5] Run verify-change checks

Run the consistency checker again, inspect `design.md`, `tasks.md`, `plan.md`, and the implementation diff, then produce a verify-change report with PASS only if every task is `[x]` and no CRITICAL finding remains.
