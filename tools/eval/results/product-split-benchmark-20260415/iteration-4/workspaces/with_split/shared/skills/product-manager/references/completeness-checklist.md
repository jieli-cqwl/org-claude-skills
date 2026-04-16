# 需求完整性检查表（10 类分类法）

## 使用方式

在 Manager 收口前，逐类扫描并标记状态。Partial / Missing 的类别必须追问，或显式标注“不适用（原因）”。

## 10 类检查

| # | 类别 | 检查要点 | 状态 |
|---|------|---------|------|
| C1 | 功能域 | 核心功能是否已定义？正常 / 异常 / 边界流程是否覆盖？ | Clear / Partial / Missing |
| C2 | 数据模型 | 业务对象、字段、关系、生命周期是否明确？ | Clear / Partial / Missing |
| C3 | 用户交互 | 输入方式、反馈形式、操作流程是否定义？ | Clear / Partial / Missing |
| C4 | 非功能需求 | 性能、安全、可用性、可观测性是否有量化标准？ | Clear / Partial / Missing |
| C5 | 集成边界 | 外部系统、API、第三方服务的接口和契约是否明确？ | Clear / Partial / Missing |
| C6 | 边界条件 | 数据量上限、并发上限、极端输入是否定义？ | Clear / Partial / Missing |
| C7 | 约束条件 | 技术约束、业务约束、合规要求是否列出？ | Clear / Partial / Missing |
| C8 | 术语定义 | 领域术语是否有统一定义？是否存在歧义术语？ | Clear / Partial / Missing |
| C9 | 完成信号 | MVP 范围是否明确？上线标准是否可验证？成功信号是否包含基线、目标值/方向、观测窗口和数据来源？ | Clear / Partial / Missing |
| C10 | 风险前瞻 | Pre-mortem：最可能的失败原因是什么？ | Clear / Partial / Missing |

## 判定规则

- 全部 Clear → 可进入输出
- 存在 Partial → 必须追问补充，或记录已知不完整及原因
- 存在 Missing → 必须追问，不允许默认跳过
- C1 与 C9 不允许 Missing
