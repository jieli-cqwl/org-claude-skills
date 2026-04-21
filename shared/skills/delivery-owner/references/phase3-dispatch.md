# 阶段 3：固定完整门禁调度合同

> 引用者：delivery-owner SKILL.md Phase 3

Trigger: Use when delivery-owner enters Phase 3 review, QA, fix-loop convergence, waiver handling, or sign-off readiness.
Read: `code-review-result.json`, `qa-result.json`, `delivery-state.json`, `signoff-package.json`, current `plan_version_ref`, and QA test-case refs.
Expect: Phase 3 always runs the fixed full review/QA gate and records current evidence before sign-off.
Consume: Code review agents, QA agents, fixer loops, delivery-owner gate decisions, `code-review-result.json`, `qa-result.json`, and `signoff-package.json` consume this guide.
Evidence: `tests/test-delivery-owner-phase3-contract.sh`, replay contract tests, rollout gate tests, and completion gates assert this contract.
Sync: Update this file with `SKILL.md` Phase 3, `scripts/phase3-grade-matrix.sh`, QA template, code-review template, and completion gate validations.

## 固定完整门禁

| 类型 | 必跑阶段 | 消费工件 |
|------|----------|----------|
| Code Review | `REVIEW_A + REVIEW_B + REVIEW_C` | `code-review-result.json` |
| QA | `QA_A + QA_B + QA_C + QA_D` | `qa-result.json` |

所有阶段都是固定完整门禁。`delivery-owner` 不按轻量、标准、完整分级裁剪执行，也不通过偏差信号追加或删除阶段。

## Handoff Boundary

`delivery-owner` 只负责交接合同和证据消费：

- 给 `review`：当前变更范围、design/plan refs、developer/verify refs、fresh proving output refs、固定 `REVIEW_A/B/C` 输出要求。
- 给 `qa`：`test_cases_ref` 或 `test_cases_refs`、当前 plan/tasks baseline refs、entry/build/env、固定 `QA_A/B/C/D` 输出要求。
- 给 `fix`：稳定 issue id、失败证据、允许修改范围、回归影响面、关闭标准。

`review / qa / fix` 各自保持独立结论；`delivery-owner` 不替专家判断问题是否关闭。

若 `test_cases_ref / test_cases_refs` 命中 `browser_required`，`QA_B` 必须使用浏览器 E2E（默认 `webapp-testing` / Playwright）执行，并在 `qa-result.json` 写入 `browser_tool`、`entry_url`、`browser_evidence`。

## 修复循环与熔断

- `REVIEW_ISSUE`：派发 `fix` 修复对应 issue，修复后重跑受影响 review 阶段，并按影响面决定是否重跑完整 review。
- `QA_A_ISSUE`：基础 AC 验收失败，先修复并重跑 QA_A；影响范围扩大时重跑完整 QA。
- `QA_B/C/D_ISSUE`：修复对应 issue，重跑失败阶段；修复触及已通过阶段覆盖范围时，重跑受影响阶段。
- 连续 2 轮 FAIL 数不减少：暂停并展示趋势、重复项、owner。
- 同一问题连续 3 轮未关闭：`BLOCKED`。
- Review-Fix 或 QA-Fix 最多 10 轮。

修复循环中产生的新证据必须写回 `delivery-state.json`，并保持当前 `plan_version_ref`。

## 风险接受边界

- `residual_risk / waiver` 必须关联稳定 issue id、影响范围、补偿控制、到期条件和用户确认。
- 固定门禁阶段不得整体豁免。
- `qa` 只能给出风险与放行建议，不能替用户接受风险。
- 任何 `residual_risk / waiver` 都必须由用户显式确认后，才能进入签收。

## 汇总代理边界

- 汇总代理只汇总 Task 状态、门禁结果、证据锚点、未决项和风险承接。
- 汇总代理不得新增 `REVIEW/QA` 结论。
- 汇总代理不得改变固定完整门禁。
- 汇总代理不得新增风险接受或放行结论。
- 若未触发汇总代理，completion gate 不强制要求 summary 文件存在。
