# Runtime Reference Activation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** 为 Claude Code 与 Codex 增加入口外部 `reference/*.md` 的真实运行时采证能力，并补充可回归的探针契约测试。

**Architecture:** 在现有 capability probe 脚本内新增平台专属 `Entry Reference Activation` 探针。探针通过复制已安装运行时到临时 HOME、注入 reference 文件与入口触发段、再执行真实 CLI 调用来证明外部 reference 被消费；仓库测试只验证探针实现契约，避免把不稳定 live 调用纳入默认 CI。

**Tech Stack:** Bash, Python 3, Claude Code CLI, Codex CLI

---

### Task 1: Claude 入口 reference 生效探针 [T1]

Files:
- Modify: `tools/dev/probe-claude-capabilities.sh`

1. [T1] 写失败测试，要求 Claude probe 脚本包含独立的 `Entry Reference Activation` 探针名，并显式使用临时 HOME 复制运行时。
2. [T1] 运行测试，确认在脚本尚未实现前失败。
3. [T1] 在 `tools/dev/probe-claude-capabilities.sh` 中新增辅助逻辑：复制 `~/.claude` 到临时 HOME、注入 `reference/runtime-reference-probe.md`、修改临时 `CLAUDE.md`。
4. [T1] 实现 Claude live probe，使用随机 token 与现有 stream-json 解析方式做精确匹配。
5. [T1] 运行测试确认通过，并做一次脚本语法检查。

### Task 2: Codex 入口 reference 生效探针 [T2]

Files:
- Modify: `tools/dev/probe-codex-capabilities.sh`

1. [T2] 写失败测试，要求 Codex probe 脚本包含独立的 `Entry Reference Activation` 探针名，并显式使用临时 HOME 复制运行时。
2. [T2] 运行测试，确认在脚本尚未实现前失败。
3. [T2] 在 `tools/dev/probe-codex-capabilities.sh` 中新增辅助逻辑：复制 `~/.codex` 到临时 HOME、注入 `reference/runtime-reference-probe.md`、修改临时 `AGENTS.md`。
4. [T2] 实现 Codex live probe，使用随机 token 与现有 json 输出解析方式做精确匹配。
5. [T2] 运行测试确认通过，并做一次脚本语法检查。

### Task 3: 探针契约回归 [T3]

Files:
- Create: `tests/test-runtime-reference-activation.sh`
- Modify: `tests/run-all.sh`

1. [T3] 先写失败测试，断言两端 probe 脚本都满足三项契约：临时 HOME 隔离、外部 reference 承载 token、精确输出匹配。
2. [T3] 运行测试确认失败，证明门禁有效。
3. [T3] 实现测试脚本并接入 `tests/run-all.sh`。
4. [T3] 运行新增测试、`bash -n` 语法检查和相关回归，确认全部通过。
5. [T3] 使用真实已安装运行时执行一次双端 probe，记录 PASS/WARN/FAIL 证据。
