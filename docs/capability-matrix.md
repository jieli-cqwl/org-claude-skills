# Claude / Codex 能力矩阵

本仓库的对齐原则：
- `aligned`：共享源码一份，Claude / Codex 都通过安装获得。
- `adapter-specific`：同一能力目标一致，但入口或配置格式因平台不同而分离。
- `unsupported-in-codex`：Claude 侧存在、Codex 当前仓库不做伪实现，需显式保留差距说明。

| 能力 | Claude | Codex | 状态 | 说明 |
|------|--------|-------|------|------|
| 统一入口指令 | `~/.claude/CLAUDE.md` | `~/.codex/AGENTS.md` | aligned | 统一源：`shared/assistant.md` |
| skills 主体内容 | 支持 | 支持 | aligned | 统一源：`shared/skills/*` |
| skill 附属脚本 / references / templates | 支持 | 支持 | aligned | 统一源：`shared/skills/*` |
| rules | 支持 | 支持 | aligned | 统一源：`shared/rules/*` |
| reference | 支持 | 支持 | aligned | 统一源：`shared/reference/*` |
| agent 角色说明 | 支持 | 支持 | aligned | 统一源：`shared/agents/*` |
| skill-local completion checks | Claude 自动执行 Stop hook | Codex 仅安装脚本，需显式 Bash 调用 | adapter-specific | 2026-03-26 本机实测：Codex skill frontmatter hooks 不触发；安装器会移除 Codex 运行时的误导性 `hooks:` 配置 |
| hooks 公共运行库 | 支持 | 支持 | aligned | 安装到两端 `hooks/lib/common.sh` |
| Claude 全局 hooks 脚本 | 支持 | 不适用 | adapter-specific | 仅 Claude 安装 `block_dangerous` / `code_quality_check` / `auto_format` / `post_compact` / `task_verify` |
| Claude hooks 注册片段 | 支持 | 不适用 | adapter-specific | `claude/settings/hooks-fragment.json` |
| Codex agents `.toml` | 不适用 | 支持 | adapter-specific | `codex/agents/*.toml` |
| Codex skills `agents/openai.yaml` | 不适用 | 支持 | adapter-specific | 源码进入 `shared/skills/*/agents/openai.yaml`，仅安装到 Codex |
| Codex `hooks.json` SessionStart / Stop | 不适用 | feature flag 开启后有触发证据 | adapter-specific | `codex_hooks` 默认关闭；2026-03-26 本机 `codex-cli 0.116.0` + `--enable codex_hooks` 时仅观察到 `SessionStart/Stop` |
| Codex `hooks.json` PreToolUse / PostToolUse / TaskCompleted | 不适用 | 未收口 | unsupported-in-codex | 2026-03-26 本机 `codex exec` 强制 Bash/Write 后仍未捕获这些事件 |
| Claude 本地 agents | 支持 | 不适用 | adapter-specific | 原生 Claude 运行面支持；若走自定义代理，代理必须接受 `claude-*` 系列模型名，否则 subagent 会失败，见 `docs/claude-proxy-compatibility.md` |

## 当前结论

- 团队级共享能力已经收口为单一源码层，不再人工维护两套 skills/rules/reference/agents。
- Codex 运行期已不再依赖 `~/.claude` 路径。
- Claude 的全局 hooks 仍然是平台专属适配层。
- Codex 当前不能把 hooks 当成强保障；运行时必须以显式脚本调用为准。
- 若 Claude 本机通过自定义代理切换到非 Anthropic 模型，需额外验证 subagent 模型兼容性。
