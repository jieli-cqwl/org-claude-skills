# Test Design Governance Implementation Plan

> **For agentic workers:** REQUIRED NEXT STEP: run `implementation-router`. Implement only after `execution-route.json` chooses `serial` or `parallel`.

**Goal:** Upgrade `test-design` from shallow AC coverage wording into a machine-enforced pre-development test analysis and test design contract.

**Architecture:** The cutover is contract first, behavior second. Schema and templates define the target `test-cases.json` shape; canonical semantic rules and the completion gate reject invalid artifacts; fixtures prove the active runtime shape; Skill text, projections, reviewer prompts, downstream consumers, and evals then describe behavior already backed by mechanical checks.

**Tech Stack:** JSON Schema draft 2020-12, Python canonical validators, Bash completion gates, jq-based hook assertions, Markdown Skill files, standard-chain fixtures, local skill eval metadata.

---

### Task 1: Contract inventory and schema/template target [T1]

Context: The current schema allows shallow `test_cases[]` with only `case_id` and `title`. This task freezes the strengthened JSON shape before any Skill wording claims the new behavior.

Files:
- Modify: `shared/skills/test-design/contracts/test-cases.schema.json`
- Modify: `shared/skills/test-design/templates/test-cases.template.json`
- Create: `tests/test-test-design-governance-contract.sh`

1. [T1] Write the failing static contract test.

```bash
bash tests/test-test-design-governance-contract.sh
```

Expected: FAIL because the schema/template do not yet require the redesigned `test_analysis`, product refs, executable case fields, typed gap rows, and cross-UNIT obligations.

2. [T1] Add schema definitions for source refs and closed enums.

```json
{
  "$defs": {
    "sourceRef": {
      "type": "string",
      "pattern": "^(brief\\.json|phase-prd\\.json|UNIT-[0-9]+\\.json|design\\.json)#[A-Za-z_][A-Za-z0-9_]*(\\[[0-9]+\\])?(\\.[A-Za-z_][A-Za-z0-9_]*(\\[[0-9]+\\])?)*$"
    },
    "gapType": {
      "type": "string",
      "enum": [
        "PRODUCT_GAP",
        "DESIGN_GAP",
        "SCOPE_DRIFT",
        "TRACE_CONFLICT",
        "TESTABILITY_GAP",
        "EQ_GAP"
      ]
    }
  }
}
```

3. [T1] Add `test_analysis` to the schema and template.

```json
{
  "test_analysis": {
    "objectives": [
      "prove every closed UNIT acceptance criterion with positive, negative, and boundary obligations"
    ],
    "in_scope": [
      "UNIT behavior, ACs, exclusions, risks, and triggered quality areas"
    ],
    "out_of_scope": [
      "architecture decisions, task planning, QA release recommendation, and delivery signoff"
    ],
    "risk_model": [
      {
        "risk_ref": "phase-prd.json#risks[0]",
        "risk_type": "product",
        "test_depth": "expanded"
      }
    ],
    "strategy_by_quality_area": [
      {
        "quality_area": "functional",
        "strategy": "positive negative boundary exclusion coverage"
      }
    ],
    "test_flow": [
      {
        "checkpoint_id": "FLOW-1",
        "source_refs": [
          "UNIT-1.json#acceptance_criteria[0].ac_id"
        ],
        "expected_checkpoint": "observable result can be asserted"
      }
    ],
    "environment_assumptions": [
      "phase runtime dependencies are available or represented as TESTABILITY_GAP"
    ],
    "data_assumptions": [
      "seed and boundary data are declared per executable case"
    ]
  }
}
```

4. [T1] Strengthen `test_cases[]` to require executable intent.

```json
{
  "required": [
    "case_id",
    "title",
    "product_refs",
    "design_refs",
    "case_type",
    "priority",
    "preconditions",
    "test_data",
    "steps",
    "expected_result",
    "assertion_target",
    "execution_mode",
    "automation_level",
    "evidence_expectation",
    "owner_stage"
  ]
}
```

5. [T1] Strengthen `design_gap_report.gaps[]` and keep the compatibility field name.

```json
{
  "required": [
    "gap_id",
    "gap_type",
    "blocking_refs",
    "owner",
    "next_action",
    "blocking"
  ]
}
```

6. [T1] Add `traceability_matrix[]` and `cross_unit_obligations[]` to schema/template using the exact fields from `design.md`.

7. [T1] Update `authoritative_fields` in the template to include `$.test_analysis`, `$.traceability_matrix`, and `$.cross_unit_obligations`.

8. [T1] Run the contract test.

Run: `bash tests/test-test-design-governance-contract.sh`
Expected: `[PASS] test-design governance contract`

### Task 2: Semantic validator for refs, gaps, and cross-UNIT obligations [T2]

Context: Schema can close shape, but semantic validation must resolve refs against the correct product and design artifacts and classify invalid gaps before planning sees the artifact.

Files:
- Modify: `tools/community/canonical_test_case_rules.py`
- Create: `tests/test-test-design-canonical-rules.sh`
- Create: `tests/fixtures/test-design-governance/valid-phase/brief.json`
- Create: `tests/fixtures/test-design-governance/valid-phase/phase-1/phase-prd.json`
- Create: `tests/fixtures/test-design-governance/valid-phase/phase-1/units/UNIT-1.json`
- Create: `tests/fixtures/test-design-governance/valid-phase/phase-1/design.json`
- Create: `tests/fixtures/test-design-governance/valid-phase/phase-1/unit-1/test-cases.json`

1. [T2] Write the failing semantic rules test with a valid phase fixture and copy-on-write mutations.

```bash
bash tests/test-test-design-canonical-rules.sh
```

Expected: FAIL because the validator only resolves `design.json#...` in `qa_handoff_contract[].design_source_refs`.

2. [T2] Replace `TEST_DESIGN_REF_RE` with a source-ref parser that accepts product and design artifacts.

```python
SOURCE_REF_RE = re.compile(
    r"^(brief\\.json|phase-prd\\.json|UNIT-[0-9]+\\.json|design\\.json)#(.+)$"
)
```

3. [T2] Build an artifact lookup for `brief`, `phase-prd`, `unit-definition`, and `design`.

```python
def _artifact_by_ref_name(artifacts: list[dict], ref_name: str) -> dict:
    artifact_type_by_name = {
        "brief.json": "brief",
        "phase-prd.json": "phase-prd",
        "design.json": "design",
    }
    if ref_name.startswith("UNIT-"):
        return _first_artifact(artifacts, "unit-definition")
    return _first_artifact(artifacts, artifact_type_by_name[ref_name])
```

4. [T2] Validate every source ref in `test_analysis`, `traceability_matrix`, `test_cases[].product_refs`, `test_cases[].design_refs`, `design_gap_report.gaps[].blocking_refs`, and `cross_unit_obligations[]`.

5. [T2] Add semantic assertions for executable cases.

```python
def _assert_executable_case(row: dict, path: str) -> None:
    _require_string_list(row.get("product_refs"), f"{path}.product_refs")
    _require_string_list(row.get("design_refs"), f"{path}.design_refs")
    _require_non_empty_string(row.get("expected_result"), f"{path}.expected_result")
    _require_non_empty_string(row.get("assertion_target"), f"{path}.assertion_target")
```

6. [T2] Add gap rules that require one owner, one recovery action, and fail completion when `blocking=true`.

7. [T2] Add cross-UNIT composition rules for `journey_id`, complete `participant_unit_refs`, ordered `sequence_index`, and `composition_status` values `COMPOSABLE` or `BLOCKED_GAP`.

8. [T2] Run the semantic rules test.

Run: `bash tests/test-test-design-canonical-rules.sh`
Expected: `[PASS] test-design canonical rules`

### Task 3: Completion gate fail-closed hardening [T3]

Context: The hook is the runtime guard immediately before handoff. It must reject the same failure modes as the canonical semantic rules without relying on a readable projection.

Files:
- Modify: `shared/skills/test-design/scripts/completion_check.sh`
- Modify: `shared/skills/test-design/scripts/manifest.json`
- Create: `tests/test-test-design-completion-gate.sh`

1. [T3] Write the failing completion gate test with mutations for missing analysis, missing refs, shallow cases, malformed QA rows, unknown gaps, unresolved refs, and cross-UNIT errors.

```bash
bash tests/test-test-design-completion-gate.sh
```

Expected: FAIL because the gate currently checks AC triple coverage and QA handoff basics but not the redesigned artifact contract.

2. [T3] Replace the inline design-only ref validator with a Python block that uses the same source-ref grammar as T2.

3. [T3] Extend the jq gate to require `test_analysis`, executable `test_cases[]`, `traceability_matrix`, typed `design_gap_report.gaps[]`, and valid `cross_unit_obligations[]`.

```bash
jq -e '
  (.test_analysis | type == "object")
  and (.traceability_matrix | type == "array" and length > 0)
  and all(.test_cases[]; (.product_refs | type == "array" and length > 0)
    and (.expected_result // "" | type == "string" and length > 0)
    and (.assertion_target // "" | type == "string" and length > 0))
' "$target"
```

4. [T3] Enforce `qa_stage` enum values `QA_A`, `QA_B`, `QA_C`, `QA_D`, and `NFR` while preserving the existing required QA_A-D coverage.

5. [T3] Emit clear owner/recovery diagnostics for blocking gaps.

```bash
add_failure "test-cases.json has blocking test-design gaps; owner and next_action must be resolved before tech-lead handoff: $target"
```

6. [T3] Update the manifest verification command to include the new gate test.

7. [T3] Run the completion gate test.

Run: `bash tests/test-test-design-completion-gate.sh`
Expected: `[PASS] test-design completion gate`

### Task 4: Active fixtures and phase validation cutover [T4]

Context: Contract changes become real only when active fixtures use the new shape and legacy shallow artifacts fail the same validation path.

Files:
- Modify: `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/unit-1/test-cases.json`
- Modify: `tests/fixtures/standard-chain-foundation/delivery-owner-positive-dispatch/sample-feature/phase-1/unit-1/test-cases.json`
- Modify: `tests/test-skill-output-and-gate-contract.sh`
- Modify: `tests/test-standard-chain-readiness-gate.sh`
- Modify: `tests/test-standard-chain-validator-stack.sh`

1. [T4] Update active `test-cases.json` fixtures with `test_analysis`, `traceability_matrix`, executable case rows, typed gap rows, and QA handoff evidence expectations.

2. [T4] Keep `schema_version` at `1.0.0` only if all active fixtures and consumers update in this batch. Use `1.1.0` when a compatibility validator is required by the impact inventory.

3. [T4] Add negative fixture mutations for shallow cases, unresolved product refs, unknown gap types, and blocking gaps.

4. [T4] Run phase validation on the golden pilot fixture.

Run: `python3 tools/community/validate_standard_chain_phase.py --phase-dir tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1 --catalog shared/runtime/standard-chain-catalog.json`
Expected: exit 0.

5. [T4] Run targeted contract tests that consume active fixtures.

Run: `bash tests/test-skill-output-and-gate-contract.sh`
Expected: PASS.

Run: `bash tests/test-standard-chain-validator-stack.sh`
Expected: PASS.

### Task 5: Skill SOP, projection, reviewer, and downstream consumer alignment [T5]

Context: After the machine contract exists, the human-facing Skill body and projections can describe the upgraded role without becoming the source of truth.

Files:
- Modify: `shared/skills/test-design/SKILL.md`
- Modify: `shared/skills/test-design/projections/test-cases-template.md`
- Modify: `shared/skills/test-design/references/testdesign-reviewer-prompt.md`
- Modify: `shared/skills/test-design/references/testdesign-product-reviewer-prompt.md`
- Modify: `shared/skills/test-design/references/testdesign-arch-reviewer-prompt.md`
- Modify: `shared/skills/tech-lead/SKILL.md`
- Modify: `shared/skills/developer/SKILL.md`
- Modify: `shared/skills/verify/SKILL.md`
- Modify: `shared/skills/delivery-owner/SKILL.md`
- Modify: `shared/skills/consistency-audit/SKILL.md`
- Modify: `tests/test-design-skill-governance-redesign.sh`
- Modify: `tests/test-standard-chain-cutover.sh`

1. [T5] Rewrite the `test-design` role section around test analysis, test design, testability gaps, and QA obligation freezing.

```markdown
`test-design` owns pre-development test analysis and test design. It translates product truth and design承接 into `test-cases.json` obligations before `tech-lead` planning starts.
```

2. [T5] Replace the coverage-first main flow with the seven states from `design.md`: Input Check, Product Understanding, Design承接 Analysis, Test Analysis, Test Case Design, Gap Judgment, and Handoff And Review.

3. [T5] Update projection vocabulary to render JSON enums with human-friendly labels while preserving schema enum spelling as authoritative.

4. [T5] Update reviewer prompts so product reviewers validate product intent refs, architecture reviewers validate design承接 and testability, and test reviewers validate executable assertions.

5. [T5] Update downstream Skill text so `tech-lead`, `developer`, `verify`, `delivery-owner`, and `consistency-audit` consume strengthened `test-cases.json` fields without changing QA execution or delivery signoff authority.

6. [T5] Run governance and cutover tests.

Run: `bash tests/test-design-skill-governance-redesign.sh`
Expected: PASS.

Run: `bash tests/test-standard-chain-cutover.sh`
Expected: PASS.

### Task 6: Behavior eval and effectiveness evidence upgrade [T6]

Context: The Skill should prove behavior across normal and adversarial prompts, not just static contract shape.

Files:
- Modify: `shared/skills/test-design/evals/evals.json`
- Modify: `shared/skills/test-design/evals/lifecycle-review.json`
- Modify: `tests/test-standard-chain-skill-evals.sh`
- Modify: `tests/test-skill-effectiveness-eval-framework.sh`

1. [T6] Add eval cases for product ambiguity, design gap, scope drift, trace conflict, testability gap, browser-required QA handoff, and cross-UNIT composition.

```json
{
  "id": "product-design-conflict-produces-trace-conflict",
  "prompt": "产品 AC 要求只读角色不可导出数据，但 design.json 暴露了只读导出接口。请执行 test-design 分析，本 eval 不要求实际写文件。",
  "expected_output": "输出 TRACE_CONFLICT，指出 product 和 design 的冲突 source refs、owner、next_action，并阻断进入 tech-lead。",
  "files": [
    "tests/fixtures/test-design-governance/valid-phase"
  ],
  "expectations": [
    "识别 TRACE_CONFLICT",
    "引用 product_ref 和 design_ref",
    "给出 owner 和 next_action",
    "阻断 tech-lead handoff"
  ],
  "expected_anchors": [
    "PA-TRACE",
    "PA-BLOCK"
  ],
  "run_modes": [
    "with_skill",
    "without_skill"
  ]
}
```

2. [T6] Expand `preference_anchors` so each new eval maps to role boundary, product-first traceability, typed gaps, executable assertions, QA handoff, or cross-UNIT composition.

3. [T6] Update lifecycle review to keep `decision=optimize` until empirical with-skill and without-skill results exist.

4. [T6] Run eval metadata tests.

Run: `bash tests/test-standard-chain-skill-evals.sh`
Expected: `[PASS] standard-chain skill evals contract`

Run: `bash tests/test-skill-effectiveness-eval-framework.sh`
Expected: PASS.

### Task 7: Contract-grade design producer/consumer ownership guard [T7]

Context: This guards the process issue found during this redesign: C1-C8 details belong to the `design.md` producer contract, while `writing-plans` carries approved decisions into tasks.

Files:
- Modify: `community/superpowers/skills/brainstorming/SKILL.md`
- Modify: `community/superpowers/skills/brainstorming/references/design-completeness-checklist.md`
- Modify: `community/superpowers/skills/writing-plans/SKILL.md`
- Modify: `tests/test-contract-grade-design-preflight.sh`
- Modify: `docs/feature--standard-chain--flow-optimization/2026-04-28-test-design-governance/design.md`

1. [T7] Keep `brainstorming` as the producer-side owner for `design.md` C1-C8 checks.

```markdown
Treat this as `brainstorming`'s producer-side responsibility for `design.md`: freeze C1-C8 decisions here before user review and writing-plans.
```

2. [T7] Keep `writing-plans` as the consumer that carries approved preflight decisions into `tasks.md` and `plan.md`.

```markdown
Carry forward the approved source-of-truth rules, ref grammar, owner/waiver rules, cutover order, and proving categories from `design.md` into `tasks.md` and `plan.md`.
```

3. [T7] Keep `Skill质量标准.md` focused on artifact-contract quality in the governance design.

4. [T7] Run the contract-grade preflight test.

Run: `bash tests/test-contract-grade-design-preflight.sh`
Expected: `[PASS] contract-grade design preflight`

### Task 8: Final route, context, and targeted verification [T8]

Context: Finish only after the plan-stage artifacts route cleanly and every targeted proof command supports the design success criteria.

Files:
- Modify: `docs/feature--standard-chain--flow-optimization/2026-04-28-test-design-governance/tasks.md`
- Create: `docs/feature--standard-chain--flow-optimization/2026-04-28-test-design-governance/execution-route.json`
- Modify: `docs/feature--standard-chain--flow-optimization/worklog.md`

1. [T8] Run task-plan consistency.

Run: `python3 tools/community/check_task_plan_consistency.py docs/feature--standard-chain--flow-optimization/2026-04-28-test-design-governance/tasks.md docs/feature--standard-chain--flow-optimization/2026-04-28-test-design-governance/plan.md`
Expected: `[PASS] tasks-plan consistency (8 tasks, 48 plan steps)`

2. [T8] Route the implementation plan.

Run: `python3 tools/community/implementation_router.py --repo-root . --feature-path docs/feature--standard-chain--flow-optimization --workset 2026-04-28-test-design-governance --force-refresh`
Expected: JSON with `"decision": "serial"` and `"reason": "requested_serial_execution"`.

3. [T8] Validate context handoff.

Run: `python3 tools/community/validate_context_contract.py --repo-root .`
Expected: exit 0.

4. [T8] Run all targeted proving commands after implementation.

```bash
bash tests/test-test-design-governance-contract.sh
bash tests/test-test-design-canonical-rules.sh
bash tests/test-test-design-completion-gate.sh
python3 tools/community/validate_standard_chain_phase.py --phase-dir tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1 --catalog shared/runtime/standard-chain-catalog.json
bash tests/test-skill-output-and-gate-contract.sh
bash tests/test-standard-chain-validator-stack.sh
bash tests/test-design-skill-governance-redesign.sh
bash tests/test-standard-chain-cutover.sh
bash tests/test-standard-chain-skill-evals.sh
bash tests/test-skill-effectiveness-eval-framework.sh
bash tests/test-contract-grade-design-preflight.sh
```

5. [T8] Mark each task complete in `tasks.md` only after its AC command passes.

6. [T8] Append the next worklog entry with `stage: verify` only after all T1-T7 commands pass.
