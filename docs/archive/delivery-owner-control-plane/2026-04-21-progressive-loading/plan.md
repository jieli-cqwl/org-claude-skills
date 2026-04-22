# Delivery Owner Progressive Loading Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Turn `delivery-owner` into a fixed full-delivery control plane with progressive loading, no internal grade trimming, and clean expert handoff boundaries.

**Architecture:** The runtime entry stays thin and routes phase-specific detail to references. Legacy markdown paths keep compatibility only where hooks still read them, while canonical JSON remains the active runtime authority. Tests first lock the new contract, then implementation updates skill text, references, templates, helper scripts, gates, graders, and stale docs.

**Tech Stack:** Markdown skills and references, Bash contract tests and hook scripts, JSON canonical schemas/templates, ripgrep-based structural assertions.

---

## File Boundaries

- `tests/test-delivery-owner-gate-contract.sh`: primary RED/GREEN contract for fixed full gates, progressive loading, no grade trimming, no expert SOP leakage, and no `Edit` tool on the skill.
- `shared/skills/delivery-owner/SKILL.md`: thin delivery control-plane entry.
- `shared/skills/delivery-owner/references/dispatch-guide.md`: Phase 2 handoff contract.
- `shared/skills/delivery-owner/references/delivery-gate-dispatch.md`: fixed full交付门禁gate contract.
- `shared/skills/delivery-owner/references/templates/code-review-report-template.md`: review projection template without grade fields.
- `shared/skills/qa/references/templates/qa-report-template.md`: QA projection template without grade fields and with full QA_A/B/C/D results.
- `shared/skills/delivery-owner/scripts/delivery-gate-stages.sh`: legacy-compatible fixed full-gate helper.
- `shared/skills/delivery-owner/scripts/completion_check.sh`: legacy markdown gate update from grade matching to full-gate evidence.
- `shared/skills/delivery-owner/scripts/manifest.json`: helper metadata update.
- `shared/skills/tech-lead/references/templates/plan-template.md`: legacy plan template without交付门禁审查分级章节.
- `shared/skills/tech-lead/scripts/completion_check.sh`: legacy plan hook no longer requires grade matrix.
- `shared/skills/qa/scripts/completion_check.sh`: legacy QA hook no longer requires grade field.
- `tests/test-delivery-owner-replay-contract.sh`, `tests/test-delivery-owner-rollout-gate.sh`, `tests/test-skill-output-and-gate-contract.sh`: downstream compatibility updates.
- `tools/eval/graders/task-constraint-grader.md`: grader dimension update.
- `docs/delivery-owner-role-20260411/`: archive stale role-era docs after preserving test-critical fixtures.

### Task 1: Lock the new contract with RED tests [T1]

Context: The old tests currently assert grade matrices and dynamic escalation. The first step changes tests to assert the desired contract and confirms they fail against current runtime files.

Files:
- Modify: `tests/test-delivery-owner-gate-contract.sh`
- Read: `docs/delivery-owner-control-plane/2026-04-21-progressive-loading/design.md`

1. [T1] Replace grade matrix assertions with fixed full gate assertions.

Edit the test so it sources `delivery-gate-stages.sh` and asserts:

```bash
assert_lines $'REVIEW_A\nREVIEW_B\nREVIEW_C' "$(delivery_gate_required_review_stages)"
assert_lines $'REVIEW_A\nREVIEW_B\nREVIEW_C' "$(delivery_gate_required_review_stages 轻量)"
assert_lines $'REVIEW_A\nREVIEW_B\nREVIEW_C' "$(delivery_gate_required_review_stages 标准)"
assert_lines $'REVIEW_A\nREVIEW_B\nREVIEW_C' "$(delivery_gate_required_review_stages 完整)"
assert_lines $'QA_A\nQA_B\nQA_C\nQA_D' "$(delivery_gate_required_qa_stages)"
assert_lines $'QA_A\nQA_B\nQA_C\nQA_D' "$(delivery_gate_required_qa_stages 轻量)"
assert_lines $'QA_A\nQA_B\nQA_C\nQA_D' "$(delivery_gate_required_qa_stages 标准)"
assert_lines $'QA_A\nQA_B\nQA_C\nQA_D' "$(delivery_gate_required_qa_stages 完整)"
```

Remove assertions that expect `旧 review 升档 helper` or `旧 QA 升档 helper`.

2. [T1] Add negative assertions for old delivery-owner wording.

Add these checks:

```bash
if grep -Fq '交付门禁gate evidence mismatches 旧分级矩阵' "$PM_SKILL"; then
  fail "delivery-owner skill must not reference 旧分级矩阵"
fi
if grep -Fq '动态质量升档' "$PM_SKILL" || grep -Fq '动态升档' "$PM_SKILL"; then
  fail "delivery-owner skill must not describe dynamic escalation"
fi
if grep -Fq '交付门禁审查分级' "$PM_SKILL"; then
  fail "delivery-owner skill must not consume交付门禁grade"
fi
if grep -E '^allowed-tools:.*(^|, )Edit(,|$)' "$PM_SKILL"; then
  fail "delivery-owner frontmatter must not allow Edit"
fi
grep -Fq 'REVIEW_A + REVIEW_B + REVIEW_C + QA_A + QA_B + QA_C + QA_D' "$PM_SKILL" || fail "delivery-owner skill missing fixed full gate"
```

3. [T1] Add reference and template assertions.

Add assertions that:

```bash
if grep -Fq '## 动态升档规则' "$DELIVERY_GATE_DOC"; then
  fail "delivery gate dispatch must not contain dynamic escalation section"
fi
if grep -Fq '按分级裁剪执行' "$DELIVERY_GATE_DOC"; then
  fail "delivery gate dispatch must not trim gates by grade"
fi
if grep -Fq 'Agent(subagent_type:' "$DISPATCH_GUIDE"; then
  fail "dispatch guide must not inline expert subagent pseudocode"
fi
if grep -Fq 'Developer 执行：test-first 实现' "$DISPATCH_GUIDE"; then
  fail "dispatch guide must not duplicate developer SOP"
fi
if grep -Fq '审查分级' "$CR_TEMPLATE" || grep -Fq '"grade"' "$CR_TEMPLATE"; then
  fail "code-review template must not expose grade"
fi
if grep -Fq '审查分级' "$QA_TEMPLATE" || grep -Fq '"grade"' "$QA_TEMPLATE"; then
  fail "qa template must not expose grade"
fi
```

4. [T1] Run the RED command.

Run:

```bash
bash tests/test-delivery-owner-gate-contract.sh
```

Expected: FAIL before implementation, with failures showing current old grade, dynamic escalation, `Edit`, or expert SOP content still present.

### Task 2: Refactor delivery-owner runtime documents [T2]

Context: The runtime documents should guide orchestration and progressive loading, not teach expert execution details.

Files:
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify: `shared/skills/delivery-owner/references/dispatch-guide.md`
- Modify: `shared/skills/delivery-owner/references/delivery-gate-dispatch.md`
- Test: `tests/test-delivery-owner-gate-contract.sh`

1. [T2] Rewrite `SKILL.md` as a thin control-plane entry.

Keep these sections in order:

```markdown
## HARD-GATE
## Runtime Authority
## 角色
## 前置条件
## 何时停下来问
## 熔断机制
## 流程
## 输出
## FORBIDDEN
## 完成校验
```

The交付门禁section must state fixed full gates:

```markdown
###交付门禁: 整体审查与验收
固定完整门禁：`REVIEW_A + REVIEW_B + REVIEW_C + QA_A + QA_B + QA_C + QA_D`。
`delivery-owner` 负责调度、消费 `code-review-result.json / qa-result.json`、维护修复循环与签收前证据状态；`review / qa / fix` 保持独立结论。

当执行交付门禁时：
→ 读取 `references/delivery-gate-dispatch.md` 获取固定完整门禁、review/QA handoff、修复循环、风险接受边界和汇总代理越权边界。
```

Remove wording that consumes 旧分级, computes 分级系数, maps high-risk drift to extra gates, or says dynamic escalation.

2. [T2] Rewrite `dispatch-guide.md` as a handoff contract.

Keep the top contract fields:

```markdown
Trigger:
Read:
Expect:
Consume:
Evidence:
Sync:
```

Make the body center on:

```markdown
## 派发合同
## Evidence In
## Evidence Out
## Control Decision
## Replan Boundary
## Parallel Boundary
```

Use the seven handoff elements from design: Requirement, Goal, Acceptance Criteria, Scope, Evidence In, Evidence Out, Control Decision. Do not include `Agent(subagent_type: ...)` examples or developer/verifier/fixer SOP paragraphs.

3. [T2] Rewrite `delivery-gate-dispatch.md` as fixed full-gate contract.

The top description must say fixed full gate. Include:

```markdown
## 固定完整门禁
| 类型 | 必跑阶段 | 消费工件 |
| Code Review | `REVIEW_A + REVIEW_B + REVIEW_C` | `code-review-result.json` |
| QA | `QA_A + QA_B + QA_C + QA_D` | `qa-result.json` |

## Handoff Boundary
## 修复循环与熔断
## 风险接受边界
## 汇总代理边界
```

Remove the grade table and `## 动态升档规则`.

4. [T2] Run targeted GREEN check for runtime docs.

Run:

```bash
bash tests/test-delivery-owner-gate-contract.sh
```

Expected: Remaining failures only point to scripts, templates, downstream tests, or gates assigned to T3/T4.

### Task 3: Align templates, helper, manifest, and legacy gates [T3]

Context: Full-gate behavior must be enforced in helpers and legacy projection templates without breaking existing hook imports.

Files:
- Modify: `shared/skills/delivery-owner/scripts/delivery-gate-stages.sh`
- Modify: `shared/skills/delivery-owner/scripts/manifest.json`
- Modify: `shared/skills/delivery-owner/scripts/completion_check.sh`
- Modify: `shared/skills/tech-lead/references/templates/plan-template.md`
- Modify: `shared/skills/tech-lead/scripts/completion_check.sh`
- Modify: `shared/skills/qa/references/templates/qa-report-template.md`
- Modify: `shared/skills/qa/scripts/completion_check.sh`
- Modify: `shared/skills/delivery-owner/references/templates/code-review-report-template.md`
- Test: `tests/test-delivery-owner-gate-contract.sh`
- Test: `tests/test-skill-output-and-gate-contract.sh`

1. [T3] Update `delivery-gate-stages.sh`.

Keep function names, ignore the input grade, and return full gates:

```bash
delivery_gate_required_review_stages() {
    printf '%s\n' "REVIEW_A" "REVIEW_B" "REVIEW_C"
}

delivery_gate_required_qa_stages() {
    printf '%s\n' "QA_A" "QA_B" "QA_C" "QA_D"
}
```

Remove escalation helper functions unless a caller still uses them. If callers remain, keep functions returning success with no output and add a comment that fixed full gates make extra-stage escalation unnecessary.

2. [T3] Update manifest helper wording.

Change the helper entry to fixed full-gate wording while keeping path stable:

```json
"failure_message": "delivery-owner delivery gate fixed full gate helper failed",
"exit_code_meanings": {
  "0": "fixed full gate function returned expected stage list or boolean status",
  "1": "invalid helper invocation"
}
```

3. [T3] Update legacy delivery-owner completion gate.

Replace required grade extraction failures with fixed full stages. The legacy gate should require `REVIEW_A/B/C` and `QA_A/B/C/D` report statuses and should not compare 报告分级 to 旧分级. Keep canonical readiness path unchanged.

4. [T3] Update legacy tech-lead gate and template.

Remove `##交付门禁审查分级` from `plan-template.md`. Remove `T7b` grade-required checks and replace matrix checks with a simple fixed full-gate handoff check if the legacy plan still includes a gate section.

5. [T3] Update review and QA templates.

For `code-review-report-template.md`, remove:

```markdown
审查分级: {轻量, 标准, 完整}
```

and remove `"grade"` from metadata.

For `qa-report-template.md`, remove grade lines and require all QA stages to carry real status in full execution scope:

```markdown
执行范围: full
```

No QA_B/C/D line should say it is not executed due to light or standard mode.

6. [T3] Update legacy QA gate.

Remove required `审查分级` parsing and 旧分级 comparison. Keep execution scope and QA_A/B/C/D status validation. `full` continues to forbid `N/A`.

7. [T3] Run targeted tests.

Run:

```bash
bash tests/test-delivery-owner-gate-contract.sh
bash tests/test-skill-output-and-gate-contract.sh
```

Expected: T3-specific assertions pass; downstream replay/rollout wording failures are handled by T4.

### Task 4: Update downstream tests, graders, replay, rollout, and archive stale role docs [T4]

Context: Old role-era docs and replay/rollout wording still teach dynamic escalation and grade fit. This task removes those active references or moves them out of the active context.

Files:
- Modify: `tests/test-delivery-owner-replay-contract.sh`
- Modify: `tests/test-delivery-owner-rollout-gate.sh`
- Modify: `tests/test-skill-output-and-gate-contract.sh`
- Modify: `tools/eval/graders/task-constraint-grader.md`
- Move: `docs/delivery-owner-role-20260411/` to `docs/archive/delivery-owner-role-20260411/`
- Create or modify fixtures if tests still need stable sample material.

1. [T4] Update replay scenario wording.

Replace `quality escalation after risk increase` with:

```text
full gate evidence after risk increase
```

The scenario checks that fixed full REVIEW/QA gates and regression evidence remain present after risk increases.

2. [T4] Update rollout rubric wording.

Replace rubric dimension `动态升档` with:

```text
完整门禁承接
```

Update test fixture score strings and `parse_score_from_rubric` calls.

3. [T4] Update `test-skill-output-and-gate-contract.sh`.

Replace old expectations:

```text
交付门禁gate evidence mismatches 旧分级矩阵
审查分级
```

with fixed full-gate expectations:

```text
delivery gate fixed full gate evidence is incomplete
QA_A/QA_B/QA_C/QA_D
REVIEW_A/REVIEW_B/REVIEW_C
```

Update legacy fixtures that include `##交付门禁审查分级` to use a fixed full-gate section.

4. [T4] Update task constraint grader.

Rename D4 to:

```markdown
### D4: 完整门禁与证据链承接
```

PASS: plan handoff and downstream artifacts preserve full REVIEW/QA evidence requirements. FAIL: plan or reports trim QA_B/C/D, rely on light/standard grade, or omit evidence refs.

5. [T4] Archive stale role docs.

Move `docs/delivery-owner-role-20260411/` to `docs/archive/delivery-owner-role-20260411/`. If an active test still needs one fixture, copy the exact minimum file into `tests/fixtures/delivery-owner-role/` before archiving and update test paths.

6. [T4] Run downstream checks.

Run:

```bash
bash tests/test-delivery-owner-replay-contract.sh
bash tests/test-delivery-owner-rollout-gate.sh
bash tests/test-skill-output-and-gate-contract.sh
```

Expected: no assertion refers to grade trimming or dynamic escalation as current behavior.

### Task 5: Verify the complete small-chain delivery [T5]

Context: Completion requires fresh proof mapped to the accepted success criteria and a clean diff review.

Files:
- Read: all changed files
- Test: all delivery-owner and standard-chain contract tests listed below

1. [T5] Run delivery gate contract.

Run:

```bash
bash tests/test-delivery-owner-gate-contract.sh
```

Expected: PASS.

2. [T5] Run replay contract.

Run:

```bash
bash tests/test-delivery-owner-replay-contract.sh
```

Expected: PASS.

3. [T5] Run rollout gate.

Run:

```bash
bash tests/test-delivery-owner-rollout-gate.sh
```

Expected: PASS.

4. [T5] Run standard-chain skill structure.

Run:

```bash
bash tests/test-standard-chain-skill-structure.sh
```

Expected: PASS.

5. [T5] Run broad gate contract.

Run:

```bash
bash tests/test-skill-output-and-gate-contract.sh
```

Expected: PASS.

6. [T5] Run diff hygiene.

Run:

```bash
git diff --check
```

Expected: no output and exit code 0.

7. [T5] Review diff scope.

Run:

```bash
git diff --stat
git diff -- docs/delivery-owner-control-plane/2026-04-21-progressive-loading shared/skills/delivery-owner shared/skills/tech-lead shared/skills/qa tests tools/eval/graders docs/archive
```

Expected: diff only covers planned files or moved stale docs; unrelated local changes remain untouched.

## Self-Review Checklist

- Every task in `tasks.md` appears in this plan.
- Every `[T1]` through `[T5]` appears in `tasks.md`.
- Every design success criterion maps to at least one task.
- No task depends on an undefined task.
- Verification commands are explicit and executable.
