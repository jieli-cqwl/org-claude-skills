# Goal Evidence Model

## 冻结说明

- 本文件自 `T1` 起作为 `goal closure`、签收与业务风险接受的判定真源。
- 若要调整字段或判定规则，必须先刷新实施计划并重新评审；最终验收阶段不得临时改尺子。

## 目的

把 `brief` 成功标准、Phase 目标和交付价值映射到执行证据、QA 证据和最终签收结论，避免“流程全绿但目标没达成”。

## 映射模型

| 层级 | 真源 | 必须映射到 | 收口方式 |
|------|------|-----------|---------|
| 成功标准 | `brief.md` | `goal closure` 行项 | `已达成 / 部分达成 / 未达成` |
| Phase 目标 | `phase-{N}/prd.md` | `dev-report / qa-report / acceptance-summary` | 证据链闭环 |
| 交付价值 | `brief.md / prd.md` | `release_recommendation + residual_risk + remaining_gap` | 用户 sign-off 前确认 |

## 字段合同

| 字段 | 含义 | 允许来源 |
|------|------|---------|
| `goal_source_ref` | 目标来源锚点 | `brief.md#目标与成功标准` / `phase-{N}/prd.md#阶段目标` |
| `execution_basis_ref` | 当前执行基线锚点 | `design.md#...` / 当前 phase 的 `plan.md#计划版本` / `test-cases.md#...` |
| `evidence_ref` | 证明当前结果的证据 | `dev-report.md#...` / `qa-report.md#...` / `preflight-evidence.md#...` |
| `sign_off_status` | 用户是否确认当前交付 | `确认 / 拒绝 / 待签收` |
| `business_risk_acceptance_status` | 用户是否接受残余业务风险 | `接受 / 拒绝 / 不适用 / 待确认` |
| `uncovered_boundary` | QA 尚未覆盖或需条件承接的边界 | 来自 `qa-report.md` 的冻结摘要 |
| `conditional_release_basis` | 条件放行依据 | 来自 `qa-report.md` 的冻结摘要；无则写 `无` |
| `not_executed_reason` | QA 非执行项承接摘要 | 来自 `qa-report.md` 的冻结摘要；无则写 `无` |
| `risk_acceptance_basis` | 风险接受依据 | 仅允许引用已冻结报告与用户确认事实 |

> `goal_source_ref / execution_basis_ref / evidence_ref` 都是必填字段，且必须指向真实存在的锚点；缺失、错文件或错锚点都不能签收。
> `goal` 本身可以是 upstream goal 的同义复述或收口摘要，但不能漏承接任何 upstream goal；门禁按来源锚点与行数核对，不按字面相似度裁决。

## 结论规则

- 所有目标都 `已达成` 且 QA 非阻塞，才允许 `acceptance_release_recommendation=放行`。
- 任一目标 `部分达成` 时，最多 `条件放行`，并且必须说明 `remaining_gap`。
- 任一目标 `未达成` 时，不得确认签收。
- 当存在残余风险、条件放行或 `部分达成` 时，`business_risk_acceptance_status` 不得留空。
- `acceptance-summary.md` 必须完整承接 `qa-report.md` 的 `uncovered_boundary / conditional_release_basis / not_executed_reason`，不能只复制放行结论与残余风险。
- `goal_source_ref` 负责证明“这个目标来自哪里”；`execution_basis_ref` 负责证明“本次执行依赖了哪条冻结基线”；两者都不能用描述性文字替代锚点引用。
- `execution_basis_ref` 若引用 `plan.md`，只能引用当前 phase 的 `plan.md#计划版本`；`stale-plan.md#计划版本` 这类旧基线不得作为当前执行依据。

## 目标闭环

- 从 `brief / prd` 取目标。
- 从 `dev-report / qa-report / acceptance-summary` 取证据。
- 用 `已达成 / 部分达成 / 未达成` 收口。
