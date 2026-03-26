# 团队运行验收 SOP

目标：确保“仓库可安装”真正等于“Claude / Codex 运行可用”，并把已知平台边界显式化。

适用场景：
- 新版本发布前验收
- 新同事首次接入
- 升级后怀疑某项能力失效

## 1. 前置条件

在可写 HOME 环境中执行，并确保：

- `~/org-claude-skills` 为当前待验收版本
- Claude 已登录，`claude auth status` 正常
- 若 Claude 走本地代理，代理地址可访问
- 若 Claude 走本地代理，不能指向本地 `mock/probe` 服务
- Codex 在 trusted git 仓库中执行，不要在 `~/.claude` / `~/.codex` 下直接运行

## 2. 仓库与安装验收

执行：

```bash
cd ~/org-claude-skills
git status --short
bash tests/run-all.sh
bash install.sh --target all --force --merge-hooks --check full
```

要求：

- `git status --short` 仅包含本次待发布变更
- `bash tests/run-all.sh` 输出 `All tests passed`
- `bash install.sh ... --check full` 通过

## 3. 运行时真实探针

执行：

```bash
cd ~/org-claude-skills
bash tools/dev/probe-runtime-capabilities.sh ~/org-claude-skills
```

判定规则：

- 必须没有 `[FAIL]`
- 允许存在以下已知 `[WARN]`，但必须被团队理解并接受：
  - `Claude 常规模式 result 字段为空`
  - `Codex skill-local Stop hook 未触发`
  - `Codex hooks.json 默认未捕获任何事件`
- 如出现 `Claude 当前指向本地 mock/probe 服务`，视为阻断，不属于可接受 WARN。

这些 `WARN` 不是安装故障，而是当前平台运行边界。

## 4. 人工抽样验证

### Claude

执行：

```bash
claude --bare --no-session-persistence -p --output-format json 'Reply with exactly HELLO_<唯一token>.'
```

要求：

- 返回完整唯一 token

### Codex

执行：

```bash
cd ~/org-claude-skills
codex exec --json "List all currently available skills by exact name only, one per line, no extra text."
```

要求：

- 至少看到核心 skills：
  - `product`
  - `design`
  - `test-design`
  - `tech-lead`
  - `project-manager`

## 5. 当前团队运行口径

- Claude：
  - 可依赖全局 hooks
  - 可依赖 skill-local Stop hook
  - 可依赖本地 agent 委派
  - 若走 LiteLLM / OpenAI 代理，必须显式支持 `claude-sonnet-* / claude-opus-* / claude-haiku-*` 模型别名
- Codex：
  - 可依赖 skills
  - 可依赖 agent 委派
  - 不把 hooks 当成强保障
  - 对带 `scripts/completion_check.sh` 的 skill，必须按文档显式执行脚本

## 6. 异常分级

- `P0`：
  - Claude 最小调用失败
  - Codex 最小调用失败
  - 核心 skills 不可见
  - 安装后出现路径漂移或大面积受管文件缺失
- `P1`：
  - Claude hooks 失效
  - Claude skill-local Stop hook 失效
  - Codex agent 委派失效
- `P2`：
  - 文档口径与实际探针结果不一致
  - 已知 `WARN` 未被显式记录

## 7. 失败后的处置

1. 先执行回滚：

```bash
cd ~/org-claude-skills
bash install.sh --uninstall --target all
```

2. 再查看：

- `docs/rollback-sop.md`
- `docs/runtime-validation.md`
- `docs/codex-hooks-support.md`

3. 补充故障证据：

- 失败命令
- 终端输出
- 当前 `VERSION`
- 当前 `git rev-parse --short HEAD`
