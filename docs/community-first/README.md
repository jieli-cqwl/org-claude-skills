# Community-First 总览

目标：给团队一个一眼能看懂的总览，明确 `community-first` 是什么、目录怎么分、默认链怎么走，以及和标准链怎么共存。

## 定位

- `community-first` 是**日常小需求默认流程**
- `OpenSpec` 管**改什么**
- `superpowers` 管**怎么改**
- 本地标准链 `/product -> /design -> /test-design -> /tech-lead -> /project-manager` 管**大需求强治理**

它不是：

- 标准流程的裁剪版
- 本地自造 orchestrator
- 标准流程替代品

## 默认链

未显式调用 skill 时，默认走：

`brainstorming -> opsx:propose -> writing-plans -> using-git-worktrees -> opsx:apply -> (subagent-driven-development 默认 / executing-plans 备选) -> requesting-code-review -> verification-before-completion -> opsx:verify -> opsx:archive`

规则补充：

- `using-superpowers` 是元规则，**manual-only**
- `brainstorming` 是唯一默认自动入口
- 标准链保持可用，但为**显式手动入口**

对应文件：

- 入口合同：[shared/assistant.md](/Users/lijieli/org-claude-skills/shared/assistant.md)
- 行为纪律：[shared/rules/执行纪律.md](/Users/lijieli/org-claude-skills/shared/rules/执行纪律.md)
- 链路合同：[contracts/community-first-chain.yaml](/Users/lijieli/org-claude-skills/contracts/community-first-chain.yaml)

说明：`shared/assistant.md` 只负责 always-on 入口合同；完整 workflow 顺序、manual-only 策略与 artifact chain 以本文件和 contract 为准。

## 目录结构

```text
community/
  SOURCES.yaml                 # 来源锁定（repo / ref / captured_at / scope）
  openspec/                    # OpenSpec 中文 canonical runtime
    skills/
    claude/commands/opsx/
  superpowers/                 # superpowers 中文 canonical runtime
    skills/
    agents/
    codex/skills/brainstorming/agents/openai.yaml

openspec/
  config.yaml                  # 本地 OpenSpec 配置
  designs/                     # brainstorming 设计草稿
  plans/                       # writing-plans 计划稿
  changes/                     # 当前 change
  changes/archive/             # 已归档 changes
  specs/                       # 长期行为真源

contracts/
  community-first-chain.yaml   # community-first 阶段合同
```

## Source Of Truth

分层固定为：

1. community 中文 canonical runtime
- `community/superpowers`
- `community/openspec`

2. 来源锁定
- `community/SOURCES.yaml`
- 只保留：
  - upstream repo URL
  - ref / tag / commit
  - captured_at
  - 参考范围

3. 本地运行工作区
- `openspec/`
- 承载设计草稿、执行计划、change、spec、archive

不允许做的事：

- 把英文 upstream 正文继续作为本地运行真源
- 为贴合 first-party 模板而改写社区流程顺序
- 改写 `opsx:*` 状态机职责
- 让 `tasks.md` 与 `plan.md` 成为双真源

## 运行面策略

### Claude

- community-first 组件正常安装
- 默认入口是 `brainstorming`
- 本地标准链和重叠 workflow skill 通过 `disable-model-invocation: true` 降为 manual-only
- OpenSpec 侧通过 `community/openspec/claude/commands/opsx/*.md` 提供 `/opsx:*`

### Codex

- 自动暴露面保留 `brainstorming`
- `using-superpowers`、标准链、以及本地重叠 workflow skill 继续安装，但移除 `agents/openai.yaml`，降为 manual-only
- `opsx:*` 不再走 prompts，而是安装为原生 `openspec-*` skills：
  - `openspec-propose`
  - `openspec-apply-change`
  - `openspec-verify-change`
  - `openspec-archive-change`
  - `openspec-explore`

manual-only 的典型集合：

- `using-superpowers`
- `product`
- `design`
- `test-design`
- `tech-lead`
- `project-manager`
- `developer`
- `review`
- `verify`
- `qa`
- `worktree`
- `commit`
- `ux`

## 适用边界

适合：

- 单次可收口的小需求
- 目标明确、风险低到中
- 不需要多阶段排期
- 可以在一次 change 内讲清行为变化

不适合：

- 多阶段交付
- 核心模型或核心 API 大改
- 高风险安全/性能/兼容变更
- 需要完整正式审查链的需求

超界时，直接显式切到 `/product`，v1 不做自动升级。

## 日常使用方式

### 小需求

1. 直接描述需求，不显式调 skill
2. 默认进入 `brainstorming`
3. 收口后进入 `opsx:*` + superpowers 执行链
4. 以 `opsx:archive` 作为完成定义

### 大需求

1. 显式调用 `/product`
2. 继续走标准链

## 相关文档

- RFC：[docs/rfcs/2026-03-26_community-first默认流RFC.md](/Users/lijieli/org-claude-skills/docs/rfcs/2026-03-26_community-first默认流RFC.md)
- 投入使用时机：[docs/community-first/go-live-plan.md](/Users/lijieli/org-claude-skills/docs/community-first/go-live-plan.md)
- 试点执行清单：[docs/community-first/pilot-rollout-checklist.md](/Users/lijieli/org-claude-skills/docs/community-first/pilot-rollout-checklist.md)
- 采用建议：[docs/reports/readiness/2026-03-26_community-first轻量流程采用建议.md](/Users/lijieli/org-claude-skills/docs/reports/readiness/2026-03-26_community-first轻量流程采用建议.md)
- OpenSpec 本地 canonical 实施计划：[docs/openspec-local-canonical/implementation-plan.md](/Users/lijieli/org-claude-skills/docs/openspec-local-canonical/implementation-plan.md)
- OpenSpec 本地 canonical 调研报告：[docs/openspec-local-canonical/research-report.md](/Users/lijieli/org-claude-skills/docs/openspec-local-canonical/research-report.md)
- 团队运行验收：[docs/runtime-acceptance-sop.md](/Users/lijieli/org-claude-skills/docs/runtime-acceptance-sop.md)
