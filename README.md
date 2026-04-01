# org-claude-skills

统一维护 Claude Code 与 Codex CLI 的 `skills / rules / reference / hooks / agents`，当前默认轻量链已收口为 `small-chain`。

## 当前状态

- 默认轻量链：`small-chain`
- 运行时基线：`community/superpowers`
- OpenSpec 定位：只保留概念与历史工件语义，不作为运行时依赖
- 进度真源：`tasks.md`
- 执行计划：`plan.md`（只保留 task-id 映射，不持有 checkbox 状态）

## 仓库结构

- `shared/`：first-party 真源，维护共享入口、规则、参考资料、技能与协议
- `community/superpowers/`：本地中文 runtime 与 overlay
- `contracts/`：small-chain 与 superpowers 边界合同
- `docs/small-chain/`：当前默认链路的说明与边界文档
- `openspec/`：历史设计、计划与变更工作台，不参与当前默认运行时编排
- `claude/`：Claude 适配层
- `codex/`：Codex 适配层

## 当前真源

- 入口合同：`shared/assistant.md`
- 来源锁定：`community/SOURCES.yaml`
- small-chain 链路合同：`contracts/small-chain.yaml`
- small-chain 说明：`docs/small-chain/README.md`
- small-chain 边界合同：`docs/small-chain/boundary-contract.md`
- superpowers 运行边界：`contracts/superpowers-boundary.yaml`

## 快速开始

```bash
git clone <repo-url> ~/org-claude-skills
cd ~/org-claude-skills
bash install.sh --target all
```

首次覆盖旧环境时可用：

```bash
bash install.sh --target all --force
```

如需合并 Claude hooks：

```bash
bash install.sh --target claude --merge-hooks --force
```

## 常用命令

```bash
bash install.sh --target all --dry-run
bash install.sh --target all --check full
bash install.sh --uninstall --target all
bash tests/run-all.sh
bash tools/dev/probe-runtime-capabilities.sh ~/org-claude-skills
```

## Small Chain

默认轻量链说明见 `docs/small-chain/README.md`，边界见 `docs/small-chain/boundary-contract.md`。

当前链路为：

1. `brainstorming`
2. `writing-plans`
3. `using-git-worktrees`
4. `subagent-driven-development`
5. `verify-change`
6. `archive`

约束：

- 执行统一收口到 `subagent-driven-development`
- 不再依赖 OpenSpec CLI
- `tasks.md` 是唯一完成状态真源

## 发布与验证

- 结构与合同验证：`bash tools/validate-contracts.sh`
- 全量回归：`bash tests/run-all.sh`
- 运行能力探针：`bash tools/dev/probe-runtime-capabilities.sh ~/org-claude-skills`
