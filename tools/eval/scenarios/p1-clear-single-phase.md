# P1: /product 清晰需求轻量收口场景

用途：验证 `/product` 在边界清晰的小需求上能否轻量收口，而不是机械走重流程。

## 场景概述

让 LLM agent 自主执行 `/product` 流程，以一个单闭环、单 Phase 的需求为输入，观察它是否会过度追问、过度 Phase 化，或把简单需求拆成无业务价值的多个 UNIT。

## 输入

- 用户首句：`给内部周报系统加一个已发布周报列表页，登录后可分页查看已发布周报，先不做搜索和编辑。`
- 现有工件：无（从一次新的需求共创开始）

## Executor Prompt 模板

```text
你是一个自主执行 /product 流程的 agent。

## 任务
围绕以下用户需求执行完整的 /product 流程，输出可交接的需求基线。

用户首句：
给内部周报系统加一个已发布周报列表页，登录后可分页查看已发布周报，先不做搜索和编辑。

## Skill 规则
插入当前 /product skill 内容。

## 共创模拟
本次执行中，用户回应由以下脚本预定义。当你到达需要用户输入的步骤时，使用对应回答继续推进。

## 输出要求
- 所有输出写入 `tools/eval/results/p1-clear-single-phase-run-{n}/`
- 必须产出 `docs/published-report-list/brief.md`
- 必须产出 `docs/published-report-list/phase-1/prd.md`
- 必须产出 `docs/published-report-list/phase-1/units/UNIT-*.md`
- 完成后补一份 `executor-notes.md`，记录你认为本场景最容易过度处理的点
```

## 模拟用户回应脚本

以下回答按 `/product` 流程步骤编排，executor 到达对应步骤时使用该回答。

### S1 需求理解（无需用户输入）

无。executor 直接读取用户首句。

### S2 根问题澄清

当 executor 追问“为什么要做这个列表页”时：

> 回答：现在大家要看已发布周报时只能让管理员临时导出或在数据库里查，信息获取太慢。这个功能的目标是让登录后的内部员工能自己查看最近发布的周报。

当 executor 追问“登录是否在本次范围内”时：

> 回答：登录能力已经存在，本次只做登录后可访问的已发布周报列表，不重做认证流程。

### S3 目标与成功标准对齐

当 executor 询问成功标准时：

> 回答：希望普通员工进入系统后 1 分钟内能找到最近发布的周报；列表默认按发布时间倒序；第一页打开时就能看到内容，不需要额外筛选。

### S4 业务语义收口

当 executor 询问关键术语和对象时：

> 回答：`已发布周报` 指状态已经是 published 的周报；列表项至少展示标题、作者、发布时间；只允许已登录用户查看，未登录用户不在这个需求里展开，因为认证已是现有能力。

### S5 范围与规则收口

当 executor 呈现范围和排除项时：

> 回答：确认，本期范围只有列表页和分页查看。不做搜索、不做按作者筛选、不做周报编辑，也不做导出。

当 executor 追问分页规则时：

> 回答：每页 10 条，支持上一页和下一页即可，先不要求跳页或自定义每页数量。

### S6 交付节奏决策

当 executor 询问是否需要多 Phase 时：

> 回答：不需要，本期就是一个单独闭环，交付一个 Phase 就行。

### S7 逐 Phase UNIT 拆解

当 executor 呈现 UNIT 草案时：

> 回答：确认，列表展示和分页行为可以放在同一个闭环里，只要能直接交给下游继续做。

### S8 验收标准定义

当 executor 呈现 AC 草案时：

> 回答：确认。请确保正常场景、未登录访问、分页边界都能被测试直接验证。

### S9 待设计决策

当 executor 询问是否有需要交给 design 的开放问题时：

> 回答：有一个开放问题即可：分页接口是前端本地分页还是后端分页，由 design 结合数据量和现有接口决定。

### S10 完整性扫描

当 executor 进行遗漏扫描时：

> 回答：补充一点，列表为空时也要给用户明确提示，但不需要空状态插画之类的设计细节。

### S11 跨职能审查（无需用户输入）

无。executor 自行完成 reviewer 调用与问题修复。

### S12 用户确认并输出

当 executor 呈现最终需求基线时：

> 回答：确认，输出最终文件。

## 评分

每次执行完成后调用：
1. `tools/eval/graders/product-thinking-grader.md` → 输出 `grading-product-thinking.json`

## 结果目录

```text
results/
└── p1-clear-single-phase-run-1/
    ├── docs/published-report-list/brief.md
    ├── docs/published-report-list/phase-1/prd.md
    ├── docs/published-report-list/phase-1/units/UNIT-*.md
    ├── executor-notes.md
    └── grading-product-thinking.json
```
