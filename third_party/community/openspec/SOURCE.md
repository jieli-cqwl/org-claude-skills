# OpenSpec Snapshot

- Repository: `https://github.com/Fission-AI/OpenSpec`
- Branch at capture: `main`
- Commit: `afdca0d5dab1aa109cfd8848b2512333ccad60c3`
- Captured from upstream on: `2026-03-26`

Included upstream artifacts:
- `docs/opsx.md`
- `docs/workflows.md`
- `docs/commands.md`
- `docs/getting-started.md`
- `src/core/templates/workflows/propose.ts`
- `src/core/templates/workflows/apply-change.ts`
- `src/core/templates/workflows/verify-change.ts`
- `src/core/templates/workflows/archive-change.ts`
- `src/core/command-generation/adapters/claude.ts`
- `src/core/command-generation/adapters/codex.ts`

Notes:
- `community-adapters/claude/commands/opsx/*.md` 与 `community-adapters/codex/prompts/opsx-*.md` 由 `tools/dev/generate_opsx_adapters.py` 从上述 upstream 模板正文生成。
- `opsx:*` 命令正文保持 upstream 逻辑，不改工作流语义。
