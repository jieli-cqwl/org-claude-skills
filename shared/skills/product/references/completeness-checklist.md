# 需求完整性检查表（10 类分类法）

> 引用者：product SKILL.md（完整性扫描步骤）

## 使用方式

在 PRD 收口前，逐类扫描并标记状态。Partial/Missing 的类别必须追问或显式标注"不适用（原因）"。

## 收口检查

- 最终稿里若仍保留 `候选问题`、`候选根问题`、`未裁决 root problem` 或类似占位标记，说明前序共创没有真正收口，必须回退继续澄清。
- `C1` 和 `C9` 的判定只以最终 `brief.md / prd.md / UNIT-*` 为准，候选清单不能替代最终结论。

## 10 类检查

| # | 类别 | 检查要点 | 状态 |
|---|------|---------|------|
| C1 | 功能域 | 核心功能是否已定义？正常/异常/边界流程是否覆盖？ | Clear / Partial / Missing |
| C2 | 数据模型 | 业务对象、字段、关系、生命周期是否明确？ | Clear / Partial / Missing |
| C3 | 用户交互 | 输入方式、反馈形式、操作流程是否定义？ | Clear / Partial / Missing |
| C4 | 非功能需求 | 性能、安全、可用性、可观测性是否有量化标准？ | Clear / Partial / Missing |
| C5 | 集成边界 | 外部系统、API、第三方服务的接口和契约是否明确？ | Clear / Partial / Missing |
| C6 | 边界条件 | 数据量上限、并发上限、极端输入是否定义？ | Clear / Partial / Missing |
| C7 | 约束条件 | 技术约束、业务约束、合规要求是否列出？ | Clear / Partial / Missing |
| C8 | 术语定义 | 领域术语是否有统一定义？是否存在歧义术语？ | Clear / Partial / Missing |
| C9 | 完成信号 | MVP 范围是否明确？上线标准是否可验证？成功标准是否有可观察的度量方式？ | Clear / Partial / Missing |
| C10 | 风险前瞻 | Pre-mortem：假设项目已失败，最可能的 3 个失败原因是什么？ | Clear / Partial / Missing |

## 判定规则

- 全部 Clear -> 完整性通过，可进入输出
- 存在 Partial -> 必须追问补充，或记录"已知不完整，原因：..."
- 存在 Missing -> 必须追问，不允许标注"不适用"除非有充分理由
- C1（功能域）和 C9（完成信号）为 REQUIRED，不允许 Missing
- C10（风险前瞻）为推荐项，Partial/Missing 时建议补充但不阻塞
- 最终稿中如仍出现候选问题清单或未裁决 root problem，视为对应类别未收口，不能进入输出

## 不适用标注格式

```
| C5 | 集成边界 | 不适用（纯前端功能，无外部集成） | N/A |
```
