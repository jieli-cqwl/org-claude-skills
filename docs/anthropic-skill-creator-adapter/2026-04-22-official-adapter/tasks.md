# Tasks — Anthropic Skill-Creator Official Adapter
Created: 2026-04-22
Related plan: ./plan.md

## Acceptance Checklist
- [ ] T1 Add adapter config, path helpers, and dry-run workspace planning
  - AC: `bash tools/eval/anthropic_skill_creator/run_developer_improvement.sh --dry-run --output-dir "$TMPDIR/demo"` prints the planned developer iteration path, validates official `skill-creator`, and creates no run outputs.
  - Traces: Success Criteria: local adapter exists, upstream directory remains read-only, dry-run verifies config/path/evals.
  - Depends: -
  - Complexity: moderate
- [ ] T2 Implement existing-skill workspace snapshot and eval metadata generation
  - AC: Adapter creates `iteration-1/skill-snapshot`, per-eval `eval_metadata.json`, and records snapshot source for `old_skill` and `new_skill` without modifying `shared/skills/developer`.
  - Traces: Success Criteria: old/new loop, official-compatible workspace, no automatic skill mutation.
  - Depends: T1
  - Complexity: moderate
- [ ] T3 Implement old/new execution, grading, benchmark, and review HTML generation
  - AC: With fake `codex`, full eval produces old/new `outputs/response.md`, official-compatible `grading.json`, `benchmark.json`, `benchmark.md`, and `review.html`.
  - Traces: Success Criteria: grading JSON, official aggregate benchmark, official static viewer.
  - Depends: T2
  - Complexity: complex
- [ ] T4 Implement trigger eval and description optimization wrapper
  - AC: With fake `claude`, `--trigger-only` produces `trigger/eval-set.json` and a timestamped trigger result directory containing `results.json` and `report.html`, without writing to `SKILL.md`.
  - Traces: Success Criteria: official run_eval, official run_loop, best_description emitted, no automatic writeback.
  - Depends: T1
  - Complexity: moderate
- [ ] T5 Add repository tests and documentation for the Anthropic adapter
  - AC: `bash tests/test-anthropic-skill-creator-adapter.sh`, `bash -n tools/eval/anthropic_skill_creator/run_developer_improvement.sh`, and `python3 -m py_compile tools/eval/anthropic_skill_creator/scripts/*.py` pass.
  - Traces: Success Criteria: repeatable verification, local README, no upstream mutation.
  - Depends: T3, T4
  - Complexity: moderate

## Definition of Done
All tasks checked = ready for verify-change.
