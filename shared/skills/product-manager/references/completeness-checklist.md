# 需求完整性检查表（12 类分类法 + AI 可执行性）

## 使用方式

在 Manager 收口前，逐类扫描并标记状态。Partial / Missing 的类别必须追问，或显式标注"不适用（原因）"。扫描结论写入 `review_conclusion / issue_ledger`，人类投影视图只渲染这些 JSON 字段。

## 12 类检查

| # | 类别 | 检查要点 | 状态 |
|---|------|---------|------|
| C1 | 功能域 | 核心功能是否已定义？正常 / 异常 / 边界流程是否覆盖？是否有按子模块的 Mermaid 业务流程图？是否有功能清单表 + 模块能力矩阵？ | Clear / Partial / Missing |
| C2 | 数据模型 | 业务对象、字段、关系、生命周期是否明确？业务对象是否定义了状态流转？是否有状态/枚举定义表？ | Clear / Partial / Missing |
| C3 | 用户交互 | 输入方式、反馈形式、操作流程是否定义？是否有页面清单与组装视图（页面→UNIT 映射）？页面跳转与联动关系是否定义？页面状态要求（加载/空/错误/无权限）是否覆盖？ | Clear / Partial / Missing |
| C4 | 非功能需求 | 性能、安全、可用性、可观测性是否有量化标准？ | Clear / Partial / Missing |
| C5 | 集成边界 | Integration Context 是否覆盖涉及的业务模块、不可破坏行为、跨 UNIT 依赖和业务约束？是否保持 WHAT 层，不写技术落点？ | Clear / Partial / Missing |
| C6 | 边界条件 | 数据量上限、并发上限、极端输入是否定义？是否有字段校验矩阵？每个 UNIT 的边界情况和失败模式是否枚举？ | Clear / Partial / Missing |
| C7 | 约束条件 | 技术约束、业务约束、合规要求是否列出？ | Clear / Partial / Missing |
| C8 | 术语定义 | 领域术语是否有统一定义？是否存在歧义术语？ | Clear / Partial / Missing |
| C9 | 完成信号 | MVP 范围是否明确？上线标准是否可验证？成功信号是否包含基线、目标值/方向、观测窗口和数据来源？是否有全局验收标准（功能+流程+安全）？ | Clear / Partial / Missing |
| C10 | 风险前瞻 | Pre-mortem：最可能的失败原因是什么？是否有高风险操作清单（含前端控制、后端控制、日志要求）？ | Clear / Partial / Missing |
| C11 | 角色权限 | 是否有角色×模块权限矩阵？各角色的查询/新增/修改/删除/导出权限是否明确？ | Clear / Partial / Missing |
| C12 | QA 交接 | 是否有 QA 测试重点（按类别列出优先测试区域）？Verification Plan 是否按 UNIT 给出业务操作和预期可观察结果？ | Clear / Partial / Missing |

## AI 可执行性补充检查

| # | 检查项 | Clear 标准 | 状态 |
|---|--------|------------|------|
| AI-1 | 示例驱动 AC | 每条 AC 都有示例输入、预期结果、边界情况和失败模式，且能直接支撑验收判断 | Clear / Partial / Missing |
| AI-2 | Verification Plan | 每个 UNIT 都说明验证类型、业务操作或场景、预期可观察结果，以及对应 AC / 成功标准 / 风险项 | Clear / Partial / Missing |
| AI-3 | Integration Context | 每个 UNIT 都说明业务模块、不可破坏行为和跨 UNIT 依赖，下游无需猜测影响面 | Clear / Partial / Missing |
| AI-4 | 结构化待设计决策 | 每个开放设计问题都有候选选项、约束条件、影响 UNIT 和 design handoff，不提前写技术答案 | Clear / Partial / Missing |
| AI-5 | AI 可执行性 | 规格没有“按需、默认、合理处理”等模糊词；下游 AI 不需要自行补边界、异常或验收样例 | Clear / Partial / Missing |

## 判定规则

- 全部 Clear → 可进入输出
- 存在 Partial → 必须追问补充，或记录已知不完整及原因
- 存在 Missing → 必须追问，不允许默认跳过
- C1、C9 与 C11 不允许 Missing
- AI-1、AI-2、AI-3 Missing 时不得进入 M-S8；AI-4 Missing 且存在开放设计问题时不得进入 M-S8
