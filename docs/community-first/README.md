# Community-First 总览

目标：给团队一个一眼能看懂的总览，明确 `community-first` 是什么、目录怎么分、默认链怎么走、和标准链怎么共存。

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

- 默认入口文档：[shared/assistant.md](/Users/lijieli/org-claude-skills/shared/assistant.md)
- 执行纪律：[shared/rules/执行纪律.md](/Users/lijieli/org-claude-skills/shared/rules/执行纪律.md)
- 链路合同：[contracts/community-first-chain.yaml](/Users/lijieli/org-claude-skills/contracts/community-first-chain.yaml)

## 目录结构

```text
third_party/community/
  openspec/                    # OpenSpec upstream 快照
  superpowers/                 # superpowers upstream 快照

community-adapters/
  claude/commands/opsx/        # Claude 侧 opsx 命令落位
  codex/prompts/               # Codex 侧 opsx prompt 落位
  codex/skills/brainstorming/  # Codex 自动暴露 metadata

openspec/
  config.yaml                  # 本地 OpenSpec 配置
  changes/archive/             # 已归档 changes
  specs/                       # 长期行为真源

contracts/
  community-first-chain.yaml   # community-first 阶段合同
```

## Source Of Truth

分层固定为：

1. upstream 正文
- `third_party/community/superpowers`
- `third_party/community/openspec`

2. 本地薄适配
- `community-adapters/`
- 只允许：
  - platform metadata
  - `openai.yaml`
  - Claude/Codex 命令或 prompt 落位
  - 路径与占位符归一化
  - 安装映射

3. 本地运行工作区
- `openspec/`
- 承载 change、spec、archive

不允许做的事：

- 改写 upstream 流程步骤
- 改写 upstream 角色和门禁
- 本地重命名 upstream skill 或 `opsx:*`
- 手写维护 `opsx:*` 正文

## 运行面策略

### Claude

- community-first 组件正常安装
- 默认入口是 `brainstorming`
- 本地标准链和重叠 workflow skill 通过 `disable-model-invocation: true` 降为 manual-only

### Codex

- 自动暴露面保留 `brainstorming`
- `using-superpowers`、标准链、以及本地重叠 workflow skill 继续安装，但移除 `agents/openai.yaml`，降为 manual-only
- `opsx:*` 通过 prompt 形式安装

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
- 社区快照说明：[third_party/community/README.md](/Users/lijieli/org-claude-skills/third_party/community/README.md)
- 适配层说明：[community-adapters/README.md](/Users/lijieli/org-claude-skills/community-adapters/README.md)
- 团队运行验收：[docs/runtime-acceptance-sop.md](/Users/lijieli/org-claude-skills/docs/runtime-acceptance-sop.md)
