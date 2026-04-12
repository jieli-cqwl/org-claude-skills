# Goal Evidence Model

## 目的

把 `brief` 成功标准、Phase 目标和交付价值映射到执行证据、QA 证据和最终签收结论，避免“流程全绿但目标没达成”。

## 映射模型

| 层级 | 真源 | 必须映射到 | 收口方式 |
|------|------|-----------|---------|
| 成功标准 | `brief.md` | `goal closure` 行项 | `已达成 / 部分达成 / 未达成` |
| Phase 目标 | `phase-{N}/prd.md` | `dev-report / qa-report / acceptance-summary` | 证据链闭环 |
| 交付价值 | `brief.md / prd.md` | `release_recommendation + residual_risk + remaining_gap` | 用户 sign-off 前确认 |

## 结论规则

- 所有目标都 `已达成` 且 QA 非阻塞，才允许 `acceptance_release_recommendation=放行`。
- 任一目标 `部分达成` 时，最多 `条件放行`，并且必须说明 `remaining_gap`。
- 任一目标 `未达成` 时，不得确认签收。

## 目标闭环

- 从 `brief / prd` 取目标。
- 从 `dev-report / qa-report / acceptance-summary` 取证据。
- 用 `已达成 / 部分达成 / 未达成` 收口。
