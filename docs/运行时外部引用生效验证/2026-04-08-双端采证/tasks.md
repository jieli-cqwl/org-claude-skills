# Tasks — 双端外部引用运行时采证
Created: 2026-04-08
Related plan: ./plan.md

## Acceptance Checklist
- [ ] T1 Claude 入口 reference 生效探针
  - AC: `tools/dev/probe-claude-capabilities.sh` 新增独立 probe，使用临时 HOME 复制 `~/.claude`，通过外部 `reference/runtime-reference-probe.md` 驱动随机 token 校验
- [ ] T2 Codex 入口 reference 生效探针
  - AC: `tools/dev/probe-codex-capabilities.sh` 新增独立 probe，使用临时 HOME 复制 `~/.codex`，通过外部 `reference/runtime-reference-probe.md` 驱动随机 token 校验
- [ ] T3 探针契约回归
  - AC: 新测试纳入 `tests/run-all.sh`，能校验两端 probe 采用隔离运行时、外部 reference 承载 token、精确输出匹配三项约束

## Definition of Done
All tasks checked = ready for verify-change.
