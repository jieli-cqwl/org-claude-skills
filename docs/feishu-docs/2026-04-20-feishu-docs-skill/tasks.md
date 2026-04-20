# Tasks - Feishu Docs Skill
Created: 2026-04-20
Related plan: ./plan.md

## Acceptance Checklist

- [x] T1 Add Feishu Docs skill contract tests
  - AC: `bash tests/test-feishu-docs-skill-contract.sh` fails before the skill source exists, then checks source frontmatter, manual-only visibility, required references, required evals, safety language, CLI command coverage, and secret hygiene.
  - Traces: 手动触发; 安全写入; 安全删除; 可验证完成; 读文档总结; 权限失败可解释
  - Depends: -
  - Complexity: moderate
- [x] T2 Create `feishu-docs` skill source and bundled references
  - AC: `shared/skills/feishu-docs/` contains `SKILL.md`, `agents/openai.yaml`, `references/auth-and-config.md`, `references/document-read-playbook.md`, `references/document-write-playbook.md`, `scripts/manifest.json`, and `evals/evals.json`; `bash tests/test-feishu-docs-skill-contract.sh` passes.
  - Traces: 手动触发; 安全写入; 安全删除; 可验证完成; 读文档总结; 权限失败可解释
  - Depends: T1
  - Complexity: moderate
- [x] T3 Add deterministic Feishu CLI wrapper and wrapper tests
  - AC: `python3 tests/test-feishu-docs-wrapper.py` proves the wrapper builds read/create/update/delete commands without executing them by default, requires confirmation for destructive modes, redacts token-like output, and reports CLI-missing failures without fallback tools.
  - Traces: 安全写入; 安全删除; 可验证完成; 权限失败可解释
  - Depends: T2
  - Complexity: moderate
- [x] T4 Integrate `feishu-docs` into Claude and Codex runtime installation
  - AC: `feishu-docs` is listed as local manual-only; `bash tests/test-install-smoke.sh`, `bash tests/test-runtime-integrity.sh`, `bash tests/test-single-source-layout.sh`, and `bash tests/test-codex-skill-adapter.sh` prove Claude receives the skill, Codex receives the skill, and Codex runtime removes `agents/openai.yaml`.
  - Traces: Claude Code 与 Codex 共用; 手动触发
  - Depends: T2
  - Complexity: moderate
- [x] T5 Update docs and run final small-chain verification set
  - AC: `README.md` names `feishu-docs` as a first-party manual Skill; `python3 community/superpowers/skills/verify-change/scripts/check_task_plan_consistency.py docs/feishu-docs/2026-04-20-feishu-docs-skill/tasks.md docs/feishu-docs/2026-04-20-feishu-docs-skill/plan.md`, `bash tests/test-feishu-docs-skill-contract.sh`, `python3 tests/test-feishu-docs-wrapper.py`, `bash tests/test-install-smoke.sh`, `bash tests/test-runtime-integrity.sh`, `bash tests/test-single-source-layout.sh`, and `bash tests/test-codex-skill-adapter.sh` pass.
  - Traces: Claude Code 与 Codex 共用; 手动触发; 安全写入; 安全删除; 可验证完成; 读文档总结; 权限失败可解释
  - Depends: T1,T2,T3,T4
  - Complexity: simple

## Definition of Done

All tasks checked = ready for verify-change.
