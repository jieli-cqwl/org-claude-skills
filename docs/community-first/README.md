# Community-First 总览

目标：给团队一个一眼能看懂的总览，明确 `community-first` 是什么、分层怎么切、默认链由谁定义，以及和标准链怎么共存。

## 定位

- `community-first` 是**本地默认编排层**
- `superpowers` 管**怎么改**
- OpenSpec 管**工件语义**
- 本地标准链 `/product -> /design -> /test-design -> /tech-lead -> /project-manager` 管**大需求强治理**

它不是：

- 标准流程的裁剪版
- 本地自造 orchestrator
- 标准流程替代品

## 默认链

默认入口仍是 `brainstorming`。完整链路与 handoff 以 `contracts/community-first-chain.yaml` 为机器真源，以 `docs/community-first/boundary-contract.md` 为分层真源。

当前最佳实践目标是：

`brainstorming -> writing-plans -> using-git-worktrees -> (subagent-driven-development 默认 / executing-plans 备选) -> requesting-code-review -> verification-before-completion`

OpenSpec 在本仓库中提供 `proposal / design / tasks / verify / archive` 的工件语义，不再作为未来默认运行时链路真源。

规则补充：

- `using-superpowers` 是元规则，**manual-only**
- `brainstorming` 是唯一默认自动入口
- 标准链保持可用，但为**显式手动入口**

对应文件：

- 入口合同：[shared/assistant.md](../../shared/assistant.md)
- 行为纪律：[shared/rules/执行纪律.md](../../shared/rules/执行纪律.md)
- 链路合同：[contracts/community-first-chain.yaml](../../contracts/community-first-chain.yaml)

说明：`shared/assistant.md` 只负责 always-on 入口合同；完整分层与链路职责以 `docs/community-first/boundary-contract.md` 和 `contracts/community-first-chain.yaml` 为准。

## 目录结构

```text
community/
  SOURCES.yaml                 # 来源锁定（repo / ref / captured_at / scope）
  superpowers/                 # superpowers 中文 canonical runtime
    skills/
    agents/
    codex/skills/brainstorming/agents/openai.yaml
  openspec/                    # 兼容库存或迁移过渡资产（如仍保留）

openspec/
  config.yaml                  # 可选兼容配置，仅供历史资产或过渡脚本使用
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

1. upstream 方法论运行资产
- `community/superpowers`

2. 本地编排与边界真源
- `docs/community-first/boundary-contract.md`
- `contracts/community-first-chain.yaml`

3. 来源锁定
- `community/SOURCES.yaml`
- 只保留：
  - upstream repo URL
  - ref / tag / commit
  - captured_at
  - 参考范围

4. 本地运行工作区
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
- 若仍保留 `community/openspec` 相关资产，仅作为兼容库存，不作为未来默认编排真源

### Codex

- 自动暴露面保留 `brainstorming`
- `using-superpowers`、标准链、以及本地重叠 workflow skill 继续安装，但移除 `agents/openai.yaml`，降为 manual-only
- 若仍保留 `openspec-*` 相关安装项，仅视为兼容路径，不作为 future-state 的默认链定义

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
3. 进入 `writing-plans` 与 superpowers 执行链
4. proposal / design / tasks / verify / archive 等工件语义由本地模板、contract 与 validator 承接

### 大需求

1. 显式调用 `/product`
2. 继续走标准链

## 相关文档

- 试点执行入口：[docs/community-first/试点执行入口.md](./试点执行入口.md)
- RFC：[docs/rfcs/2026-03-26_community-first默认流RFC.md](../rfcs/2026-03-26_community-first默认流RFC.md)
- 边界合同：[docs/community-first/boundary-contract.md](./boundary-contract.md)
- 投入使用时机：[docs/community-first/go-live-plan.md](./go-live-plan.md)
- 试点执行清单：[docs/community-first/pilot-rollout-checklist.md](./pilot-rollout-checklist.md)
- 试点模板目录：[docs/community-first/templates](./templates)
- 试点记录目录：[docs/community-first/pilot-records](./pilot-records)
- 采用建议：[docs/reports/readiness/2026-03-26_community-first轻量流程采用建议.md](../reports/readiness/2026-03-26_community-first轻量流程采用建议.md)
- 团队运行验收：[docs/runtime-acceptance-sop.md](../runtime-acceptance-sop.md)
