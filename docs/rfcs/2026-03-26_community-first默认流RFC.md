# RFC: Community-First 默认流

- RFC ID：`RFC-2026-03-26-community-first-default-flow`
- Status：`Accepted for Pilot`
- Date：`2026-03-26`
- Scope：`org-claude-skills`

## 1. 背景

当前仓库长期默认入口是本地标准链：

`/product -> /design -> /test-design -> /tech-lead -> /project-manager`

这条链在大需求、高风险变更和强治理场景下是合理的，但用于日常小需求时，存在两个明显问题：

1. 前置工件和阶段门禁偏重
2. 默认自动入口与真实使用频率不匹配

同时，社区里已经出现两类被验证过的方法：

- `OpenSpec`：把“改什么”沉淀为 change/spec 体系
- `superpowers`：把“怎么改”收口为 agent workflow discipline

因此需要一条新的默认流，满足下面 4 个目标：

1. 适合日常小需求
2. 保留需求澄清与执行质量
3. 不破坏现有标准链
4. 尽量直接复用 community 语义，而不是本地重写

## 2. 决策

本 RFC 的决策是：

1. 日常小需求默认流采用 `community-first`
2. 默认自动入口固定为 `brainstorming`
3. `using-superpowers` 作为元规则保留，但降为 `manual-only`
4. 规格侧采用 `OpenSpec` 的 `opsx:*` 核心命令：
   - `opsx:propose`
   - `opsx:apply`
   - `opsx:verify`
   - `opsx:archive`
5. 本地标准链继续保留，但统一降为显式手动入口
6. v1 不做 automatic upgrade，不做轻量链到标准链的自动迁移

一句话概括：

`community-first` 成为日常小需求默认流，标准链退回大需求显式入口。

## 3. 非目标

本 RFC 明确不做下面这些事：

1. 不用 `community-first` 替代标准链
2. 不在本地重写一套看起来像 `superpowers`/`OpenSpec` 的正文
3. 不做轻量链到标准链的自动升级
4. 不要求历史 release/review/hotfix 文档回写新口径
5. 不把所有 skill 都强行统一成同一暴露策略

## 4. 总体模型

三层边界固定如下：

- `OpenSpec`：管改什么
- `superpowers`：管怎么改
- 本地标准链：管大需求强治理

这意味着：

- `community-first` 不是标准链裁剪版
- `community-first` 不是本地 orchestrator
- `community-first` 是“community 正文优先 + 本地薄适配”的默认小需求流

## 5. 默认链定义

未显式调用 skill 时，默认进入：

`brainstorming -> opsx:propose -> writing-plans -> using-git-worktrees -> opsx:apply -> (subagent-driven-development 默认 / executing-plans 备选) -> requesting-code-review -> verification-before-completion -> opsx:verify -> opsx:archive`

补充规则：

- `using-superpowers` 是元规则，但不作为默认自动入口
- `brainstorming` 是唯一默认自动入口
- 完成定义以 `opsx:archive` 为准，而不是“代码已经写完”

## 6. 目录与真源

### 6.1 分层

```text
shared/                       # first-party 真源
third_party/community/        # upstream 快照
community-adapters/           # 薄适配层
openspec/                     # 本地 change/spec 工作区
contracts/                    # 链路合同
```

### 6.2 Source Of Truth

1. first-party 真源
- `shared/`

2. community upstream 快照
- `third_party/community/superpowers`
- `third_party/community/openspec`

3. community 薄适配层
- `community-adapters/`

4. change/spec 运行工作区
- `openspec/`

### 6.3 适配层边界

允许：

- platform metadata
- `openai.yaml`
- Claude/Codex 命令或 prompt 落位
- 路径与占位符归一化
- 安装映射

禁止：

- 改写 upstream 流程步骤
- 改写 upstream 角色与门禁
- 重命名 upstream skill 或 `opsx:*`
- 手工维护 `opsx:*` 正文

## 7. 平台运行面策略

### 7.1 Claude

- 默认小需求入口：`brainstorming`
- community-first 组件正常安装
- 本地标准链与本地重叠 workflow skill 通过 `disable-model-invocation: true` 降为 `manual-only`

### 7.2 Codex

- 默认自动暴露面只保留 `brainstorming`
- `using-superpowers`、标准链与本地重叠 workflow skill 继续安装，但移除 `agents/openai.yaml`
- `opsx:*` 以 prompt 形式进入运行面

Codex 的典型 `manual-only` 集合：

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

## 8. 适用边界

### 8.1 适合 community-first

- 单次可收口
- 目标明确
- 风险低到中
- 不需要多阶段排期
- 一次 change 内能讲清行为变化
- 不需要完整正式审查链

### 8.2 不适合 community-first

- 多阶段交付
- 核心数据模型或核心 API 大改
- 高风险安全/性能/兼容变更
- 跨系统/跨团队协同
- 难以在短对话中收口的复杂需求
- 必须走正式测试设计、正式计划、正式验收分级

超界处理：

- 显式切到 `/product`
- v1 不做自动升级

## 9. 运行前置条件

`community-first` 默认流依赖下面这些条件：

1. `openspec` CLI 已安装并可执行
2. `opsx:*` adapter 与 upstream 模板保持同步
3. Codex 默认自动发现面已正确收窄到 `brainstorming`
4. 标准链与重叠 workflow skill 已完成降级

任何缺失都会使默认流处于“不应发布”的状态。

## 10. 证据基础

本 RFC 不是纯设计提案，已经有下面这些证据：

1. 仓库级回归通过
- `bash tests/run-all.sh`

2. 真实 `OpenSpec 1.2.0` 隔离环境闭环通过
- `init`
- `new change`
- `status`
- `instructions`
- `change validate`
- `archive`

3. 真实小需求样本通过
- 登录页
- 后端登录接口
- 本地存储登录态
- 刷新恢复
- 登出
- 动画首页
- Playwright 桌面端和移动端验收

## 11. 后果与权衡

### 11.1 获得的收益

1. 默认入口更符合日常小需求使用场景
2. 需求澄清、计划、验证、归档仍然保留
3. community 语义得到直接复用，减少本地重写失真
4. 标准链继续存在，不会因轻量流引入治理缺口

### 11.2 接受的代价

1. 引入了 `third_party/community` 和 `community-adapters` 两层结构
2. 需要维护 upstream 快照与本地适配同步
3. 团队需要学习新默认入口和双轨制边界
4. `openspec` CLI 成为明确运行前置

## 12. Rollout 决策

当前 rollout 口径固定为：

- 小需求默认流：`GO`
- 大需求替代标准链：`NO-GO`
- 自动升级迁移：`NO-GO`
- 团队全面立即切换：`NO-GO`
- 小范围试点：`GO`

因此本 RFC 的执行状态是：

`Accepted for Pilot`

## 13. 关联文档

- 总览：[docs/community-first/README.md](/Users/lijieli/org-claude-skills/docs/community-first/README.md)
- 投入使用时机：[docs/community-first/go-live-plan.md](/Users/lijieli/org-claude-skills/docs/community-first/go-live-plan.md)
- 试点执行清单：[docs/community-first/pilot-rollout-checklist.md](/Users/lijieli/org-claude-skills/docs/community-first/pilot-rollout-checklist.md)
- 采用建议：[docs/reports/readiness/2026-03-26_community-first轻量流程采用建议.md](/Users/lijieli/org-claude-skills/docs/reports/readiness/2026-03-26_community-first轻量流程采用建议.md)
- 默认入口文档：[shared/assistant.md](/Users/lijieli/org-claude-skills/shared/assistant.md)
- 执行纪律：[shared/rules/执行纪律.md](/Users/lijieli/org-claude-skills/shared/rules/执行纪律.md)
- 链路合同：[contracts/community-first-chain.yaml](/Users/lijieli/org-claude-skills/contracts/community-first-chain.yaml)
- 运行验收：[docs/runtime-acceptance-sop.md](/Users/lijieli/org-claude-skills/docs/runtime-acceptance-sop.md)
- 运行时验证：[docs/runtime-validation.md](/Users/lijieli/org-claude-skills/docs/runtime-validation.md)
