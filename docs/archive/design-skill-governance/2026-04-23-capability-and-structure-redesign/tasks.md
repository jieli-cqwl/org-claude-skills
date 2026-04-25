# Tasks - design skill capability and runtime quality governance
Created: 2026-04-24
Related plan: ./plan.md

## Acceptance Checklist

- [x] T1 Add governance regression coverage
  - AC: `bash tests/test-design-skill-governance-redesign.sh` fails before implementation because the current artifacts still lack the updated line-count policy, Q1-Q9 design skill contract, reference contract routing, design canonical fields, design gate checks, and downstream consumption markers.
  - AC: The test asserts P0, P1, and P2 surfaces without using archived docs as runtime truth.
  - Traces: 行数标准修正; Q1-Q9 可落地; Reference 按需加载; 工程化闭环; 下游不被遗忘; 保持兼容
  - Depends: -
  - Complexity: moderate

- [x] T2 Update P0 skill governance surfaces
  - AC: `shared/reference/Skill质量标准.md` states 500 lines / 5000 tokens as the official soft ceiling and treats 250 lines as a responsibility and noise review signal, not an automatic failure.
  - AC: `shared/skills/design/SKILL.md` contains Q1-Q9, LLM/artifact/gate responsibility separation, consumer-first field admission, reference contract routing, and noise-control guidance.
  - AC: `shared/skills/design/references/*` methodology references expose Trigger/Read/Expect/Consume/Evidence/Sync contracts or are explicitly fixed-template/runtime references.
  - Traces: 需求价值成立; LLM 职责边界清晰; Reference 按需加载; 行数标准修正; 无噪音扩张
  - Depends: T1
  - Complexity: complex

- [x] T3 Expand design canonical contract
  - AC: `contracts/canonical/templates/planning/design.template.json` and `contracts/canonical/schemas/planning/design.schema.json` require and demonstrate `modules`, `data_architecture`, `cross_cutting_concerns`, `verification_mapping`, `unit_coverage`, `impact_scope`, `planning_constraints`, `product_handoff`, `risks`, and `risk_response`.
  - AC: `quality_attributes` is structured enough to carry priority ranking, key scenarios, and tradeoff points while remaining schema-valid for existing standard-chain validation.
  - AC: `contracts/standard-chain.yaml` design key fields and golden design fixtures include every new authoritative field.
  - Traces: Q1-Q9 可落地; 工程化闭环; 无噪音扩张; 保持兼容
  - Depends: T2
  - Complexity: complex

- [x] T4 Enforce design semantic gates
  - AC: `shared/skills/design/scripts/completion_check.sh` rejects missing or empty Q1-Q9 canonical fields, incomplete cross-cutting concern coverage, incomplete verification mapping, missing product handoff closure, and incomplete risk response.
  - AC: `tools/community/validate_canonical_rules.py` rejects the same design contract drift during `validate_standard_chain_phase.py` so phase validation cannot pass with schema-only shape compliance.
  - AC: Negative fixture probes in `tests/test-design-skill-governance-redesign.sh` prove missing `data_architecture`, missing `verification_mapping`, and missing required cross-cutting concerns fail.
  - Traces: 工程化闭环; Q1-Q9 可落地; 保持兼容
  - Depends: T3
  - Complexity: complex

- [x] T5 Update standard-chain fixtures and contract tests
  - AC: `bash tests/test-standard-chain-foundation-registry.sh` exits 0 with the new design schema/template/fixture contract.
  - AC: `bash tests/test-standard-chain-closure-contract.sh` exits 0 and asserts the new design required fields.
  - AC: `python3 tools/community/validate_standard_chain_phase.py --phase-dir tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1` exits 0 on the upgraded golden fixture.
  - Traces: 工程化闭环; 保持兼容; 下游不被遗忘
  - Depends: T4
  - Complexity: moderate

- [x] T6 Add downstream rollout consumption
  - AC: `shared/skills/test-design/SKILL.md` explicitly consumes `data_architecture`, `cross_cutting_concerns`, and `verification_mapping` to create test obligations or DESIGN-GAP output.
  - AC: `shared/skills/tech-lead/SKILL.md` explicitly consumes `unit_coverage`, `impact_scope`, and `planning_constraints` to build Task traceability and exploration boundaries.
  - AC: `bash tests/test-design-skill-governance-redesign.sh` proves both downstream skill files contain the rollout consumption contract.
  - Traces: 下游不被遗忘; 保持兼容; 工程化闭环
  - Depends: T5
  - Complexity: moderate

- [x] T7 Verify and close the small-chain package
  - AC: `python3 tools/community/check_task_plan_consistency.py docs/design-skill-governance/2026-04-23-capability-and-structure-redesign/tasks.md docs/design-skill-governance/2026-04-23-capability-and-structure-redesign/plan.md` exits 0.
  - AC: Targeted proving commands exit 0: `bash tests/test-design-skill-governance-redesign.sh`, `bash tests/test-standard-chain-foundation-registry.sh`, `bash tests/test-standard-chain-closure-contract.sh`, and `python3 tools/community/validate_standard_chain_phase.py --phase-dir tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1`.
  - AC: `git diff --check` exits 0 and the diff contains only the planned design governance surfaces plus the user-provided `design.md`.
  - Traces: small-chain verification-before-completion; verify-change; 完成前验证
  - Depends: T6
  - Complexity: moderate

## Definition of Done

All tasks checked = ready for verify-change.
