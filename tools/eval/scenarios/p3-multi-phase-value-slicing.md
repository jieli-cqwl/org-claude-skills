# P3: /product 多闭环功能的 Phase 切片场景

用途：验证 `/product` 的 `S6 Phase 切片` 是否真按业务价值切片，而不是按功能均分或提前越界成执行计划。

## 场景概述

让 LLM agent 自主执行 `/product` 流程，输入是一组天然存在“核心闭环 + 后续增强”的需求。重点观察它是否能把最小价值闭环收成 Phase 1，并把通知、统计等增强能力放在后续 Phase，同时不把项目排期、并行批次等实施信息写进 `/product`。

## 输入

- 用户首句：`我们要做一个内部审批系统，本期至少要能提交申请、审批通过或驳回、查看审批记录；后面还想接企业微信通知和统计报表。`
- 现有工件：无

## Executor Prompt 模板

```text
你是一个自主执行 /product 流程的 agent。

## 任务
围绕以下用户需求执行完整的 /product 流程，输出可交接的需求基线。

用户首句：
我们要做一个内部审批系统，本期至少要能提交申请、审批通过或驳回、查看审批记录；后面还想接企业微信通知和统计报表。

## Skill 规则
插入当前 /product skill 内容。

## 共创模拟
本次执行中，用户回应由以下脚本预定义。当你到达需要用户输入的步骤时，使用对应回答继续推进。

## 输出要求
- 所有输出写入 `tools/eval/results/p3-multi-phase-value-slicing-run-{n}/`
- 必须产出 `docs/internal-approval/brief.md`
- 必须产出 `docs/internal-approval/phase-{N}/prd.md`
- 必须产出 `docs/internal-approval/phase-{N}/units/UNIT-*.md`
- 完成后补一份 `executor-notes.md`，说明你如何判断 Phase 边界
```

## 模拟用户回应脚本

### S1 需求理解（无需用户输入）

无。executor 直接读取用户首句。

### S2 根问题澄清

当 executor 追问“这套审批系统要先解决什么问题”时：

> 回答：现在大家通过聊天工具和表格提审批，记录分散、结果难追踪，经常不知道某个申请到底卡在哪一步。最先要解决的是让申请、审批结果和历史记录可追踪。

### S3 目标与成功标准对齐

当 executor 询问成功标准时：

> 回答：Phase 1 完成后，员工能提交审批申请，审批人能处理并给出通过或驳回结果，申请人和管理员都能查看审批记录；一笔申请的当前状态要清晰可见，不再依赖线下追问。

### S4 业务语义收口

当 executor 询问核心对象和术语时：

> 回答：核心对象是审批申请、审批结果、审批记录。审批结果至少有待处理、通过、驳回三种状态；审批记录需要能查看提交人、审批人、时间和处理结果。

### S5 范围与规则收口

当 executor 呈现范围和排除项时：

> 回答：确认。本期不做企业微信通知、不做统计报表、不做多级会签，也不做复杂 SLA 规则。先保证一个审批闭环跑通。

### S6 交付节奏决策

当 executor 询问 Phase 如何划分时：

> 回答：我希望至少把“提交申请 + 审批处理 + 查看记录”作为第一个完整闭环。企业微信通知可以后续加，统计报表也可以单独放后面，不要混进第一期。

### S7 逐 Phase UNIT 拆解

当 executor 呈现 Phase 与 UNIT 草案时：

> 回答：确认。Phase 1 要能单独交付业务价值；后续 Phase 只要说明各自增加了什么新价值，不要在这里展开任务批次或人员安排。

### S8 验收标准定义

当 executor 呈现 AC 草案时：

> 回答：确认。请保证申请提交、审批驳回、审批通过、查看历史、无权限访问这几类场景都能直接验证。

### S9 待设计决策

当 executor 询问开放问题时：

> 回答：有两个设计决策需要保留：通知接企业微信的触发和失败补偿机制，以及统计报表的维度与数据刷新方式。Phase 1 不要提前把这些技术方案定死。

### S10 完整性扫描

当 executor 做完整性扫描时：

> 回答：补充一点，审批被驳回后，申请人需要能在记录里看见驳回原因；但驳回后是否允许直接重新提交，先不在本期范围内。

### S11 跨职能审查（无需用户输入）

无。executor 自行完成 reviewer 调用与问题修复。

### S12 用户确认并输出

当 executor 呈现最终需求基线时：

> 回答：确认，输出最终文件。

## 评分

每次执行完成后调用：
1. `tools/eval/graders/product-thinking-grader.md` → 输出 `grading-product-thinking.json`
2. `tools/eval/graders/problem-discovery-grader.md` → 输出 `grading-problem-discovery.json`
3. `tools/eval/graders/phase-slicing-quality-grader.md` → 输出 `grading-phase-slicing-quality.json`
4. `tools/eval/graders/process-lightness-grader.md` → 输出 `grading-process-lightness.json`

## 结果目录

```text
results/
└── p3-multi-phase-value-slicing-run-1/
    ├── docs/internal-approval/brief.md
    ├── docs/internal-approval/phase-{N}/prd.md
    ├── docs/internal-approval/phase-{N}/units/UNIT-*.md
    ├── executor-notes.md
    ├── grading-product-thinking.json
    ├── grading-problem-discovery.json
    ├── grading-phase-slicing-quality.json
    └── grading-process-lightness.json
```
