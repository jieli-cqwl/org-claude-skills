# Codex Hooks 支持结论

## 当前结论

截至 2026 年 3 月 26 日，在本机 `codex-cli 0.116.0` 上做的本地探针结果是：

- `~/.codex/hooks.json` 文件可以存在
- 但在 `codex exec` 路径下，`SessionStart / PreToolUse / PostToolUse / TaskCompleted / Stop` 没有捕获到触发证据
- 探针分别覆盖了两条主路径：
  - `bash-flow`：强制 Codex 使用 Bash 执行 `printf ok >/tmp/codex-hooks-probe-bash.txt`
  - `write-flow`：强制 Codex 使用 Write 创建 `hook-write.txt`
- 两条路径都执行成功，但事件日志仍为空

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
