# Design Skill Capability and Runtime Quality Governance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Implement the `design` skill governance redesign so the skill, canonical contract, gates, fixtures, and downstream consumers all enforce the new HOW-layer quality contract.

**Architecture:** Keep the standard-chain phase order and canonical JSON authority unchanged. Strengthen P0 skill/reference wording first, then expand P1 schema/template/semantic gates, then add P2 downstream consumption markers in `test-design` and `tech-lead`.

**Tech Stack:** Bash contract tests, JSON Schema, `jq`, Python semantic validation, Markdown skill/reference files, existing standard-chain validation scripts.

---

## Current Workspace Notes

The active worktree is `/Users/lijieli/.superset/worktrees/org-claude-skills/paint-guavaberry`, branch `paint-guavaberry`. `docs/design-skill-governance/2026-04-23-capability-and-structure-redesign/design.md` is already modified and is treated as the user-provided design truth. The historical `docs/archive/product-skills-governance/2026-04-23-capability-and-structure-redesign/` package is an archive reference only and is not a runtime source.

## File Boundary Map

- Create: `docs/design-skill-governance/2026-04-23-capability-and-structure-redesign/plan.md`
- Create: `docs/design-skill-governance/2026-04-23-capability-and-structure-redesign/tasks.md`
- Create: `docs/design-skill-governance/2026-04-23-capability-and-structure-redesign/verify-change-report.md`
- Modify: `docs/design-skill-governance/2026-04-23-capability-and-structure-redesign/design.md` (user-provided design truth)
- Create: `tests/test-design-skill-governance-redesign.sh`
- Modify: `shared/reference/Skill质量标准.md`
- Modify: `shared/skills/design/SKILL.md`
- Modify: `shared/skills/design/references/adr-spec.md`
- Modify: `shared/skills/design/references/architecture-patterns.md`
- Modify: `shared/skills/design/references/constitution-template.md`
- Modify: `shared/skills/design/references/decision-templates.md`
- Modify: `shared/skills/design/references/design-product-reviewer-prompt.md`
- Modify: `shared/skills/design/references/design-reviewer-prompt.md`
- Modify: `shared/skills/design/references/design-test-reviewer-prompt.md`
- Modify: `shared/skills/design/references/interface-spec.md`
- Modify: `shared/skills/design/references/legacy-modernization.md`
- Modify: `shared/skills/design/references/quality-attributes.md`
- Modify: `shared/skills/design/references/risk-assessment.md`
- Modify: `shared/skills/design/references/runtime-fact-capture.md`
- Modify: `shared/skills/design/references/service-decomposition.md`
- Modify: `shared/skills/design/references/templates/design-template.md`
- Modify: `shared/skills/design/references/templates/mod-template.md`
- Modify: `shared/skills/design/references/templates/template-notes.md`
- Modify: `contracts/canonical/templates/planning/design.template.json`
- Modify: `contracts/canonical/templates/planning/test-cases.template.json`
- Modify: `contracts/canonical/schemas/planning/design.schema.json`
- Modify: `contracts/canonical/schemas/planning/test-cases.schema.json`
- Modify: `contracts/standard-chain.yaml`
- Modify: `shared/skills/design/scripts/completion_check.sh`
- Modify: `tools/community/validate_canonical_rules.py`
- Modify: `tests/test-standard-chain-foundation-registry.sh`
- Modify: `tests/test-standard-chain-closure-contract.sh`
- Modify: `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/design.json`
- Modify: `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/test-cases.json`
- Modify: `tests/fixtures/standard-chain-foundation/delivery-owner-positive-dispatch/sample-feature/phase-1/design.json`
- Modify: `tests/fixtures/standard-chain-foundation/delivery-owner-positive-dispatch/sample-feature/phase-1/unit-1/test-cases.json`
- Modify: `tests/fixtures/standard-chain-foundation/runtime/baseline/design.json`
- Modify: `shared/skills/test-design/SKILL.md`
- Modify: `shared/skills/test-design/scripts/completion_check.sh`
- Modify: `shared/skills/tech-lead/SKILL.md`
- Modify: `tests/test-skill-context-budget.sh`

### Task 1: Add Governance Regression Coverage [T1]

Context: This task creates the RED contract test that locks the redesign surfaces before changing production artifacts.

Files:
- Create: `tests/test-design-skill-governance-redesign.sh`

1. [T1] Write the failing test.

Create `tests/test-design-skill-governance-redesign.sh` with assertions for these exact surfaces:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_file() {
  [ -f "$1" ] || fail "missing file: ${1#"$ROOT"/}"
}

assert_present() {
  local pattern="$1" file="$2" label="${3:-$2}"
  grep -Eq "$pattern" "$file" || fail "missing pattern in ${label#"$ROOT"/}: $pattern"
}

assert_absent() {
  local pattern="$1" file="$2" label="${3:-$2}"
  if grep -Eq "$pattern" "$file"; then
    fail "unexpected pattern in ${label#"$ROOT"/}: $pattern"
  fi
}
```

2. [T1] Add path variables and P0 assertions.

Append variables for `STANDARD`, `DESIGN_SKILL`, `TEST_DESIGN_SKILL`, `TECH_LEAD_SKILL`, `DESIGN_TEMPLATE`, `DESIGN_SCHEMA`, `DESIGN_CHECK`, `CANONICAL_RULES`, `STANDARD_CHAIN`, `REGISTRY_TEST`, and `CLOSURE_TEST`. Assert:

```bash
assert_present '500 行 / 5000 tokens|5000 tokens / 500 行' "$STANDARD"
assert_present '250 行.*审视信号|审视信号.*250 行' "$STANDARD"
assert_absent 'Pipeline skill \| <=250 行' "$STANDARD"
assert_present 'Q1.*技术现状与约束' "$DESIGN_SKILL"
assert_present 'Q9.*风险与回应' "$DESIGN_SKILL"
assert_present 'LLM 判断.*Artifact.*工程化验证|工程化验证.*Artifact.*LLM 判断' "$DESIGN_SKILL"
assert_present 'consumer-first|消费者优先' "$DESIGN_SKILL"
assert_present 'Trigger.*Read.*Expect.*Consume.*Evidence.*Sync' "$DESIGN_SKILL"
```

3. [T1] Add P1/P2 assertions.

Assert all new canonical fields appear in the template, schema, design gate, canonical rules, standard-chain design key fields, registry/closure tests, and downstream skill files:

```bash
for field in modules data_architecture cross_cutting_concerns verification_mapping unit_coverage impact_scope planning_constraints product_handoff risks risk_response; do
  assert_present "\"$field\"" "$DESIGN_TEMPLATE"
  assert_present "\"$field\"" "$DESIGN_SCHEMA"
  assert_present "$field" "$DESIGN_CHECK"
  assert_present "$field" "$CANONICAL_RULES"
  assert_present "$field" "$STANDARD_CHAIN"
  assert_present "$field" "$REGISTRY_TEST"
  assert_present "$field" "$CLOSURE_TEST"
done

assert_present 'data_architecture.*DESIGN-GAP|DESIGN-GAP.*data_architecture' "$TEST_DESIGN_SKILL"
assert_present 'cross_cutting_concerns.*auth.*error.*log.*config|auth.*error.*log.*config.*cross_cutting_concerns' "$TEST_DESIGN_SKILL"
assert_present 'verification_mapping' "$TEST_DESIGN_SKILL"
assert_present 'unit_coverage.*Task|Task.*unit_coverage' "$TECH_LEAD_SKILL"
assert_present 'impact_scope.*scope_item_id|scope_item_id.*impact_scope' "$TECH_LEAD_SKILL"
assert_present 'planning_constraints.*探索|探索.*planning_constraints' "$TECH_LEAD_SKILL"
```

4. [T1] Run the RED command.

Run: `bash tests/test-design-skill-governance-redesign.sh`

Expected: non-zero exit because the redesign is not implemented yet.

### Task 2: Update P0 Skill Governance Surfaces [T2]

Context: P0 freezes the human-facing and LLM-facing governance contract: line-count policy, Q1-Q9, role separation, reference contracts, and noise control.

Files:
- Modify: `shared/reference/Skill质量标准.md`
- Modify: `shared/skills/design/SKILL.md`
- Modify: `shared/skills/design/references/*.md`
- Modify: `shared/skills/design/references/templates/*.md`

1. [T2] Update `Skill质量标准.md`.

Replace the existing D2 line budget table with a policy that says:

```markdown
行数口径：

- 官方软上限：`SKILL.md` 接近或超过 500 行 / 5000 tokens 时，必须拆分或记录豁免理由。
- 本地审视信号：超过 250 行触发职责数量、读取频率、低频内容比例、reference 合同质量和工程化替代空间审视；不自动判失败。
- 不为了压缩行数删除 HARD-GATE、前置条件、完成边界或失败路径。
```

2. [T2] Update `design/SKILL.md` with Q1-Q9.

Add a `## 核心问题框架` section with a table for Q1-Q9. Each row must name the LLM responsibility, canonical fields, and gate responsibility from `design.md`.

3. [T2] Add reference routing contract to `design/SKILL.md`.

Add a `## Reference 合同` section requiring Trigger/Read/Expect/Consume/Evidence/Sync for methodology references and exempting fixed template/schema/script paths from method-style contract formatting.

4. [T2] Add consumer-first and noise-control guidance.

Add explicit guidance that new canonical fields must identify consumer, behavior change, missing-field gate, and verification evidence before entering `design.json`.

5. [T2] Add contract headers to methodology references.

For each methodology reference, add a concise contract block:

```markdown
## Resource Contract

| 字段 | 内容 |
| --- | --- |
| Trigger | [specific trigger] |
| Read | `shared/skills/design/references/<file>.md` |
| Expect | [specific decision material] |
| Consume | [specific design step or canonical field] |
| Evidence | [specific gate, review item, or artifact field] |
| Sync | [specific skill/template/schema/test to sync] |
```

Fixed template files may state `固定投影视图模板；由 template-notes 与 canonical template/schema 同步约束。`

6. [T2] Run focused checks.

Run: `bash tests/test-design-skill-governance-redesign.sh`

Expected: still fails on P1/P2 assertions, while the line-count and Q1-Q9 assertions pass.

### Task 3: Expand Design Canonical Contract [T3]

Context: P1 expands machine-consumable design facts without making Markdown a runtime source.

Files:
- Modify: `contracts/canonical/templates/planning/design.template.json`
- Modify: `contracts/canonical/schemas/planning/design.schema.json`
- Modify: `contracts/standard-chain.yaml`
- Modify: design golden fixtures under `tests/fixtures/standard-chain-foundation/**/design.json`
- Modify: `tests/test-standard-chain-foundation-registry.sh`
- Modify: `tests/test-standard-chain-closure-contract.sh`

1. [T3] Replace design template field set.

Make `authoritative_fields` include:

```json
"$.modules",
"$.data_architecture",
"$.cross_cutting_concerns",
"$.verification_mapping",
"$.unit_coverage",
"$.impact_scope",
"$.planning_constraints",
"$.product_handoff",
"$.risks",
"$.risk_response"
```

2. [T3] Add structured sample values to the design template.

Use object arrays for `quality_attributes`, `modules`, `verification_mapping`, `unit_coverage`, `impact_scope`, `risks`, and `risk_response`. Use an object for `data_architecture` and `product_handoff`.

3. [T3] Update the schema.

Add required properties and minimum required subfields:

```json
"data_architecture": {
  "type": "object",
  "required": ["summary", "storage_decisions", "data_flows", "consistency_strategy"]
}
```

Apply the same pattern for `modules`, `cross_cutting_concerns`, `verification_mapping`, `unit_coverage`, `impact_scope`, `planning_constraints`, `product_handoff`, `risks`, and `risk_response`.

4. [T3] Update standard-chain design key fields.

In `contracts/standard-chain.yaml`, include every new design field under the `design` output key fields.

5. [T3] Update golden design fixtures.

Update every standard-chain design fixture listed in the boundary map so schema validation and authoritative field checks pass with the expanded contract.

6. [T3] Update registry and closure tests.

Extend `REQUIRED_SCHEMA_FIELDS["design"]` in `tests/test-standard-chain-foundation-registry.sh` and the design schema required-field loop in `tests/test-standard-chain-closure-contract.sh`.

7. [T3] Run schema-focused checks.

Run: `bash tests/test-standard-chain-foundation-registry.sh`

Expected: exits 0 after the template, schema, standard-chain, and fixtures are aligned.

### Task 4: Enforce Design Semantic Gates [T4]

Context: Schema proves shape. The semantic validators prove status, traceability, handoff, and field completeness.

Files:
- Modify: `shared/skills/design/scripts/completion_check.sh`
- Modify: `tools/community/validate_canonical_rules.py`
- Modify: `tests/test-design-skill-governance-redesign.sh`

1. [T4] Add a `jq` semantic expression to `completion_check.sh`.

Require non-empty `modules`, `data_architecture`, `cross_cutting_concerns`, `verification_mapping`, `unit_coverage`, `impact_scope`, `planning_constraints`, `product_handoff`, `risks`, and `risk_response`. Require cross-cutting concerns for `auth`, `error`, `log`, and `config`.

2. [T4] Add design rule validation in Python.

In `tools/community/validate_canonical_rules.py`, add `assert_design_contract(artifact)` and call it for `artifact_type == "design"`. The function must check:

```python
required_concerns = {"auth", "error", "log", "config"}
```

It must reject missing `verification_mapping[*].technical_checks`, missing `unit_coverage[*].design_refs`, missing `impact_scope[*].scope_item_id`, product handoff status other than `confirmed`, and risk responses without `verification_refs` or `escalation_path`.

Review-driven extension: the validator must also resolve cross-artifact references against sibling `brief.json`, `phase-prd.json`, `units/UNIT-*.json`, and `design.json` consumers so fake-looking refs cannot pass by string presence alone. This includes `verification_mapping[].manager_vp_ref`, `unit_coverage[].unit_id`, `unit_coverage[].ac_refs`, `unit_coverage[].design_refs`, `impact_scope[].affected_modules`, `product_handoff.accepted_refs`, and `qa_handoff_contract[].design_source_refs`.

3. [T4] Add negative fixture probes to the regression test.

Use a temp copy of the golden phase. Remove `data_architecture`, remove `verification_mapping`, and remove one required cross-cutting concern in three separate probes. Each probe must run:

```bash
python3 "$ROOT/tools/community/validate_standard_chain_phase.py" --phase-dir "$tmp_phase"
```

Expected: each probe exits non-zero and mentions the missing field or semantic rule.

Also mutate bad cross-artifact refs and missing/bad `qa_handoff_contract[].design_source_refs`; each mutation must fail both phase validation and the relevant local completion gate.

4. [T4] Run semantic checks.

Run: `bash tests/test-design-skill-governance-redesign.sh`

Expected: P0/P1/P2 string assertions pass and negative probes fail for the right reasons.

### Task 5: Update Standard-Chain Fixtures and Contract Tests [T5]

Context: This task proves the expanded design contract remains compatible with existing standard-chain validation.

Files:
- Modify: `tests/test-standard-chain-foundation-registry.sh`
- Modify: `tests/test-standard-chain-closure-contract.sh`
- Modify: `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/design.json`
- Modify: `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/test-cases.json`
- Modify: `tests/fixtures/standard-chain-foundation/delivery-owner-positive-dispatch/sample-feature/phase-1/design.json`
- Modify: `tests/fixtures/standard-chain-foundation/delivery-owner-positive-dispatch/sample-feature/phase-1/unit-1/test-cases.json`
- Modify: `tests/fixtures/standard-chain-foundation/runtime/baseline/design.json`

1. [T5] Validate fixture consistency.

Run: `bash tests/test-standard-chain-foundation-registry.sh`

Expected: exits 0 and validates template, schema, key fields, and golden authoritative fields.

2. [T5] Validate closure contract.

Run: `bash tests/test-standard-chain-closure-contract.sh`

Expected: exits 0 and asserts the new design required fields.

3. [T5] Validate the golden phase.

Run: `python3 tools/community/validate_standard_chain_phase.py --phase-dir tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1`

Expected: exits 0.

### Task 6: Add Downstream Rollout Consumption [T6]

Context: P2 makes the downstream rollout explicit so the new fields are not silently forgotten.

Files:
- Modify: `shared/skills/test-design/SKILL.md`
- Modify: `shared/skills/test-design/scripts/completion_check.sh`
- Modify: `shared/skills/tech-lead/SKILL.md`
- Modify: `contracts/canonical/templates/planning/test-cases.template.json`
- Modify: `contracts/canonical/schemas/planning/test-cases.schema.json`

1. [T6] Update `test-design/SKILL.md`.

In `固定主流程` step 2 and `专项展开规则`, explicitly consume:

```markdown
- `data_architecture`: triggers data consistency, migration, rollback, or DESIGN-GAP obligations.
- `cross_cutting_concerns`: triggers auth/error/log/config test obligations or DESIGN-GAP output.
- `verification_mapping`: validates Manager VP to test-case coverage.
```

2. [T6] Update `tech-lead/SKILL.md`.

In input reading, design review, traceability, and task split steps, explicitly consume:

```markdown
- `unit_coverage`: maps Task rows to UNIT/AC design coverage.
- `impact_scope`: maps `scope_item_id` to Task impact and verification scope.
- `planning_constraints`: creates prerequisite checks, non-parallel items, exploration boundaries, and unlock rules.
```

3. [T6] Run downstream contract check.

Run: `bash tests/test-design-skill-governance-redesign.sh`

Expected: exits 0.

### Task 7: Verify and Close the Small-Chain Package [T7]

Context: The closeout task performs fresh proving commands and checks the diff against the planned surface.

Files:
- Modify: `docs/design-skill-governance/2026-04-23-capability-and-structure-redesign/tasks.md`
- Create: `docs/design-skill-governance/2026-04-23-capability-and-structure-redesign/verify-change-report.md`

1. [T7] Run task-plan consistency.

Run: `python3 tools/community/check_task_plan_consistency.py docs/design-skill-governance/2026-04-23-capability-and-structure-redesign/tasks.md docs/design-skill-governance/2026-04-23-capability-and-structure-redesign/plan.md`

Expected: `[PASS] tasks-plan consistency (7 tasks, ... plan steps)`.

2. [T7] Run targeted proving commands.

Run:

```bash
bash tests/test-design-skill-governance-redesign.sh
bash tests/test-standard-chain-foundation-registry.sh
bash tests/test-standard-chain-closure-contract.sh
python3 tools/community/validate_standard_chain_phase.py --phase-dir tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1
bash tests/test-skill-context-budget.sh
python3 -m py_compile tools/community/validate_canonical_rules.py
bash -n shared/skills/design/scripts/completion_check.sh shared/skills/test-design/scripts/completion_check.sh tests/test-design-skill-governance-redesign.sh tests/test-skill-context-budget.sh
```

Expected: every command exits 0.

3. [T7] Check diff hygiene.

Run: `git diff --check`

Expected: exits 0.

4. [T7] Mark completed tasks.

After each task has its review evidence and the targeted proving commands pass, update `tasks.md` checkboxes from `[ ]` to `[x]` for T1-T7.
