# Tasks — research 目的驱动输出优化
Created: 2026-04-10
Related plan: ./plan.md

## Acceptance Checklist
- [x] T1 research 呈现模式 contract
  - AC: `shared/skills/research/SKILL.md` 明确要求在范围澄清阶段确认调研目的、目标读者、读后动作，并输出 `presentation_profile`
- [x] T2 research 模板重构
  - AC: `shared/skills/research/references/templates/` 提供 `decision / understanding / audit` 三类首屏模板和共享审计附录，且 mode 模板顺序体现“答案优先、证据后置”
- [x] T3 research 机械校验
  - AC: 新增 `shared/skills/research/scripts/completion_check.sh`，可校验 profile 必填段落、共享审计附录和关键章节顺序
- [x] T4 research 回归测试
  - AC: 仓库测试覆盖新 contract、模板存在性，以及 `decision / understanding / audit` 三类 completion check 通过/失败场景，并纳入 `tests/run-all.sh`
- [x] T5 Codex hooks blocker fixes
  - AC: `tools/community/render_hook_registry.py` 为 Codex 显式渲染空的 `PostToolUse / PostCompact / TaskCompleted`，且安装/卸载流程能恢复安装前的非标准 `hooks.json` baseline，相关 systematic / adapter 测试通过

## Definition of Done
All tasks checked = ready for verify-change.
