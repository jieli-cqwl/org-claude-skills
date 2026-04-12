# Tasks — vendor selected Vercel skills
Created: 2026-04-12
Related plan: ./plan.md

## Acceptance Checklist
- [x] T1 建立 Vercel community source 目录与来源锁定
  - AC: `community/vercel/skills/find-skills/SKILL.md`、`community/vercel/skills/agent-browser/SKILL.md`、`community/vercel/codex/skills/*/agents/openai.yaml` 存在；`community/SOURCES.yaml` 包含 `vercel_skills` 与 `vercel_agent_browser`。
- [x] T2 接入安装链路
  - AC: `install.sh` 能把两个 Vercel skill 合成到 Claude/Codex runtime；Codex runtime 中两个 skill 都有 `agents/openai.yaml`。
- [x] T3 补齐同步与回归验证
  - AC: 存在可复用的 `tools/community/sync_vercel_skills_from_upstream.py`；结构/安装/运行完整性相关测试覆盖新 source 并通过。

## Definition of Done
All tasks checked = ready for verify-change.
