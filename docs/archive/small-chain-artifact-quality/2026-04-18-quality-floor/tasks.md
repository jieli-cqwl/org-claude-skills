# Tasks — small-chain-artifact-quality quality floor
Created: 2026-04-18
Related plan: ./plan.md

## Acceptance Checklist
- [x] T1 Add small-chain artifact key_fields contract coverage
  - AC: `bash tests/test-small-chain-boundary.sh` fails before the contract change because `contracts/small-chain.yaml` lacks design.md, tasks.md, and plan.md key_fields, then passes after the contract change.
  - Traces: design.md 检查表与契约对齐; tasks.md 有追踪/依赖/复杂度字段; plan.md 有上下文字段
  - Depends: -
  - Complexity: simple
- [x] T2 Add brainstorming design completeness floor
  - AC: `bash tests/test-small-chain-boundary.sh` fails before the brainstorming artifact changes because the D1-D8 checklist and Content completeness self-review are absent, then passes after the checklist, template, and SKILL.md changes.
  - Traces: design.md 内容完整性有结构化保障; design.md 检查表与契约对齐
  - Depends: T1
  - Complexity: moderate
- [x] T3 Add writing-plans traceability, dependency, complexity, and context floor
  - AC: `bash tests/test-small-chain-boundary.sh` fails before the writing-plans changes because Traces/Depends/Complexity, Context, and the three new HARD-GATE checks are absent, then passes after the SKILL.md changes.
  - Traces: tasks.md 有追踪/依赖/复杂度字段; plan.md 有上下文字段; HARD-GATE 覆盖新字段
  - Depends: T1
  - Complexity: moderate
- [x] T4 Declare local superpowers overlays for the new small-chain forks
  - AC: `bash tests/test-superpowers-boundary.sh` fails before the boundary change because the two declared_forks and the new checklist overlay file are absent, then passes after the boundary contract change.
  - Traces: overlay 声明完整
  - Depends: T2, T3
  - Complexity: simple
- [x] T5 Verify the complete small-chain artifact quality change
  - AC: `python3 tools/community/check_task_plan_consistency.py docs/small-chain-artifact-quality/2026-04-18-quality-floor/tasks.md docs/small-chain-artifact-quality/2026-04-18-quality-floor/plan.md`, `bash tests/test-small-chain-boundary.sh`, `bash tests/test-superpowers-boundary.sh`, `bash tests/run-all.sh`, and `git diff --check` all exit 0 after T1-T4.
  - Traces: design.md 内容完整性有结构化保障; design.md 检查表与契约对齐; tasks.md 有追踪/依赖/复杂度字段; plan.md 有上下文字段; HARD-GATE 覆盖新字段; overlay 声明完整
  - Depends: T1, T2, T3, T4
  - Complexity: complex

## Definition of Done
All tasks checked = ready for verify-change.
