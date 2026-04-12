# Structure Draft Template

> 用途：`Structure Draft` 类 sub agent 的唯一模板源。
> 约束：只输出结构草稿，不写最终编号、最终 Gate 或最终签收结论。

## 统一 schema

| 字段 | 固定值 / 填写要求 |
|------|-------------------|
| `agent_kind` | 固定为 `structure_draft` |
| `current_judgment_type` | 固定为 `draft` |
| `decision_state` | 只允许 `候选` 或 `待裁决` |
| `input_boundary` | 必填，引用下方 `## 输入边界` |
| `evidence_anchor` | 必填，引用下方 `## 证据锚点` |
| `unresolved_item` | 必填，引用下方 `## 未决项` |
| `forbidden_action` | 必填，引用下方 `## 禁止越权项` |

## 输入边界

| 来源类型 | 来源 | 说明 |
|------|------|------|
| required_input | | 当前阶段必须读取的上游输入 |
| upstream_artifact | | 已冻结的上游工件 |
| accepted_candidate | | 主 Agent 已接受的候选输入 |

## 当前判断

| 草稿 ID | 草稿项 | 状态 | 说明 |
|------|------|------|------|
| D-001 | | draft | 只写结构，不写冻结结论 |

## 证据锚点

| 草稿 ID | 上游字段 | 锚点 | 回链说明 |
|------|----------|------|--------|
| D-001 | | | |

## 未决项

| Item ID | owner | blocking_for | next_action | 备注 |
|------|------|-------------|------------|------|
| U-001 | | | | |

## 禁止越权项

- 不得写最终编号。
- 不得写最终 Gate。
- 不得写最终签收结论。

## 结构草稿

| 字段 | 草稿值 | 上游来源 | 备注 |
|------|--------|----------|------|
| | | | |
