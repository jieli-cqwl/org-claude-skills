# Worklog — skill runtime manual-only visibility

Created: 2026-04-18
Updated: 2026-04-18

## Current State
- Goal: 在安装层维护低频 skill 的 manual-only 策略，减少运行时上下文噪音，并同步 Claude / Codex 暴露行为。
- Decision: 不改 vendored `community/*/skills/*/SKILL.md`，统一通过 `install.sh` 在安装时注入 `disable-model-invocation: true`，并同步处理 Codex `agents/openai.yaml` 暴露。
- Constraint: `webapp-testing` 保持自动可见；现有来源选择与安装优先级不变。

## Active Workset
- state_ref: ./2026-04-18-install-layer-manual-only/design.md
- next_ref: ./2026-04-18-install-layer-manual-only/tasks.md
- plan_ref: ./2026-04-18-install-layer-manual-only/plan.md

## Notes
- 该变更按 small-chain 链路推进：design → tasks/plan → implementation → verification。
- 当前实现边界限定在安装层与测试，不触碰 vendored skill 正文。
