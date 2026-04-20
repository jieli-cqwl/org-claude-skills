# fix-1: baseline contract repair

## Context

- Worktree: `/Users/lijieli/org-claude-skills/.worktrees/skill-harness-small-chain`
- Branch: `codex/skill-harness-small-chain`
- Input command: `bash tests/run-all.sh`
- Scope: 修复进入 small-chain 前暴露的基线测试与契约漂移。

## Findings

### F1: single-source layout shellcheck failure

- RED: `bash tests/run-all.sh` stopped at `[2/36] shellcheck`.
- Evidence: `tests/test-single-source-layout.sh:55` 使用单元素 `for skill in agent-browser; do`，触发 `SC2043`。
- Root cause: 测试脚本为单对象断言保留了循环结构。
- Fix: 改为直接断言 `community/vercel/skills/agent-browser/SKILL.md` 存在。

### F2: Codex runtime noise leak

- RED: `bash tests/run-all.sh` stopped at `[10/35] platform runtime noise test`.
- Evidence: 安装后的 `.codex/skills/project-memory/SKILL.md` 包含示例标题 `# CLAUDE.md`。
- Root cause: `shared/skills/project-memory/SKILL.md` 的模板示例把平台专属文件名写入 Codex runtime 正文。
- Fix: 将示例标题改为 `# {ENTRY_FILE}`，保留正文对 `CLAUDE.md` 与 `AGENTS.md` 的真实产出约束。

### F3: Codex adapter contract drift

- RED: `bash tests/run-all.sh` stopped at `[12/35] codex skill adapter test`.
- Evidence: `tests/test-codex-skill-adapter.sh` 要求 `skill-auditor/agents/openai.yaml` 存在；`install.sh` 的现行契约将 `skill-auditor` 归入 manual-only，Quick Check 要求该 adapter 不存在。
- Root cause: 测试仍按旧的自动触发 adapter 契约检查。
- Fix: 测试改为校验 `skill-auditor/SKILL.md` 安装成功，且 `skill-auditor/agents/openai.yaml` 不进入 Codex runtime。

### F4: research presentation contract omission

- RED: `bash tests/run-all.sh` stopped at `[24/36] research skill contract test`。
- Evidence: `shared/skills/research/SKILL.md` 缺少 `调研目的`、`目标读者`、`读后动作` 三个输出定位槽位。
- Root cause: `presentation_profile` 只列出了模式，没有落到报告消费场景的三个判断槽位。
- Fix: 在 `presentation_profile` 下补齐三个槽位，约束调研输出面向决策、理解或审计的呈现方式。

### F5: context budget audit stale skill name

- RED: `bash tests/run-all.sh` stopped at `[35/36] skill context budget test`。
- Evidence: `tests/test-skill-context-budget.sh` 仍检查 `skill-optimizer`，而当前源目录为 `shared/skills/skill-auditor`。
- Root cause: 核心技能预算清单残留旧名。
- Fix: 将预算清单、行预算分支和缺失目录硬失败对象统一改为 `skill-auditor`。

## Verification

- `bash tests/test-platform-runtime-noise.sh` -> `[PASS] platform runtime noise`
- `bash tests/test-codex-skill-adapter.sh` -> `[PASS] codex skill adapter`
- `bash tests/test-research-skill-contract.sh` -> `[PASS] research skill contract`
- `bash tests/test-skill-context-budget.sh` -> `skill-auditor ... PASS`
- `bash tests/run-all.sh` -> `All tests passed`

## Result

基线测试恢复为可证明通过状态，已具备进入 skill-harness small-chain 计划与实现阶段的前置条件。
