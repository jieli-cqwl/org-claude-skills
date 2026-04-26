# org-claude-skills

统一维护 Claude Code 与 Codex CLI 的 `skills / rules / reference / hooks / agents`，当前默认轻量链已收口为 `small-chain`。

## 当前状态

- 默认轻量链：`small-chain`
- 标准流程：runtime id 为 `standard-chain/v1`，合同入口为 `contracts/standard-chain.yaml`
- 运行时基线：`community/superpowers`
- OpenSpec 定位：只保留概念与历史工件语义，不作为运行时依赖
- 受管通用入口：`worklog.md`（仅对 `contracts/active-doc-scope.yaml` 纳管的 feature 生效）
- scope registry：`contracts/active-doc-scope.yaml`，只记录纳管边界；active candidate 使用 `management_status in [managed, migrated]`
- context ownership：`context_owner` 维护 feature 接手链路，`artifact_owner` 维护具体工件正确性
- handoff 状态：`worklog.md` 最新记录中的 `handoff_status / state_ref / next_ref`
- `small-chain only` 进度真源：`tasks.md`（active workset 内）
- `small-chain only` 执行计划：`plan.md`（active workset 内；只保留 task-id 映射，不持有 checkbox 状态）

## 仓库结构

- `shared/`：first-party 真源，维护共享入口、规则、参考资料、协议与 first-party skills
- `community/superpowers/`：Superpowers upstream 基线与声明式本地 overlay；upstream skill 正文保持锁定 ref 原文
- `community/anthropic/`：官方 `anthropics/skills` 镜像目录与 Codex 适配层
- `community/vercel/`：选定 Vercel community skills 的镜像目录与 Codex 适配层
- `community/alchaincyf/`：选定 Alchaincyf community skills 的镜像目录与 Codex 适配层
- `community/nextlevelbuilder/`：选定 NextLevelBuilder community skills 的镜像目录与 Codex 适配层
- `contracts/`：small-chain、标准流程、active scope 与 superpowers 边界合同
- `docs/`：默认历史材料与非运行时文档；被 `contracts/active-doc-scope.yaml` 纳管的 `docs/{feature}` 目录视为受管活跃子集
- `claude/`：Claude 适配层
- `codex/`：Codex 适配层

## 当前真源

- 入口合同：`shared/assistant.md`
- 来源锁定：`community/SOURCES.yaml`
- 官方 skills 真源目录：`community/anthropic/skills`
- 官方 Codex adapters：`community/anthropic/codex/skills`
- Vercel community skills 真源目录：`community/vercel/skills`
- Vercel community Codex adapters：`community/vercel/codex/skills`
- Alchaincyf community skills 真源目录：`community/alchaincyf/skills`
- Alchaincyf community Codex adapters：`community/alchaincyf/codex/skills`
- NextLevelBuilder community skills 真源目录：`community/nextlevelbuilder/skills`
- NextLevelBuilder community Codex adapters：`community/nextlevelbuilder/codex/skills`
- small-chain 链路合同：`contracts/small-chain.yaml`
- 标准流程合同：`contracts/standard-chain.yaml`
- 标准流程 runtime catalog：`shared/runtime/standard-chain-catalog.json`
- active scope registry：`contracts/active-doc-scope.yaml`
- context artifact ownership：`contracts/context-artifact-ownership.yaml`
- superpowers 运行边界：`contracts/superpowers-boundary.yaml`
- 默认入口 skill：`community/superpowers/skills/using-superpowers/SKILL.md`

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

Claude 安装现在默认会把托管 hooks 合并到 `~/.claude/settings.json`，并在 quick check 中校验关键 hooks 已生效。`--merge-hooks` 仅保留给旧脚本兼容场景。

Codex 安装会默认完成两件事：

- 托管启用 `~/.codex/config.toml` 中的 `features.codex_hooks = true`
- 托管配置 `~/.codex/config.toml` 中的 `[agents]` 并注册 first-party sub agents；agent 模型分层写在 `codex/agents/*.toml`
- 将仓库管理的 hooks 合并到 `~/.codex/hooks.json`，保留 Claude 标准事件上的用户 hooks，并清理不在 Claude 标准事件面内的旧事件

## 常用命令

```bash
bash install.sh --target all --dry-run
bash install.sh --target all --check full
bash install.sh --uninstall --target all
bash tests/run-all.sh
bash tests/run-all.sh --quick
bash tests/run-all.sh --profile
bash tests/run-all.sh --quick --profile
bash tests/run-all.sh --list
bash tools/dev/probe-runtime-capabilities.sh ~/org-claude-skills
```

## Small Chain

默认轻量链的正式 contract 见 `contracts/small-chain.yaml`，边界与 closeout 规则见 `contracts/superpowers-boundary.yaml`。
以下布局与链路只对 scope registry `contracts/active-doc-scope.yaml` 中 `mode=small-chain` 且 `management_status in [managed, migrated]` 的 feature 生效。

### 官方 / 本地适配口径

- `community/superpowers` 以 `community/SOURCES.yaml` 锁定的 upstream ref 为基线，定期更新时优先同步官方原文。
- 本仓库只在 `contracts/superpowers-boundary.yaml` 声明的 overlay、Codex adapter、runtime metadata 和 local-only skill 中承载本地改造。
- `small-chain` 是本地 wrapper contract，不等同于 upstream README 的 Basic Workflow；它在官方 `brainstorming / writing-plans / subagent-driven-development / finishing-a-development-branch` 基础上补充 `verification-before-completion / verify-change / archive` closeout。
- upstream 更新后，如官方流程语义变化，先更新 `community/SOURCES.yaml` 与镜像，再按 `contracts/superpowers-boundary.yaml` 重新裁决本地 overlay 是否仍成立，禁止直接把本地链路写回未声明的官方正文。

当前 small-chain 采用兼容布局：

- 稳定 feature 根：`docs/{feature}/`
- 接手入口：`docs/{feature}/worklog.md`，最新记录只承载 `handoff_status / state_ref / next_ref`
- active workset：`docs/{feature}/YYYY-MM-DD-<change>/`
- `design.md / tasks.md / plan.md` 继续位于 active workset
- 示例：`docs/feature--doc-governance--context-recovery/worklog.md`
- 示例：`docs/feature--doc-governance--context-recovery/2026-04-13-context-contract/plan.md`

上下文接手恢复顺序固定为：

1. 读取 scope registry：`contracts/active-doc-scope.yaml`
2. 打开 `entry_ref` 指向的 `worklog.md`
3. 读取最新记录的 `state_ref` 与 `next_ref`
4. small-chain 回到 `design.md / tasks.md / plan.md`，standard-chain 通过 `canonical:` active artifact ref 回到 canonical JSON

当前链路为：

1. `using-superpowers`（meta）
2. `brainstorming`（entry）
3. `writing-plans`（plan）
4. `using-git-worktrees`（env，按需）
5. `subagent-driven-development`（execute）
6. `verification-before-completion`（verify-preflight）
7. `verify-change`（verify）
8. `finishing-a-development-branch`（integrate，仍有分支集成或 worktree 清理时）
9. `archive`（finish，仅变更已在目标分支完成集成后）

约束：

- 执行统一收口到 `subagent-driven-development`
- 不再依赖 OpenSpec CLI
- `tasks.md` 是唯一完成状态真源
- `test-driven-development` 与 `requesting-code-review` 是实现阶段内嵌门禁，不作为 top-level closeout 节点重复列出
- `verify-change` 通过后才能进入 `finishing-a-development-branch` 或 `archive`
- 若仍有分支集成或 worktree 清理待处理，必须先进入 `finishing-a-development-branch`
- 若已在目标分支且没有分支/worktree 动作待处理，可由 `verify-change` 直接进入 `archive`

自动化收口：

- `tools/community/small_chain_closeout.py` 是 small-chain closeout 的确定性 helper。
- 默认集成策略是 `pr_auto_merge`：`verify-change PASS` 且无 CRITICAL 后创建 PR，并调用 GitHub auto-merge。
- `ci_and_branch_protection` 是合并权威；helper 只启用 auto-merge，不绕过 CI、required review 或分支保护。
- `archive_after_merge` 是唯一自动归档路径；没有 PR merged 或等价目标分支集成证据时，helper 必须 fail closed。

## 轻量改动路径

`small-chain` 是默认链路，但不是所有改动都必须先补齐整套工件。以下场景可以走轻量路径：

- `docs-only / script-only / config-only`
- 单文件小修或局部规则/说明更新
- 尚未建立 `tasks.md / plan.md` 等 small-chain 工件的老仓库

轻量路径仍必须满足：

- 遵守 `shared/rules/*.md` 的硬约束
- 先做影响范围判断，再控制改动边界
- 先明确本次变更对应的成功标准，再运行离改动最近、能直接证明这些标准的 fresh proving command，并如实汇报缺失的 build / lint / test 入口
- 如行为或约束发生变化，同步更新相关文档

## 发布与验证

- 结构与合同验证：`bash tools/validate-contracts.sh`
- 全量质量门禁：`bash tests/run-all.sh`（默认 full）
- 本地快速回归：`bash tests/run-all.sh --quick`
- 全量耗时定位：`bash tests/run-all.sh --profile`
- 快速回归耗时定位：`bash tests/run-all.sh --quick --profile`
- 查看将执行的测试计划：`bash tests/run-all.sh --list` 或 `bash tests/run-all.sh --quick --list`
- 运行能力探针：`bash tools/dev/probe-runtime-capabilities.sh ~/org-claude-skills`
- Codex hooks 探针：`bash tools/dev/probe-codex-hooks.sh`

## Skills 来源与优先级

- `shared/skills/` 只承载 first-party skills
- `community-skill-updater`：manual-only 外部 skill 更新编排器，用于检查 `community/SOURCES.yaml` 纳管来源、按锁定 upstream ref 同步 vendor 内容与 Codex adapters、运行验证并安装到 Claude Code / Codex 后在对话中汇报。
- `feishu-docs`：manual-only 飞书文档 Skill，通过官方 `lark-cli` 读取、创建、更新和删除飞书文档
- `deep-research`：manual-only 横纵分析法 Deep Research Skill，用于手动触发纵向历史、横向对比、横纵交汇的 Markdown + PDF 深度研究报告。
- `community/superpowers/skills/` 承载锁定 ref 的 Superpowers selected skills 与声明式 overlay，upstream 正文保持原文
- `community/anthropic/skills/` 承载全量官方 17 个 skills，正文保持 upstream 原文
- `community/vercel/skills/` 承载按需 vendor 的 Vercel community skills，正文保持 upstream 原文
- `community/alchaincyf/skills/` 承载按需 vendor 的 Alchaincyf community skills，正文保持 upstream 原文
- `community/nextlevelbuilder/skills/` 承载按需 vendor 的 NextLevelBuilder community skills，正文保持 upstream 原文，`ui-ux-pro-max` 在安装层按 manual-only 暴露
- 安装时按 `shared/skills -> community/superpowers/skills -> community/anthropic/skills -> community/vercel/skills -> community/alchaincyf/skills -> community/nextlevelbuilder/skills` 顺序合成运行面
- 同名 skill 默认 first-party 优先；当前唯一官方接管特例是 `mcp-builder`
- 安装、同名保护、manual-only 与前端场景使用口径见 `docs/skill-usage-policy.md`
