# 交付门禁调度合同

> 引用者：delivery-owner SKILL.md 交付门禁

Trigger: Use when delivery-owner enters delivery gate review, QA, fix-loop convergence, waiver handling, consistency sidecar scan, or sign-off readiness.
Read: `code-review-result.json`, `qa-result.json`, `delivery-state.json`, `signoff-package.json`, current `plan_version_ref`, QA test-case refs, consistency-auditor advisory report, and `references/signoff-contract.md`.
Expect: Delivery gate always runs the fixed full review/QA gate, triggers the sign-off readiness consistency sidecar scan, and records current evidence before sign-off.
Consume: Code review agents, QA agents, fixer loops, consistency-auditor, delivery-owner gate decisions, `code-review-result.json`, `qa-result.json`, `references/signoff-contract.md`, and `signoff-package.json` consume this guide.
Evidence: `tests/test-delivery-owner-gate-contract.sh`, replay contract tests, rollout gate tests, and completion gates assert this contract.
Sync: Update this file with `SKILL.md` delivery gate, `references/signoff-contract.md`, `scripts/delivery-gate-stages.sh`, QA template, code-review template, and completion gate validations.

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

## 签收前一致性旁路扫描

触发点：固定完整门禁全部通过后、生成 `signoff-package.json` 前，`delivery-owner` 调度 `consistency-auditor` 一次。

输入边界：

- `brief.json / phase-prd.json / UNIT-*.json / design.json / plan.json / tasks.json / test-cases.json`
- `delivery-state.json / artifact-registry.json`
- `developer-report.json / verify-result.json / code-review-result.json / qa-result.json`
- 当前 `plan_version_ref / tasks_version_ref`

输出边界：

- `decision_authority: advisory_only`
- `consumer: delivery-owner`
- `blocked_layers / skipped_layers / tool_warning`
- `required_owner_action`

消费规则：

- `consistency-auditor` 不得替代 `REVIEW/QA` 结论、固定完整门禁、签收或风险接受。
- 无 CRITICAL 且无 blocked layer：`delivery-owner` 将 advisory evidence 记入当前签收依据，继续生成 `signoff-package.json`。
- CRITICAL 或 blocked layer 指向代码、验证证据或实现产物断链：控制动作 `FIX`。
- CRITICAL 或 blocked layer 指向 design/plan/tasks/test-cases 基线漂移：控制动作 `REPLAN`。
- CRITICAL 或 blocked layer 指向缺失工件、环境不可用或运行态证据缺口：控制动作 `BLOCK`。
- CRITICAL 或 blocked layer 需要用户、tech-lead 或上游角色裁决：控制动作 `ESCALATE`。
- WARNING / INFO 只作为 owner action 线索；触及 residual_risk / waiver 时，按风险接受边界处理。

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

## 签收合同

签收证据闭环、goal closure、constraint closure、freshness、risk acceptance 与模板投影边界由 `references/signoff-contract.md` 定义。交付门禁只负责生成可被签收合同消费的当前 review、QA、fix 和 advisory evidence。
