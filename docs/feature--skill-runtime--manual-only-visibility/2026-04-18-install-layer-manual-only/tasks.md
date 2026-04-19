# Tasks — install-layer-manual-only
Created: 2026-04-18
Related plan: ./plan.md

## Acceptance Checklist
- [x] T1 Add failing assertions for install-layer manual-only visibility
  - AC: `bash tests/test-single-source-layout.sh` exits 0 before the implementation because the source tree remains unchanged and vendored `SKILL.md` files stay untouched, and `bash tests/test-runtime-integrity.sh` fails before the implementation because target skills still retain auto-visible runtime artifacts.
  - Traces: install-layer centralized manual-only maintenance; Claude/Codex consistent visibility; webapp-testing remains auto-visible
  - Depends: -
  - Complexity: moderate
- [x] T2 Implement install.sh manual-only maintenance for low-frequency skills
  - AC: `install.sh` declares and consumes one install-layer low-frequency manual-only list that covers the agreed target skills, injects `disable-model-invocation: true` into Claude runtime output, removes matching Codex `agents/openai.yaml`, and does not include `webapp-testing`.
  - Traces: install-layer centralized manual-only maintenance; Claude/Codex consistent visibility; webapp-testing remains auto-visible
  - Depends: T1
  - Complexity: moderate
- [x] T3 Prove runtime behavior and no formatting regressions
  - AC: `bash tests/test-single-source-layout.sh`, `bash tests/test-runtime-integrity.sh`, `python3 tools/community/check_task_plan_consistency.py docs/feature--skill-runtime--manual-only-visibility/2026-04-18-install-layer-manual-only/tasks.md docs/feature--skill-runtime--manual-only-visibility/2026-04-18-install-layer-manual-only/plan.md`, and `git diff --check` all exit 0 after T2.
  - Traces: install-layer centralized manual-only maintenance; Claude/Codex consistent visibility; webapp-testing remains auto-visible
  - Depends: T2
  - Complexity: simple

## Definition of Done
All tasks checked = ready for verify-change.
