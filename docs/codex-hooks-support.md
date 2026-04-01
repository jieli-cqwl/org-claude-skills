# Codex Hooks 支持结论

## 当前结论

截至 2026 年 4 月 1 日，基于当前仓库 `tools/dev/probe-codex-hooks.sh` 的本地复验结果是：

- `~/.codex/hooks.json` 文件可以存在
- `codex exec` 在显式开启 `codex_hooks`、走 stdin 协议并强制 `Bash` 流时，已经捕获到 `SessionStart / PreToolUse / PostToolUse / Stop`
- 当前探针的稳定基线是：
  - `bash-flow`：强制 Codex 使用 Bash 执行 `printf ok >/tmp/codex-hooks-probe-bash.txt`
- 当前 probe 使用临时 `CODEX_HOME`，避免污染用户全局 `~/.codex/hooks.json`
- 当前不再把 `write-flow` 当成强制基线：
  - 该非交互路径下，模型会先检查工具可用性，未稳定暴露独立 `Write` 工具，容易把“工具面差异”误判成“hooks 失效”
- `TaskCompleted` 仍未被当前 probe 收为可依赖事实

这是基于本地实测的工程结论，不是官方明确声明“不支持”。

## 仓库策略

- 当前标准仓库不接管 `~/.codex/hooks.json`
- Claude 全局 hooks 继续作为 Claude 专属能力维护，不应被 shared 层表述成跨平台默认保障
- Codex 侧只接管已验证可工作的共享能力：skills / reference / rules / agents / completion checks / hooks 公共库

## 复验方法

升级 Codex CLI 或 Codex App 后，执行：

```bash
cd ~/org-claude-skills
bash tools/dev/probe-codex-hooks.sh
```

如果后续版本能稳定捕获事件，再决定是否把 Codex 全局 hooks 纳入安装器标准能力。
