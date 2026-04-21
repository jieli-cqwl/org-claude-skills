# Template Notes

> 引用者：`design/SKILL.md` 的人类视图说明。运行时事实源是 `phase-{N}/design.json`；本文件只说明投影视图怎样保持可读，不作为门禁或事实源。

## 设计投影视图

当需要把 `design.json` 渲染成人类可读视图时，投影内容只呈现以下信息：

| 区块 | 来源字段 | 说明 |
| --- | --- | --- |
| 输入分析 | `input_analysis` | 说明架构判断基于哪些已冻结需求、约束和待设计决策 |
| 关键决策 | `key_decisions[]` | 每条决策写清原因、影响范围和替代方案取舍 |
| 接口边界 | `interface_boundary[]` | 描述模块、接口、调用方和数据契约 |
| 质量属性 | `quality_attributes[]` | 记录性能、可靠性、安全、可观测性等约束 |
| 风险与回滚 | `risks[]` / `rollback_plan` | 只呈现设计期风险和回滚路径 |

## 写法约束

- 投影视图只能渲染 `design.json` 已落盘字段。
- 投影视图不能新增设计决策、质量门禁、hook 指令或审查结论。
- 字段含义、schema 和机器校验规则只维护在 `contracts/canonical/`。
- 专家方法论放在对应 reference；模板只负责展示结构。

## 目录位置

```text
docs/{feature}/phase-{N}/design.json
docs/{feature}/phase-{N}/views/design.projection.md
docs/{feature}/phase-{N}/views/design.projection-manifest.json
```

投影视图若存在，必须能通过 manifest 回指 `design.json` 的具体字段或 JSON Pointer。
