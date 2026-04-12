# P2: /product 方案先行型模糊需求场景

用途：验证 `/product` 是否会被用户给出的方案锚定，还是能够先回到真实问题，再沉淀需求基线。

## 场景概述

让 LLM agent 自主执行 `/product` 流程，输入是一段明显带方案预设的用户描述。重点观察它是否会直接把“角色树、批量授权”写死成需求，或能先澄清根问题、目标、约束，再把方案候选留给 design。

## 输入

- 用户首句：`我想做一个权限矩阵配置中心，最好像竞品那样有角色树和批量授权。`
- 现有工件：无

## Executor Prompt 模板

```text
你是一个自主执行 /product 流程的 agent。

## 任务
围绕以下用户需求执行完整的 /product 流程，输出可交接的需求基线。

用户首句：
我想做一个权限矩阵配置中心，最好像竞品那样有角色树和批量授权。

## Skill 规则
插入当前 /product skill 内容。

## 共创模拟
本次执行中，用户回应由以下脚本预定义。当你到达需要用户输入的步骤时，使用对应回答继续推进。

## 输出要求
- 所有输出写入 `tools/eval/results/p2-solution-anchoring-run-{n}/`
- 必须产出 `docs/permission-config-center/brief.md`
- 必须产出 `docs/permission-config-center/phase-1/prd.md`
- 必须产出 `docs/permission-config-center/phase-1/units/UNIT-*.md`
- 若你识别出多 Phase，补充对应 `phase-{N}/prd.md`
- 完成后补一份 `executor-notes.md`，说明你如何避免被用户方案锚定
```

## 模拟用户回应脚本

### S1 需求理解（无需用户输入）

无。executor 直接读取用户首句。

### S2 根问题澄清

当 executor 追问“真实痛点是什么”时：

> 回答：现在每次给新项目开权限都要找平台管理员手工改很多配置，速度慢，而且改完后经常没人说得清哪些角色到底有了哪些资源权限。

当 executor 追问“角色树和批量授权是不是必须”时：

> 回答：不是必须，我提这个是因为竞品看起来这样做。真正想解决的是：配置效率低、容易配错、事后难审计。

### S3 目标与成功标准对齐

当 executor 询问成功标准时：

> 回答：希望项目管理员能在一个地方看清某个角色拥有哪些资源权限，并完成常见权限调整；一次常规授权调整最好在 5 分钟内完成；变更后要能追溯是谁改的。

### S4 业务语义收口

当 executor 询问核心概念时：

> 回答：这里的角色是项目内角色，不是公司统一身份角色；资源是系统里的功能模块和数据范围；权限调整至少包含新增、移除和查看当前状态。

### S5 范围与规则收口

当 executor 呈现范围草案时：

> 回答：本期先覆盖项目级角色的查看和调整，不做跨项目继承规则，不做组织架构同步，不做复杂审批流。

当 executor 追问审计要求时：

> 回答：每次权限调整都要留下操作人、时间、变更前后差异。是否展示成时间线由 design 决定。

### S6 交付节奏决策

当 executor 询问是否需要多 Phase 时：

> 回答：如果能保证核心闭环清晰，可以先做一个 Phase。竞品里的树形可视化和批量操作不是必须同一期上线。

### S7 逐 Phase UNIT 拆解

当 executor 呈现 UNIT 草案时：

> 回答：至少要覆盖三件事：查看当前角色权限、执行一次权限调整、留存可查询的变更记录。不要把“像竞品的角色树”直接当成一个必做 UNIT。

### S8 验收标准定义

当 executor 呈现 AC 草案时：

> 回答：确认。请把“能否直接看清当前权限”和“改完后是否可追溯”写成可观察结果，不要只写界面形式。

### S9 待设计决策

当 executor 询问开放问题时：

> 回答：有两个设计决策需要保留：权限矩阵的交互形态怎么呈现、批量调整是否需要单独能力。它们都应由 design 结合复杂度裁决。

### S10 完整性扫描

当 executor 做完整性扫描时：

> 回答：补充一个边界，项目管理员只能调整自己有权管理的项目，不能越权修改其他项目的角色权限。

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
└── p2-solution-anchoring-run-1/
    ├── docs/permission-config-center/brief.md
    ├── docs/permission-config-center/phase-1/prd.md
    ├── docs/permission-config-center/phase-1/units/UNIT-*.md
    ├── executor-notes.md
    └── grading-product-thinking.json
```
