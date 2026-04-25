# Skill Quality Standard MVP Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Turn the Phase 1 design into an executable MVP quality standard, align `skill-harness` as the read-only assurance consumer, and prove the two validation samples with reviewable findings.

**Architecture:** Reuse the existing first-party standard, `skill-harness` contract files, and shell proof style. Keep the standard as the authority, keep `skill-harness` as a consumer, and use targeted shell tests plus sample findings to prove the MVP boundaries without creating a new eval platform or second quality framework.

**Tech Stack:** Markdown standard and Skill files, Bash contract tests, existing Python task-plan checker, existing shell test runner conventions.

---

## Execution Preconditions

- Run in the existing isolated worktree `available-ermine`.
- Run `git status --short --branch` before implementation and preserve unrelated user changes.
- Follow RED -> GREEN -> REFACTOR for every changed behavior.
- Do not introduce a new JSON fact source for Phase 1 sample findings; the design keeps structured Markdown as sufficient unless a named machine consumer exists.
- Reuse the existing `shared/reference/Skill质量标准.md`, `shared/skills/skill-harness/SKILL.md`, and harness shell tests instead of creating a parallel standard or checker.

## File Boundaries

- Modify: `shared/reference/Skill质量标准.md`
- Modify: `shared/skills/scan/references/skills-scan-rules.md`
- Modify: `tests/test-skill-quality-standard.sh`
- Modify: `tests/test-skill-context-budget.sh`
- Modify: `shared/skills/skill-harness/SKILL.md`
- Modify: `shared/skills/skill-harness/references/audit-method.md`
- Modify: `tests/test-skill-harness-contract.sh`
- Create: `tests/test-skill-harness-mvp-boundary.sh`
- Create: `docs/skill-quality-standard-mvp/2026-04-24-phase-1-design/sample-findings.md`
- Create: `tests/test-skill-quality-standard-mvp-samples.sh`
- Create: `docs/skill-quality-standard-mvp/2026-04-24-phase-1-design/verify-change-report.md`
- Modify: `tests/run-all.sh`
- Modify: `tests/test-run-all-runner-contract.sh`
- Modify: `tests/test-developer-real-flow-value-pilot.sh` if full-suite shellcheck exposes revspec quoting drift
- Modify: `tests/test-skill-output-and-gate-contract.sh` if full-suite canonical gate setup lacks git traceability

## Task 1: Phase 1 Standard Truth Source [T1]

Context: The existing standard already contains useful D1-D9 material, resource contracts, and JSON consumer rules. Phase 1 must narrow its authority so D1-D8 are the runtime-surface quality standard, D9 is readiness-only in this MVP, and line-count budgets become warning heuristics rather than hard quality standards.

Files:
- Modify: `shared/reference/Skill质量标准.md`
- Modify: `shared/skills/scan/references/skills-scan-rules.md`
- Modify: `tests/test-skill-quality-standard.sh`
- Modify: `tests/test-skill-context-budget.sh`

1. [T1] Write the RED assertions for the Phase 1 standard boundary.

Replace the old expectation block in `tests/test-skill-quality-standard.sh` with assertions for these exact strings:

```bash
assert_present 'Phase 1 MVP' "$STANDARD"
assert_present '适用范围：standard-chain first-party Skills 与 skill-harness' "$STANDARD"
assert_present 'D1-D8 是运行时表面质量标准' "$STANDARD"
assert_present 'D9 在 Phase 1 只作为 readiness 边界' "$STANDARD"
assert_present 'PASS / FAIL / COMMENT' "$STANDARD"
assert_present 'line-count budgets 只能作为 COMMENT 或 warning-level signal' "$STANDARD"
assert_present 'skill-harness 消费本标准，不定义本标准' "$STANDARD"
assert_absent '行数基线：' "$STANDARD"
assert_absent '按 `Skill质量标准.md` 的类型分档检查 `SKILL.md` 行数 | 严重' "$SCAN_RULES"
assert_present '行数预算超出 | 固定行数预算只产生 warning-level signal' "$SCAN_RULES"
assert_present 'context budget is a warning-level health signal' "$ROOT/tests/test-skill-context-budget.sh"
```

2. [T1] Run the RED commands.

Run: `bash tests/test-skill-quality-standard.sh`
Expected: FAIL mentioning the missing `Phase 1 MVP` or old line-count expectation.

Run: `bash tests/test-skill-context-budget.sh`
Expected: current command may PASS before the line-count assertion is added; after adding the assertion it must fail until the script header and behavior are updated.

3. [T1] Rewrite `shared/reference/Skill质量标准.md` around the MVP contract.

Keep the title and D1-D9 table, then update the opening section to include:

```markdown
本文是 first-party Skill 质量标准真源。Phase 1 MVP 的适用范围：standard-chain first-party Skills 与 skill-harness。

Phase 1 只裁决 Skill runtime surface 是否清晰、可加载、可遵循、可审计。D1-D8 是运行时表面质量标准；D9 在 Phase 1 只作为 readiness 边界，不能被解释为有效性、retain、retire 或 proven-effectiveness 结论。

`skill-harness` 消费本标准，不定义本标准，不自证正确，不做最终生命周期决定。
```

4. [T1] Update the finding boundary section.

Add or replace the result language with:

```markdown
Phase 1 使用 findings，不使用数字评分。

`FAIL` 只用于阻断 Skill 被可靠加载、遵循或审计的问题。
`COMMENT` 用于 warning-level 风险，包括表达、重复、行数或上下文预算信号；除非有证据证明影响角色、触发、加载、权限、输出或证据合同，否则 COMMENT 不阻断。
每个 finding 必须映射到一个 MVP quality concern。只引用 `skill-harness` 维度、历史标签、固定行数阈值或 D9 readiness metadata 不能作为阻断依据。
```

5. [T1] Replace the hard line-count budget section.

Remove the old `行数基线：` table and add:

```markdown
## 本地启发式

Line-count budgets such as `250/200/150/100` 只能作为 COMMENT 或 warning-level signal。固定行数阈值不是 Phase 1 hard quality standard。

当行数或上下文预算产生风险时，finding 必须说明具体运行时影响：例如 active path 噪音导致触发混淆、低频细节没有下沉到资源、或 reference 合同不可消费。没有这种影响证据时，行数只能提示人工复核。
```

6. [T1] Update the D9 section.

Keep `## D9 存在合理性`, but make the Phase 1 boundary explicit:

```markdown
D9 在完整生命周期中仍由 `{{RUNTIME_HOME}}/reference/Skill能力有效性标准.md` 和 `{{RUNTIME_HOME}}/reference/Skill生命周期管理.md` 细化。Phase 1 不裁决 retain、optimize 或 retire。

Phase 1 只检查 readiness evidence 是否存在并被正确解释：`eval-type`、`evals/evals.json`、偏好锚点或 grader dimensions、`evals/lifecycle-review.json` 可以证明 review frame 存在；它们不能证明有效性、保留、退役或长期价值。
```

7. [T1] Align scan and context-budget checks.

In `shared/skills/scan/references/skills-scan-rules.md`, change the R2 line-count row to:

```markdown
| 行数预算超出 | 固定行数预算只产生 warning-level signal；需要人工判断是否造成 active path 噪音或加载边界问题 | 警告 |
```

In `tests/test-skill-context-budget.sh`, replace the hard-gate header with:

```bash
# Context budget checker
# Phase 1: SKILL.md line budgets are warning-level health signals, not hard quality standards.
```

Change the `if [ "$skill_lines" -gt "$skill_budget" ]; then fail ... fi` branch to print a WARN and increment `warn_count` instead of failing.

8. [T1] Run the GREEN commands.

Run: `bash tests/test-skill-quality-standard.sh`
Expected: `[PASS] skill quality standard`.

Run: `bash tests/test-skill-context-budget.sh`
Expected: command exits 0 and prints PASS or WARN lines without failing solely on SKILL.md line budgets.

## Task 2: skill-harness MVP Boundary [T2]

Context: `skill-harness` already has read-first tools and deterministic field gates. This task changes its authority language: it consumes the standard, maps findings to MVP concerns, and treats D9 evidence as readiness rather than lifecycle proof.

Files:
- Modify: `shared/skills/skill-harness/SKILL.md`
- Modify: `shared/skills/skill-harness/references/audit-method.md`
- Modify: `tests/test-skill-harness-contract.sh`
- Create: `tests/test-skill-harness-mvp-boundary.sh`

1. [T2] Create the RED test for the MVP boundary.

Create `tests/test-skill-harness-mvp-boundary.sh`:

```bash
#!/usr/bin/env bash
# File role: prove skill-harness consumes the Phase 1 MVP standard without becoming a second source of truth.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/shared/skills/skill-harness/SKILL.md"
AUDIT="$ROOT/shared/skills/skill-harness/references/audit-method.md"
STANDARD="$ROOT/shared/reference/Skill质量标准.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local needle="$1"
  local file="$2"
  grep -Fq "$needle" "$file" || fail "missing required content in ${file#$ROOT/}: $needle"
}

assert_absent() {
  local needle="$1"
  local file="$2"
  if grep -Fq "$needle" "$file"; then
    fail "forbidden content in ${file#$ROOT/}: $needle"
  fi
}

test -f "$STANDARD" || fail "missing Skill quality standard"
assert_present 'skill-harness 消费本标准，不定义本标准' "$STANDARD"

for file in "$SKILL" "$AUDIT"; do
  assert_present '{{RUNTIME_HOME}}/reference/Skill质量标准.md' "$file"
  assert_present 'consumes the Phase 1 MVP standard' "$file"
  assert_present 'must not define the standard' "$file"
  assert_present 'must not self-certify' "$file"
  assert_present 'must not make final lifecycle decisions' "$file"
  assert_present 'MVP quality concern' "$file"
  assert_present 'D9 readiness evidence must not produce retain, retire, or proven-effectiveness conclusions' "$file"
  assert_absent 'evidence-backed retain/optimize/retire routing' "$file"
done

printf '[PASS] skill-harness MVP boundary\n'
```

2. [T2] Run the RED command.

Run: `bash tests/test-skill-harness-mvp-boundary.sh`
Expected: FAIL because current files still mention lifecycle routing and lack MVP consumer language.

3. [T2] Update `shared/skills/skill-harness/SKILL.md`.

Add to `## Role`:

```markdown
`skill-harness` consumes the Phase 1 MVP standard at `{{RUNTIME_HOME}}/reference/Skill质量标准.md`. It must not define the standard, must not self-certify, and must not make final lifecycle decisions. Every blocking finding maps to one MVP quality concern from the standard before any `skill-harness` audit dimension is used as an output label.
```

Replace the D9 flow step with:

```markdown
For first-party lifecycle readiness, read D9 readiness evidence from `{{RUNTIME_HOME}}/reference/Skill能力有效性标准.md`: `eval-type`, matching `evals/evals.json`, anchors or grader dimensions, and latest `evals/lifecycle-review.json`. D9 readiness evidence must not produce retain, retire, or proven-effectiveness conclusions in Phase 1.
```

4. [T2] Update `shared/skills/skill-harness/references/audit-method.md`.

Add to the `Expect:` line or first body paragraph:

```markdown
The audit method consumes the Phase 1 MVP standard at `{{RUNTIME_HOME}}/reference/Skill质量标准.md`; it must not define the standard, must not self-certify, and must not make final lifecycle decisions.
```

Replace the D9 lifecycle paragraph with:

```markdown
## D9 Readiness Boundary

When the target is a first-party Skill, check D9 readiness evidence using `{{RUNTIME_HOME}}/reference/Skill能力有效性标准.md`. The audit reads `eval-type`, matching `evals/evals.json`, required `preference_anchors` or `grader_dimensions`, and latest `evals/lifecycle-review.json`.

D9 readiness evidence must not produce retain, retire, or proven-effectiveness conclusions. A D9 finding must map to an MVP quality concern, such as evidence boundary or lifecycle-overclaim risk, before `Verification` or `Evolution` is used as an output dimension.
```

5. [T2] Update `tests/test-skill-harness-contract.sh`.

Replace the old calibration-verdict assertion:

```bash
grep -Fq 'Correctness PASS / Practice FAIL' "$SKILL_FILE" || fail "missing delivery-owner calibration verdict"
```

with:

```bash
grep -Fq 'legacy_baseline_label' "$SKILL_FILE" || fail "missing legacy baseline label boundary"
grep -Fq '{{RUNTIME_HOME}}/reference/Skill质量标准.md' "$SKILL_FILE" || fail "missing MVP standard route"
```

6. [T2] Run the GREEN commands.

Run: `bash tests/test-skill-harness-mvp-boundary.sh`
Expected: `[PASS] skill-harness MVP boundary`.

Run: `bash tests/test-skill-harness-contract.sh && bash tests/test-skill-harness-responsibility-contract.sh && bash tests/test-skill-harness-legacy-label-migration.sh`
Expected: each command exits 0 and prints its `[PASS]` line.

## Task 3: Phase 1 Sample Findings [T3]

Context: The design requires actual findings for `delivery-owner` and `skill-harness`, not a narrative statement. Markdown is enough because there is no named machine consumer for the sample package.

Files:
- Create: `docs/skill-quality-standard-mvp/2026-04-24-phase-1-design/sample-findings.md`
- Create: `tests/test-skill-quality-standard-mvp-samples.sh`

1. [T3] Create the RED test for sample findings.

Create `tests/test-skill-quality-standard-mvp-samples.sh`:

```bash
#!/usr/bin/env bash
# File role: prove Phase 1 sample findings are reviewable and map to MVP quality concerns.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SAMPLES="$ROOT/docs/skill-quality-standard-mvp/2026-04-24-phase-1-design/sample-findings.md"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_present() {
  local needle="$1"
  grep -Fq "$needle" "$SAMPLES" || fail "sample findings missing: $needle"
}

assert_absent_authority() {
  local needle="$1"
  if grep -F "Authority:" "$SAMPLES" | grep -Fq "$needle"; then
    fail "sample findings use forbidden authority: $needle"
  fi
}

test -f "$SAMPLES" || fail "missing sample findings"
assert_present '## delivery-owner Findings'
assert_present '## skill-harness Findings'

for field in 'Verdict:' 'MVP Quality Concern:' 'Evidence:' 'Impact:' 'Recommendation:' 'Dimension Label Only:' 'Authority:'; do
  assert_present "$field"
done

for concern in \
  'Role clarity' \
  'Evidence-backed claims' \
  'Harness governance' \
  'D9 readiness boundary'; do
  assert_present "MVP Quality Concern: $concern"
done

assert_absent_authority 'Correctness PASS / Practice FAIL'
assert_absent_authority '250/200/150/100'
assert_absent_authority 'D9 readiness metadata'
assert_absent_authority 'skill-harness dimension'

printf '[PASS] skill quality standard MVP samples\n'
```

2. [T3] Run the RED command.

Run: `bash tests/test-skill-quality-standard-mvp-samples.sh`
Expected: FAIL because `sample-findings.md` does not exist.

3. [T3] Create `sample-findings.md`.

Use this structure and keep every finding field explicit:

```markdown
# Phase 1 MVP Sample Findings

Source design: ./design.md

## delivery-owner Findings

### DO-F1

Verdict: COMMENT
MVP Quality Concern: Role clarity
Evidence: `shared/skills/delivery-owner/SKILL.md`
Impact: The Skill is a delivery control plane with explicit gates and dispatch responsibilities; this supports Phase 1 sample calibration without making delivery-owner a source of the quality standard.
Recommendation: Keep delivery-owner as a validation sample and evaluate it with the MVP standard language.
Dimension Label Only: Yes, any `skill-harness` dimension used for this finding is an output label, not authority.
Authority: Phase 1 MVP standard role-clarity concern.

### DO-F2

Verdict: PASS
MVP Quality Concern: Evidence-backed claims
Evidence: `shared/skills/delivery-owner/SKILL.md`
Impact: Completion gates require developer, verify, review, QA, consistency, signoff, and user-decision evidence before delivery claims.
Recommendation: Preserve delivery-owner as a high-state sample for checking evidence contract language.
Dimension Label Only: Yes.
Authority: Phase 1 MVP evidence-chain concern.

## skill-harness Findings

### SH-F1

Verdict: PASS
MVP Quality Concern: Harness governance
Evidence: `shared/skills/skill-harness/SKILL.md`; `shared/skills/skill-harness/references/audit-method.md`
Impact: skill-harness is positioned as a read-only assurance layer that consumes the standard and cannot self-certify or make final lifecycle decisions.
Recommendation: Keep `shared/reference/Skill质量标准.md` as the authority and use harness dimensions only as output labels.
Dimension Label Only: Yes.
Authority: Phase 1 MVP harness-governance concern.

### SH-F2

Verdict: COMMENT
MVP Quality Concern: D9 readiness boundary
Evidence: `shared/skills/skill-harness/SKILL.md`; `shared/skills/skill-harness/references/audit-method.md`
Impact: D9 evidence is useful as readiness framing, but Phase 1 must not convert it into effectiveness, retain, or retire conclusions.
Recommendation: Keep lifecycle decision rules in the lifecycle references and report only readiness-boundary findings in Phase 1.
Dimension Label Only: Yes.
Authority: Phase 1 MVP D9 readiness boundary.
```

4. [T3] Run the GREEN command.

Run: `bash tests/test-skill-quality-standard-mvp-samples.sh`
Expected: `[PASS] skill quality standard MVP samples`.

## Task 4: Verification Package [T4]

Context: This task proves the full small-chain package against the design and records the evidence for verify-change.

Files:
- Modify: `docs/skill-quality-standard-mvp/2026-04-24-phase-1-design/tasks.md`
- Create: `docs/skill-quality-standard-mvp/2026-04-24-phase-1-design/verify-change-report.md`
- Modify: `tests/run-all.sh`
- Modify: `tests/test-run-all-runner-contract.sh`
- Modify: `tests/test-developer-real-flow-value-pilot.sh` if full-suite shellcheck exposes revspec quoting drift
- Modify: `tests/test-skill-output-and-gate-contract.sh` if full-suite canonical gate setup lacks git traceability

1. [T4] Run primary proof commands.

Run:

```bash
bash tests/test-skill-quality-standard.sh
bash tests/test-skill-context-budget.sh
bash tests/test-skill-harness-mvp-boundary.sh
bash tests/test-skill-quality-standard-mvp-samples.sh
```

Expected: each command exits 0 with a `[PASS]` line or context-budget PASS/WARN output.

2. [T4] Wire the MVP tests into the repository runner.

Run:

```bash
bash tests/test-run-all-runner-contract.sh
shellcheck -x tests/run-all.sh tests/test-run-all-runner-contract.sh tests/test-skill-harness-mvp-boundary.sh tests/test-skill-quality-standard-mvp-samples.sh
```

Expected: runner contract exits 0 and the full/quick plans include `test-skill-quality-standard.sh`, `test-skill-quality-standard-mvp-samples.sh`, and `test-skill-harness-mvp-boundary.sh`; shellcheck exits 0.

3. [T4] Run targeted existing smoke commands.

Run:

```bash
bash tests/test-skill-harness-contract.sh
bash tests/test-skill-harness-responsibility-contract.sh
bash tests/test-skill-harness-legacy-label-migration.sh
bash tests/test-skill-lifecycle-eval-framework.sh
```

Expected: each command exits 0.

4. [T4] Run full-suite regression and small-chain consistency.

Run:

```bash
bash tests/run-all.sh --full --profile
python3 tools/community/check_task_plan_consistency.py docs/skill-quality-standard-mvp/2026-04-24-phase-1-design/tasks.md docs/skill-quality-standard-mvp/2026-04-24-phase-1-design/plan.md
git diff --check
git status --short --branch
```

Expected: full runner prints `All tests passed`; consistency checker prints `[PASS] tasks-plan consistency`; `git diff --check` exits 0; status shows only expected files for this small-chain.

5. [T4] Write `verify-change-report.md`.

Record the commands and outcomes in this shape:

```markdown
# Verify Change Report

## Status
- PASS

## CRITICAL
- none

## WARNING
- none

## SUGGESTION
- none

## Evidence
- `bash tests/run-all.sh --full --profile`: PASS
- `bash tests/test-run-all-runner-contract.sh`: PASS
- `shellcheck -x tests/run-all.sh tests/test-run-all-runner-contract.sh tests/test-skill-harness-mvp-boundary.sh tests/test-skill-quality-standard-mvp-samples.sh`: PASS
- `bash tests/test-skill-quality-standard.sh`: PASS
- `bash tests/test-skill-context-budget.sh`: PASS or WARN-only exit 0
- `bash tests/test-skill-harness-mvp-boundary.sh`: PASS
- `bash tests/test-skill-quality-standard-mvp-samples.sh`: PASS
- `bash tests/test-skill-harness-contract.sh`: PASS
- `bash tests/test-skill-harness-responsibility-contract.sh`: PASS
- `bash tests/test-skill-harness-legacy-label-migration.sh`: PASS
- `bash tests/test-skill-lifecycle-eval-framework.sh`: PASS
- `python3 tools/community/check_task_plan_consistency.py docs/skill-quality-standard-mvp/2026-04-24-phase-1-design/tasks.md docs/skill-quality-standard-mvp/2026-04-24-phase-1-design/plan.md`: PASS
- `git diff --check`: PASS
```

6. [T4] Mark completed tasks in `tasks.md`.

After each task's proof command is green, change that task line from `- [ ]` to `- [x]`.

7. [T4] Run final consistency check.

Run: `python3 tools/community/check_task_plan_consistency.py docs/skill-quality-standard-mvp/2026-04-24-phase-1-design/tasks.md docs/skill-quality-standard-mvp/2026-04-24-phase-1-design/plan.md`
Expected: `[PASS] tasks-plan consistency (4 tasks, ... plan steps)`.
