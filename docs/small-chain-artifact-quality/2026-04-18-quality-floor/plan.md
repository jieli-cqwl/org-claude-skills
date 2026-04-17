# Small-Chain Artifact Quality Floor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Add a structured quality floor for small-chain `design.md`, `tasks.md`, and `plan.md` artifacts.

**Architecture:** The change is contract-driven: `contracts/small-chain.yaml` declares required artifact fields, brainstorming templates and checks consume the design contract, writing-plans templates consume task/plan contracts, and boundary tests prove the repository-local overlays remain declared. Existing shell contract tests remain the proving layer so no new automation runner is introduced.

**Tech Stack:** Markdown skill docs, YAML contracts, Bash contract tests, existing Python task-plan consistency checker.

---

### Task 1: Small-Chain Artifact Contract [T1]

Context: The contract is the authority source for the new quality floor. Only append `key_fields` under existing artifact outputs; do not change the chain order, inputs, outputs, or consumers.

Files:
- Modify: `tests/test-small-chain-boundary.sh`
- Modify: `contracts/small-chain.yaml`
- Test: `tests/test-small-chain-boundary.sh`

1. [T1] Add failing contract assertions for `key_fields`

Add these variables after `README_DOC`:

```bash
BRAINSTORMING_SKILL="$ROOT/community/superpowers/skills/brainstorming/SKILL.md"
WRITING_PLANS_SKILL="$ROOT/community/superpowers/skills/writing-plans/SKILL.md"
DESIGN_TEMPLATE="$ROOT/community/superpowers/skills/brainstorming/references/design-template.md"
DESIGN_CHECKLIST="$ROOT/community/superpowers/skills/brainstorming/references/design-completeness-checklist.md"
```

Add this helper after `fail()`:

```bash
assert_present() {
  local pattern="$1"
  local file="$2"
  grep -Fq "$pattern" "$file" || fail "缺少 small-chain 质量下限内容: ${file#"$ROOT"/} :: $pattern"
}
```

Add these assertions after the chain stage loop:

```bash
assert_present 'key_fields:' "$CHAIN_CONTRACT"
assert_present 'always_required:' "$CHAIN_CONTRACT"
assert_present 'problem_statement' "$CHAIN_CONTRACT"
assert_present 'goals_success_criteria' "$CHAIN_CONTRACT"
assert_present 'alternatives_considered' "$CHAIN_CONTRACT"
assert_present 'conditionally_required:' "$CHAIN_CONTRACT"
assert_present 'change_scope' "$CHAIN_CONTRACT"
assert_present 'downstream_impact' "$CHAIN_CONTRACT"
assert_present 'per_task:' "$CHAIN_CONTRACT"
assert_present 'traces' "$CHAIN_CONTRACT"
assert_present 'depends' "$CHAIN_CONTRACT"
assert_present 'complexity' "$CHAIN_CONTRACT"
assert_present 'per_task_section:' "$CHAIN_CONTRACT"
assert_present 'context' "$CHAIN_CONTRACT"
assert_present 'files' "$CHAIN_CONTRACT"
assert_present 'steps' "$CHAIN_CONTRACT"
```

2. [T1] Run RED for the contract assertions

Run: `bash tests/test-small-chain-boundary.sh`

Expected: FAIL with `缺少 small-chain 质量下限内容: contracts/small-chain.yaml :: key_fields:`.

3. [T1] Add `key_fields` to `contracts/small-chain.yaml`

For the brainstorming `design.md` output, add:

```yaml
        key_fields:
          always_required:
            - problem_statement
            - goals_success_criteria
            - approach
            - alternatives_considered
            - risks
          conditionally_required:
            - change_scope
            - invariants
            - downstream_impact
```

For the writing-plans `tasks.md` output, add:

```yaml
        key_fields:
          per_task:
            - deliverable
            - acceptance_criteria
            - traces
            - depends
            - complexity
```

For the writing-plans `plan.md` output, add:

```yaml
        key_fields:
          per_task_section:
            - context
            - files
            - steps
```

4. [T1] Run GREEN for the contract assertions

Run: `bash tests/test-small-chain-boundary.sh`

Expected: PASS through all existing assertions and print `[PASS] small-chain boundary`.

5. [T1] Commit the contract change

Run:

```bash
git add tests/test-small-chain-boundary.sh contracts/small-chain.yaml
git commit -m "test: cover small-chain artifact key fields"
```

### Task 2: Brainstorming Design Completeness Floor [T2]

Context: Brainstorming already writes `design.md`; this task strengthens its template and self-review while preserving the existing conversation flow and four self-review checks. The new checklist is separate because it is the validation procedure, not the template.

Files:
- Modify: `tests/test-small-chain-boundary.sh`
- Modify: `community/superpowers/skills/brainstorming/SKILL.md`
- Modify: `community/superpowers/skills/brainstorming/references/design-template.md`
- Create: `community/superpowers/skills/brainstorming/references/design-completeness-checklist.md`
- Test: `tests/test-small-chain-boundary.sh`

1. [T2] Add failing brainstorming assertions

Add these assertions after the T1 contract assertions:

```bash
test -f "$DESIGN_CHECKLIST" || fail "缺少 design completeness checklist: ${DESIGN_CHECKLIST#"$ROOT"/}"
assert_present '5. Content completeness' "$BRAINSTORMING_SKILL"
assert_present 'references/design-completeness-checklist.md' "$BRAINSTORMING_SKILL"
assert_present 'contracts/small-chain.yaml -> brainstorming -> design.md key_fields' "$DESIGN_TEMPLATE"
assert_present '## Goals & Success Criteria' "$DESIGN_TEMPLATE"
assert_present '## Change Scope' "$DESIGN_TEMPLATE"
assert_present '## Invariants' "$DESIGN_TEMPLATE"
assert_present '## Downstream Impact' "$DESIGN_TEMPLATE"
assert_present '## Risks' "$DESIGN_TEMPLATE"
for item in D1 D2 D3 D4 D5 D6 D7 D8; do
  assert_present "| $item |" "$DESIGN_CHECKLIST"
done
assert_present 'D1、D2、D3、D4、D8 不允许 Missing' "$DESIGN_CHECKLIST"
```

2. [T2] Run RED for brainstorming assertions

Run: `bash tests/test-small-chain-boundary.sh`

Expected: FAIL with `缺少 design completeness checklist`.

3. [T2] Expand `design-template.md`

Replace the current template with sections for contract reference, Why, Scope, Approach, Alternatives, Key Decisions, Goals & Success Criteria, Change Scope, Invariants, Downstream Impact, and Risks. Use this exact contract reference line near the top:

```markdown
> 结构参照：contracts/small-chain.yaml -> brainstorming -> design.md key_fields
```

4. [T2] Add `design-completeness-checklist.md`

Create a checklist containing D1-D8, mapping each item to one `contracts/small-chain.yaml` `design.md` key_field:

```markdown
# Design Completeness Checklist

Contract source: `contracts/small-chain.yaml -> brainstorming -> design.md key_fields`

## Usage

Run this checklist during brainstorming spec self-review. Mark each item Clear, Partial, Missing, or N/A. Partial and Missing items must be fixed inline before writing-plans. D5, D6, and D7 may be N/A only with a concrete reason.

## Checks

| # | Dimension | key_field | Required when | Status |
|---|-----------|-----------|---------------|--------|
| D1 | Problem statement | problem_statement | Always | Clear / Partial / Missing |
| D2 | Goals and success criteria | goals_success_criteria | Always | Clear / Partial / Missing |
| D3 | Approach | approach | Always | Clear / Partial / Missing |
| D4 | Alternatives considered | alternatives_considered | Always | Clear / Partial / Missing |
| D5 | Change scope | change_scope | Modification work | Clear / Partial / Missing / N/A |
| D6 | Invariants | invariants | Modification work | Clear / Partial / Missing / N/A |
| D7 | Downstream impact | downstream_impact | Downstream consumers exist | Clear / Partial / Missing / N/A |
| D8 | Risks | risks | Always | Clear / Partial / Missing |

## Decision Rules

- D1、D2、D3、D4、D8 不允许 Missing.
- D5、D6、D7 may be N/A only when the design states the reason.
- Partial means the section exists but does not yet give enough information for writing-plans.
- Missing or Partial items must be fixed in `design.md` before handoff.
```

5. [T2] Add Content completeness to brainstorming spec self-review

Append this item after the existing four self-review checks:

Use this exact item text in the numbered self-review list:

```markdown
Content completeness
- Run `references/design-completeness-checklist.md` against the spec.
- Fix any Missing or Partial items inline.
```

6. [T2] Run GREEN for brainstorming assertions

Run: `bash tests/test-small-chain-boundary.sh`

Expected: PASS and print `[PASS] small-chain boundary`.

7. [T2] Commit the brainstorming quality floor

Run:

```bash
git add tests/test-small-chain-boundary.sh community/superpowers/skills/brainstorming/SKILL.md community/superpowers/skills/brainstorming/references/design-template.md community/superpowers/skills/brainstorming/references/design-completeness-checklist.md
git commit -m "feat: add brainstorming design completeness floor"
```

### Task 3: Writing-Plans Task And Plan Fields [T3]

Context: Writing-plans is the consumer of `design.md` and producer of `tasks.md` and `plan.md`. The new fields are additive and keep task lines in the standard unchecked task format, preserving the existing parser and subagent controller format.

Files:
- Modify: `tests/test-small-chain-boundary.sh`
- Modify: `community/superpowers/skills/writing-plans/SKILL.md`
- Test: `tests/test-small-chain-boundary.sh`

1. [T3] Add failing writing-plans assertions

Add these assertions after the T2 assertions:

```bash
assert_present '  - Traces: {design.md Goals & Success Criteria 表中的目标名}' "$WRITING_PLANS_SKILL"
assert_present '  - Depends: {依赖的 task ID，无依赖写 -}' "$WRITING_PLANS_SKILL"
assert_present '  - Complexity: {simple | moderate | complex}' "$WRITING_PLANS_SKILL"
assert_present 'Context: {1-2 句设计意图和关键约束}' "$WRITING_PLANS_SKILL"
assert_present '5. Trace completeness' "$WRITING_PLANS_SKILL"
assert_present "Every success criterion in design.md Goals & Success Criteria" "$WRITING_PLANS_SKILL"
assert_present "is referenced by at least one task's Traces field" "$WRITING_PLANS_SKILL"
assert_present '6. Dependency validity' "$WRITING_PLANS_SKILL"
assert_present 'No circular dependencies.' "$WRITING_PLANS_SKILL"
assert_present '7. Context presence' "$WRITING_PLANS_SKILL"
assert_present 'Every task section in plan.md has a non-empty Context field.' "$WRITING_PLANS_SKILL"
```

2. [T3] Run RED for writing-plans assertions

Run: `bash tests/test-small-chain-boundary.sh`

Expected: FAIL with the first missing `Traces` assertion.

3. [T3] Extend the `tasks.md` template in writing-plans

Change the template from:

```markdown
task line: unchecked T1 {deliverable description}
  - AC: {verifiable criteria}
```

to:

```markdown
task line: unchecked T1 {deliverable description}
  - AC: {verifiable criteria}
  - Traces: {design.md Goals & Success Criteria 表中的目标名}
  - Depends: {依赖的 task ID，无依赖写 -}
  - Complexity: {simple | moderate | complex}
```

4. [T3] Add `Context` to the `plan.md` task section template

Change the task section template so it starts with:

```markdown
task heading: Task N: [Component Name] [T{N}]

Context: {1-2 句设计意图和关键约束}

Files:
- Create: `exact/path/to/file.py`
```

5. [T3] Extend the writing-plans HARD-GATE

Append these checks after the existing four hard-gate checks:

Use these exact check names and bullet bodies in the numbered hard-gate list:

```markdown
Trace completeness
- Every success criterion in design.md Goals & Success Criteria
  is referenced by at least one task's Traces field.
Dependency validity
- Every task ID in Depends fields exists in tasks.md.
- No circular dependencies.
Context presence
- Every task section in plan.md has a non-empty Context field.
```

6. [T3] Run GREEN for writing-plans assertions

Run: `bash tests/test-small-chain-boundary.sh`

Expected: PASS and print `[PASS] small-chain boundary`.

7. [T3] Commit the writing-plans quality floor

Run:

```bash
git add tests/test-small-chain-boundary.sh community/superpowers/skills/writing-plans/SKILL.md
git commit -m "feat: add writing-plans artifact traceability fields"
```

### Task 4: Superpowers Overlay Declarations [T4]

Context: The local community/superpowers copy intentionally forks upstream for the new checklist and writing-plans contract. Boundary declarations make those forks explicit for future sync and review work.

Files:
- Modify: `tests/test-superpowers-boundary.sh`
- Modify: `contracts/superpowers-boundary.yaml`
- Test: `tests/test-superpowers-boundary.sh`

1. [T4] Add failing boundary assertions

Add these assertions before `echo "[PASS] superpowers boundary"`:

```bash
grep -Fq 'brainstorming_design_completeness_gate' "$BOUNDARY" || fail "boundary contract 缺少 brainstorming design completeness fork"
grep -Fq 'writing_plans_task_traceability' "$BOUNDARY" || fail "boundary contract 缺少 writing-plans task traceability fork"
grep -Fq 'community/superpowers/skills/brainstorming/references/design-completeness-checklist.md' "$BOUNDARY" || fail "boundary contract 缺少 design completeness checklist overlay"
```

2. [T4] Run RED for boundary assertions

Run: `bash tests/test-superpowers-boundary.sh`

Expected: FAIL with `boundary contract 缺少 brainstorming design completeness fork`.

3. [T4] Add the declared forks and overlay file

Add these entries under `declared_forks`:

```yaml
  - id: brainstorming_design_completeness_gate
    scope: community/superpowers/skills/brainstorming
    reason: add design completeness checklist (D1-D8) and expanded template per small-chain.yaml key_fields
    owner_source: contracts/superpowers-boundary.yaml
  - id: writing_plans_task_traceability
    scope: community/superpowers/skills/writing-plans/SKILL.md
    reason: add Traces/Depends/Complexity to tasks.md template, Context to plan.md, and 3 HARD-GATE checks
    owner_source: contracts/superpowers-boundary.yaml
```

Add this entry under `overlay_files`:

```yaml
  - community/superpowers/skills/brainstorming/references/design-completeness-checklist.md
```

4. [T4] Run GREEN for boundary assertions

Run: `bash tests/test-superpowers-boundary.sh`

Expected: PASS and print `[PASS] superpowers boundary`.

5. [T4] Commit the overlay declarations

Run:

```bash
git add tests/test-superpowers-boundary.sh contracts/superpowers-boundary.yaml
git commit -m "docs: declare small-chain quality floor overlays"
```

### Task 5: Full Verification And Small-Chain Gate [T5]

Context: The closeout gate must prove the success criteria from `design.md`, the task-plan mapping, and the overall repository test suite from a fresh command run. The ignored `executor.log` files required by `tests/test-product-eval-contract.sh` must exist in the worktree before full test execution.

Files:
- Modify: `docs/small-chain-artifact-quality/2026-04-18-quality-floor/tasks.md`
- Verify: `docs/small-chain-artifact-quality/2026-04-18-quality-floor/plan.md`
- Test: `tools/community/check_task_plan_consistency.py`
- Test: `tests/test-small-chain-boundary.sh`
- Test: `tests/test-superpowers-boundary.sh`
- Test: `tests/run-all.sh`

1. [T5] Run the task-plan consistency checker

Run:

```bash
python3 tools/community/check_task_plan_consistency.py docs/small-chain-artifact-quality/2026-04-18-quality-floor/tasks.md docs/small-chain-artifact-quality/2026-04-18-quality-floor/plan.md
```

Expected: PASS with `tasks-plan consistency (5 tasks`.

2. [T5] Run focused small-chain tests

Run:

```bash
bash tests/test-small-chain-boundary.sh
bash tests/test-superpowers-boundary.sh
```

Expected: both commands print `[PASS]`.

3. [T5] Ensure ignored benchmark logs are present for full-suite parity

Run:

```bash
find tools/eval/results/product-split-benchmark-20260415/iteration-1 -name executor.log | wc -l
```

Expected: `36`. If the count is `0`, copy the real local logs from `/Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-1/` into the worktree with `rsync -a --include='*/' --include='executor.log' --exclude='*' ...`, then repeat the count.

4. [T5] Run full verification

Run:

```bash
bash tests/run-all.sh
git diff --check
```

Expected: `tests/run-all.sh` prints `All tests passed`; `git diff --check` exits 0 with no output.

5. [T5] Mark tasks complete after evidence exists

Change each task line in `tasks.md` from unchecked to checked only after its RED/GREEN and verification evidence is present.

6. [T5] Commit verification state

Run:

```bash
git add docs/small-chain-artifact-quality/2026-04-18-quality-floor/tasks.md docs/small-chain-artifact-quality/2026-04-18-quality-floor/plan.md
git commit -m "docs: add small-chain quality floor execution plan"
```
