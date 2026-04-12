# Design — vendor selected Vercel skills

## Why
当前仓库已经用 `community/superpowers` 和 `community/anthropic` 承载第三方 skill 真源，但还没有一套可复用的 Vercel 社区源接入方式。为了把 `find-skills` 和 `agent-browser` 纳入本地公共仓库统一维护，并继续支持本地安装到 `~/.claude` / `~/.codex`，需要沿用现有的 vendoring + source lock + Codex adapter 模式接入这两个 skill。

## Scope
- In scope: vendor `find-skills` 与 `agent-browser` 到仓库；为两个 skill 生成 Codex `openai.yaml` adapter；将新来源写入 `community/SOURCES.yaml`；让 `install.sh` 在 Claude/Codex 安装时合成这两个 skill；补充同步脚本与回归测试。
- Out of scope: 修改 skill 正文方法论；引入安装时联网拉取；扩展更多 Vercel skill；改造现有 `superpowers` / `anthropic` 接入模型。

## Approach
新增 `community/vercel/skills` 与 `community/vercel/codex/skills` 作为新的 community source。`find-skills` 与 `agent-browser` 分别从各自 upstream 仓库按锁定 ref vendor 到本地目录，正文保持 upstream 原文；Codex adapter 沿用 Anthropic 社区 skill 的 `agents/openai.yaml` 生成方式。安装时新增一组 `community_vercel_*` 选择函数，复用现有 `copy_selected_*` 与 `overlay_codex_*` 流程，把这两个 skill 合成进 Claude/Codex runtime。为了后续维护，新增 `tools/community/sync_vercel_skills_from_upstream.py`，负责按 `community/SOURCES.yaml` 的两个 Vercel source 锁文件同步 skill 目录并生成 adapter。

## Alternatives Considered
| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| 直接 vendor 到 `community/vercel` 并纳入 install | 与现有仓库模式一致；离线可安装；可复现；便于锁定版本 | 需要补一套 source lock / sync / test | 采用 |
| 只记录 GitHub 地址，安装时拉取上游 | 初始改动小 | 安装依赖网络；版本漂移；不符合当前社区源管理方式 | 不采用 |
| 用 git submodule / subtree 管理上游 | 能保留上游历史 | 对当前 `community/*` 单源布局侵入大；安装与测试链更复杂 | 不采用 |

## Key Decisions
- D1: 新增 `community/vercel`，不把 skill 混入 `community/anthropic` 或 `shared/skills` —— Reason: 语义上属于新的 third-party community source，和现有 source lock 结构一致。
- D2: `find-skills` 与 `agent-browser` 都作为 Codex auto skill 暴露 —— Reason: 两者都是通用可调用 skill，不属于 `using-superpowers` 这类 manual-only 流程 skill。
- D3: `community/SOURCES.yaml` 拆成两个 source 节点：`vercel_skills` 与 `vercel_agent_browser` —— Reason: 两个 skill 来自不同 upstream 仓库，ref 与同步策略需要独立锁定。
- D4: 增加独立同步脚本 `sync_vercel_skills_from_upstream.py` —— Reason: 避免手工复制造成漂移，并复用 Anthropic sync 的维护方式。

## Success Criteria
- `community/vercel/skills/find-skills` 与 `community/vercel/skills/agent-browser` 存在，且都包含 upstream `SKILL.md`。
- `community/vercel/codex/skills/{find-skills,agent-browser}/agents/openai.yaml` 存在。
- `community/SOURCES.yaml` 能锁定两个 Vercel upstream，且 `tools/community/source_lock_check.py` 校验通过。
- 运行 `bash install.sh --target all --check quick` 后，Claude/Codex runtime 都能安装这两个 skill。
- 相关结构/安装/运行完整性测试通过。
