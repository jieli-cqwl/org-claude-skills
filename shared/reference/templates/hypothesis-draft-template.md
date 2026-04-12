# Hypothesis Draft Template

> 用途：`Hypothesis Draft` 类 sub agent 的唯一模板源。
> 约束：只给候选假设，不给最终结论。

## 统一 schema

| 字段 | 固定值 / 填写要求 |
|------|-------------------|
| `agent_kind` | 固定为 `hypothesis_draft` |
| `current_judgment_type` | 固定为 `hypothesis` |
| `decision_state` | 只允许 `候选` 或 `待裁决` |
| `input_boundary` | 必填，引用下方 `## 输入边界` |
| `evidence_anchor` | 必填，引用下方 `## 证据锚点` |
| `unresolved_item` | 必填，引用下方 `## 未决项` |
| `forbidden_action` | 必填，引用下方 `## 禁止越权项` |

## 输入边界

| 来源类型 | 来源 | 说明 |
|------|------|------|
| required_input | | 当前阶段必须读取的上游输入 |
| upstream_artifact | | 已存在的事实回收件 |
| accepted_candidate | | 主 Agent 已接受的候选输入 |

## 当前判断

| 假设 ID | 候选假设 | 证据力度 | 判断类型 | 说明 |
|------|----------|----------|----------|------|
| H-001 | | | hypothesis | 候选项必须互斥、可比较 |

## 证据锚点

| 假设 ID | 锚点类型 | 锚点 | 反证点 |
|------|----------|------|--------|
| H-001 | section | | |

## 未决项

| Item ID | owner | blocking_for | next_action | 备注 |
|------|------|-------------|------------|------|
| U-001 | | | | |

## 禁止越权项

- 不得冻结最终方案。
- 不得替主 Agent 做最终裁决。
- 不得把单一假设伪装成结论。

## 候选对照

| 候选 | 优点 | 代价 | 反证信号 |
|------|------|------|---------|
| A | | | |
| B | | | |
