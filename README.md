# org-claude-skills

统一维护 Claude Code 与 Codex CLI 的 `skills / rules / reference / hooks / agents`。当前本地业务流程以 first-party `standard-chain` 为准；Superpowers 作为第三方官方 skill 镜像独立维护。

## 当前状态

- 标准流程：runtime id 为 `standard-chain/v1`，合同入口为 `contracts/standard-chain.yaml`
- Superpowers：`community/superpowers/skills` 为 `obra/superpowers` 锁定 ref 的官方 14 个 skill 全量纯镜像
- 受管通用入口：`worklog.md`，仅对 `contracts/active-doc-scope.yaml` 纳管的 feature 生效
- scope registry：`contracts/active-doc-scope.yaml`，只允许 active `standard-chain` scope
- context ownership：`context_owner` 维护 feature 接手链路，`artifact_owner` 维护具体工件正确性
- standard-chain 进度真源：canonical JSON；`worklog.md` 只保存 `handoff_status / state_ref / next_ref` 导航字段

## 仓库结构

- `shared/`：first-party 真源，维护共享入口、规则、参考资料、协议与 first-party skills
- `community/superpowers/`：Superpowers 官方 `skills/` 全量镜像；不得放本地 overlay、adapter、运行时 frontmatter 或本地 skill
- `community/anthropic/`：官方 `anthropics/skills` 镜像目录与 Codex 适配层
- `community/vercel/`：选定 Vercel community skills 的镜像目录与 Codex 适配层
- `community/alchaincyf/`：选定 Alchaincyf community skills 的镜像目录与 Codex 适配层
- `community/nextlevelbuilder/`：选定 NextLevelBuilder community skills 的镜像目录与 Codex 适配层
- `community/panniantong/`：选定 Panniantong community skills 的镜像目录与 Codex 适配层
- `community/skills-sh/`：选定 skills.sh community skills 的镜像目录与 Codex 适配层；manual-only skill 不生成 Codex adapter
- `community/persona/`：persona 类第三方 skill 镜像目录
- `contracts/`：标准流程、active scope、canonical registry 与 Superpowers 边界合同
- `docs/`：默认历史材料与非运行时文档；被 `contracts/active-doc-scope.yaml` 纳管的 `docs/{feature}` 目录视为受管活跃子集
- `claude/`：Claude 适配层
- `codex/`：Codex 适配层

## 当前真源

- 入口合同：`shared/assistant.md`
- 来源锁定：`community/SOURCES.yaml`
- Superpowers 边界：`contracts/superpowers-boundary.yaml`
- Superpowers 官方镜像：`community/superpowers/skills`
- 标准流程合同：`contracts/standard-chain.yaml`
- 标准流程 runtime catalog：`shared/runtime/standard-chain-catalog.json`
- active scope registry：`contracts/active-doc-scope.yaml`
- context artifact ownership：`contracts/context-artifact-ownership.yaml`
- Skill 质量维度：`shared/skills/skill-refiner/references/quality-dimensions.md`
- Skill runtime surface：`contracts/skill-runtime-surface.json`，统一声明 auto/manual/off 与 Claude/Codex 安装策略
- Planning with Files：`community/skills-sh/skills/planning-with-files` 作为手动触发的第三方 scratchpad skill 纳入安装与 `skill-pull` 更新管理；不得替代 `standard-chain` canonical artifacts

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

Claude 安装默认会把托管 hooks 合并到 `~/.claude/settings.json`，并在 quick check 中校验关键 hooks 已生效。`--merge-hooks` 仅保留给旧脚本兼容场景。

Codex 安装会默认完成：

- 托管启用 `~/.codex/config.toml` 中的 `features.hooks = true`，并清理旧版 `features.codex_hooks`
- 托管配置 `~/.codex/config.toml` 中的 `[agents]` 并注册 first-party sub agents；agent 模型分层写在 `codex/agents/*.toml`
- 将仓库管理的 hooks 合并到 `~/.codex/hooks.json`，保留 Codex 官方 hooks 事件面上的用户 hooks，并清理不在 Codex 事件面内的旧事件
- 将 Codex 用户级 skill 落位到官方路径 `~/.agents/skills/<skill>/SKILL.md`；不安装任何 Superpowers 来源的 `agents/openai.yaml`
- 归档并清理旧路径 `~/.codex/skills/<skill>` 的非隐藏残留，避免 Codex skill 双路径污染

Codex 0.129+ 会对 enabled hooks 做独立 trust/review。因为 Codex hooks 可在 sandbox 外以当前系统用户权限运行，本仓库只安装和校验配置，不自动写入 trust。`install.sh --check quick` 只强制验收仓库管理的 Codex hooks；当前机器所有 enabled hooks 是否已消除 review warning，用 `tools/dev/probe-codex-hooks.sh` 全量检查。若任一命令报告 `Codex hooks 尚未全部 trusted/managed`，在 Codex 里进入当前仓库执行 `/hooks`，逐条核对命令与路径后信任，再重新运行：

```bash
bash install.sh --target all --check quick
bash tools/dev/probe-codex-hooks.sh ~/org-claude-skills
```

组织级无人值守场景应使用 Codex 官方 `requirements.toml` managed hooks：由管理员在系统或云端 requirements 中声明 `[hooks]` 与 `hooks.managed_dir`，并通过 MDM/设备管理分发脚本。本仓库不会把用户级 `~/.codex/hooks.json` 伪装成 managed hooks。

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

## Superpowers 边界

- `community/superpowers` 只 vendor 官方 `skills/`，并由 `community/SOURCES.yaml` 锁定到具体 commit。
- 本地不在 Superpowers 镜像内放 overlay、Codex adapter、source header、运行时可见性 frontmatter 或本地-only skill。
- 安装层动态复制 `community/superpowers/skills/*` 到 Claude/Codex runtime。
- Codex 发现机制以官方用户级 `~/.agents/skills/<skill>/SKILL.md` 落位为准；自动触发只依据官方 `SKILL.md` frontmatter。
- first-party 标准流程只归属 `shared/`、`contracts/standard-chain.yaml`、`contracts/canonical/` 和相关 runtime 工具。

## Standard Chain

standard-chain 的接手恢复顺序固定为：

1. 读取 scope registry：`contracts/active-doc-scope.yaml`
2. 打开 `entry_ref` 指向的 `worklog.md`
3. 读取最新记录的 `state_ref` 与 `next_ref`
4. 通过 `canonical:` active artifact ref 回到 canonical JSON

约束：

- `contracts/active-doc-scope.yaml` 的 active mode 只允许 `standard-chain`
- `worklog.md` 不复制 PRD、设计、任务或验收全文，只保存导航字段
- canonical JSON 是进度和状态真源
- `validate_context_contract.py`、`recover_context.py`、`tools/validate-contracts.sh` 和相关测试负责证明接手链路可恢复

## 完成前验证

所有改动使用同一套完成前验证规则：

- 遵守 `shared/rules/*.md` 的硬约束
- 先做影响范围判断，再控制改动边界
- 先明确本次变更对应的成功标准，再运行能直接证明这些标准的 fresh proving command
- 如行为或约束发生变化，同步更新相关文档

## 发布与验证

- 来源锁定验证：`python3 tools/community/source_lock_check.py`
- Superpowers 镜像验证：`python3 tools/community/check_superpowers_upstream_fidelity.py`
- 结构与合同验证：`bash tools/validate-contracts.sh`
- 全量质量门禁：`bash tests/run-all.sh`
- 本地快速回归：`bash tests/run-all.sh --quick`
- 运行能力探针：`bash tools/dev/probe-runtime-capabilities.sh ~/org-claude-skills`
- Codex hooks trust 探针：`bash tools/dev/probe-codex-hooks.sh`

## Skills 来源与优先级

- `shared/skills/` 只承载 first-party skills
- `skill-pull`：manual-only 外部 skill 拉取编排器，用于检查 `community/SOURCES.yaml` 纳管来源、按锁定 upstream ref 同步 vendor 内容与 adapter-bearing 来源的 Codex adapters、运行验证并安装到 Claude Code / Codex 后在对话中汇报
- `feishu-docs`：manual-only 飞书文档 Skill，通过官方 `lark-cli` 读取、创建、更新和删除飞书文档
- `deep-research`：manual-only 横纵分析法 Deep Research Skill，用于手动触发纵向历史、横向对比、横纵交汇的 Markdown + PDF 深度研究报告
- `community/superpowers/skills/` 承载锁定 ref 的 Superpowers 官方全量 skills，正文保持 upstream 原文
- `community/anthropic/skills/` 承载全量官方 17 个 skills，正文保持 upstream 原文；其中 `skill-creator` 仅安装到 Claude 运行面，Codex 使用内置系统 `skill-creator`，不安装用户级副本且不保留 Codex 适配层
- `community/vercel/skills/` 承载按需 vendor 的 Vercel community skills，正文保持 upstream 原文
- `community/alchaincyf/skills/` 承载按需 vendor 的 Alchaincyf community skills，正文保持 upstream 原文
- `community/nextlevelbuilder/skills/` 承载按需 vendor 的 NextLevelBuilder community skills，正文保持 upstream 原文，`ui-ux-pro-max` 在安装层按 auto 暴露
- `community/panniantong/skills/` 承载按需 vendor 的 Panniantong community skills，正文保持 upstream 原文，当前包含 `agent-reach`
- `community/skills-sh/skills/` 承载按需 vendor 的 skills.sh community skills，正文保持 upstream 原文，当前包含 `baoyu-markdown-to-html`、`bb-browser`、`code-to-prd`、`graphify`、`humanizer-zh`、`notebooklm`、`prd`、`self-improving-agent`、`to-prd`；其中 `baoyu-markdown-to-html`、`code-to-prd`、`graphify`、`prd`、`self-improving-agent`、`to-prd` 在安装层按 manual-only 暴露且不生成 Codex adapter
- 安装时按 `shared/skills -> community/superpowers/skills -> community/anthropic/skills -> community/vercel/skills -> community/alchaincyf/skills -> community/nextlevelbuilder/skills -> community/panniantong/skills -> community/skills-sh/skills -> community/persona/skills` 顺序合成运行面
- 同名 skill 默认 first-party 优先；当前唯一官方接管特例是 `mcp-builder`
