# 运行时真实性验证

目标：验证“安装完成”是否真的等于“运行可用”，避免把静态文件存在误判为能力已生效。

推荐入口：

```bash
cd ~/org-claude-skills
bash tools/dev/probe-runtime-capabilities.sh ~/org-claude-skills
```

补充前置：

- `openspec` CLI 必须已安装并可执行；community-first 默认链依赖 `opsx:*`
- 默认自动入口以 `brainstorming` 为准；`using-superpowers`、标准链与本地重叠 workflow skill 为 manual-only

## 验证原则

- 先测真实调用，再看文件结构。
- 先测底层机制，再推导上层 skill 是否可信。
- 不把平台未验证能力写成默认保障。

## 当前建议验证项

### Claude

1. 最小调用：
   `claude --bare --no-session-persistence -p --output-format json 'Reply with exactly <唯一token>.'`
2. 常规模式输出链路：
   `claude --no-session-persistence --verbose -p --output-format stream-json 'Reply with exactly <唯一token>.'`
3. 全局 hooks：
   使用临时 `--settings` 注入探针 hook，确认 `PreToolUse/PostToolUse/Stop` 有触发证据。
4. skill-local hooks：
   创建临时探针 skill，确认 `Stop hook` 真正落盘。
5. 本地 agents：
   在 git 仓库中做一次最小 subagent 调用。
   如果走自定义代理，必须额外确认代理支持 `claude-*` 模型名。

### Codex

1. 最小调用：
   `codex exec --json 'Reply with exactly OK.'`
2. 技能解析：
   创建临时探针 skill，确认 `/skill-name` 可被真实调用。
3. skill-local hooks：
   当前不能默认相信 `SKILL.md` frontmatter 中的 `hooks:`。
   必须做真实探针；截至 2026-03-26，本机 `codex-cli 0.116.0` 未观察到触发证据。
4. 全局 hooks：
   截至 2026-03-26，本机 `codex exec` 默认未捕获 `hooks.json` 事件。
   开启 `--enable codex_hooks` 后，仅 `SessionStart/Stop` 有证据，`PreToolUse/PostToolUse/TaskCompleted` 仍未观察到。
5. agents：
   在 trusted git 仓库中做一次最小委派，确认 `spawn_agent/wait` 真正完成。

## 当前仓库策略

- Claude：
  保留并依赖全局 hooks + skill-local Stop hooks。
  默认小需求入口是 `brainstorming`。
  Claude 全局 hooks 属于 adapter-specific 保障，不应上升为 shared 层的跨平台默认承诺。
- Codex：
  默认自动发现面以 `brainstorming` 为准。
  `using-superpowers`、标准链与本地重叠 workflow skill 保持 manual-only。
  不把 hooks 当成强保障。
  对带 `scripts/completion_check.sh` 的 skill，安装器会移除误导性的 frontmatter `hooks:`，并在运行时文档中改为“结束前显式执行脚本”。

## 已知环境约束

- Codex 需要在 trusted 目录运行；直接在 `~/.claude` 这类运行目录执行可能被拒绝。
- Claude 若走本地代理，代理健康和模型别名兼容性属于运行前置条件，不是仓库自身可完全兜底的能力。
- Claude 运行验收必须使用唯一 token，不能用固定 `OK` 这类响应；否则本地 mock/probe 服务可能产生假阳性。
- Claude 若指向本地 `mock/probe` 服务，必须先恢复真实代理，再做任何产品级验收。
- Claude 若接 LiteLLM / OpenAI 兼容代理，参考 `docs/claude-proxy-compatibility.md`。
